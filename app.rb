require 'sinatra/base'
require_relative 'routes/init'
require_relative 'models/init'
require_relative 'lib/log_wrapper'
require 'uri'
require 'redis'
require 'json'
require 'ohm'
require 'celluloid'
require 'log4r'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/datefileoutputter'

class TranscoderManager < Sinatra::Base

  # initialize logging
  disable :logging
  Log4r::YamlConfigurator.load_yaml_file "#{File.dirname(__FILE__)}/config/logging-#{ENV['RACK_ENV']}.yaml"
  use Rack::CommonLogger, LogWrapper.new('main')
  Log4r::Logger['main'].debug('Application loaded')

  # initialize connection to redis
  set :redis_url, ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
  Ohm.connect url: settings.redis_url, driver: :hiredis
  Ohm.redis.ping

  # initialize monitoring
  MonitorService.instance.start if 'production' == ENV['RACK_ENV']


  # configure sinatra
  configure do
    set :app_file, __FILE__
    disable :show_exceptions
    disable :raise_errors
  end

  configure :development do
    enable :dump_errors
  end

  configure :test do
    enable :dump_errors
    enable :raise_errors
  end

  configure :production do
    disable :dump_errors
  end

  # General routes

  before do
    content_type :json

    # allow cross origin calls
    headers 'Access-Control-Allow-Origin' => '*',
     'Access-Control-Allow-Methods' => 'POST, GET, OPTIONS',
     'Access-Control-Allow-Headers' => 'Content-Type'

    # normalize base path from custom header
    base_path = env['HTTP_X_FORWARDED_BASE_PATH'] || '/'
    base_path = '' if base_path == '/'
    env['PATH_INFO'][base_path]= ''
  end

  get '/' do
    halt 200,
         {'Content-Type' => 'text/plain'},
         "BB Web Broadcast - Transcoder Manager. #{Time.now}"
  end

  get '/test-redis' do
    msg = 'redis is dead.'
    if Ohm.redis.ping == 'PONG'
      msg = "redis is alive at #{Ohm.conn.options[:url]}".to_json
    end
    halt 200, {'Content-Type' => 'text/plain'}, msg
  end

  # Error handlers

  class ApiError < StandardError; end

  not_found do
    'This is nowhere to be found. Intention !'
  end

  error do
    e = env['sinatra.error']
    if e.message =~ /reconnect to Redis/
      logger.warn "Redis connection error: #{e.message}. Trying to reconnect."
      recover_redis_connection
    else
      handle_error 500, 'Internal Server Error'
    end
  end

  error ApiError do
    handle_error 400, 'Api error'
  end

  error Transcoder::TranscoderError do
    handle_error 400, 'Transcoder error'
  end

  private

  def logger
    logger = Log4r::Logger['main']
    raise 'logging not initialized properly' if logger.nil?
    logger
  end

  def log_exception(e)
    trace = e.backtrace.join("\n")
    logger.error("Exception: '#{e.message}'\nBacktrace:\n#{trace}")
  end

  def success(msg = 'success')
    {result: msg}.to_json
  end

  def handle_error(status, message)
    e = env['sinatra.error']
    status == 500 ? log_exception(e) : logger.warn(e.message)
    halt status, {'Content-Type' => 'text/plain'}, "#{message} - #{e.message}"
  end

  def expect_params(*parameter_names)
    parameter_names.map do |p|
      raise ApiError, "expecting #{p} but didn't get any" unless params[p]
      params[p]
    end
  end

  def recover_redis_connection
    begin
      Ohm.connect url: settings.redis_url, driver: :hiredis
      if Ohm.redis.ping == 'PONG'
        logger.info 'Successfully reconnected to redis. Re invoking route'
        dispatch!
      end
    rescue => ex
      logger.error "Unable to reconnect: #{ex.message}"
    end
  end

end


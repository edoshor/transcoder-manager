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
  Log4r::YamlConfigurator.load_yaml_file "config/logging-#{ENV['RACK_ENV']}.yaml"
  use Rack::CommonLogger, LogWrapper.new('main')
  Log4r::Logger['main'].debug('Application loaded')

  # initialize connection to redis
  set :redis_url, ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
  Ohm.connect url: settings.redis_url
  Ohm.redis.ping

  # initialize monitoring
  MonitorService.instance.start

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

  # Error handlers and general routes

  class ApiError < StandardError; end

  get '/' do
    halt 200, {'Content-Type' => 'text/plain'}, "BB Web Broadcast - Transcoder Manager. #{Time.now}"
  end

  not_found do
    'This is nowhere to be found. Intention !'
  end

  error do
    handle_error 500, 'Internal Server Error'
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

  def handle_error(status, message)
    e = env['sinatra.error']
    status == 500 ? log_exception(e) : logger.warn(e.message)
    halt status, {'Content-Type' => 'text/plain'}, "#{message} - #{e.message}"
  end

end


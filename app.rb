require 'sinatra/base'
require_relative 'routes/init'
require_relative 'helpers/init'
require_relative 'models/init'
require 'haml'
require 'uri'
require 'redis'
require 'json'
require 'ohm'

class TranscoderManager < Sinatra::Base
  enable :method_override
  #enable :sessions
  #set :session_secret, 'super secret'

  configure do
    set :app_file, __FILE__
    disable :show_exceptions
    disable :raise_errors
    enable :logging

    set :redis_url, ENV['REDIS_URL'] || 'redis://127.0.0.1:6379/0'
    Ohm.connect url: settings.redis_url
  end

  configure :development do
    enable :dump_errors
    #enable :raise_errors
  end

  configure :qa do
    enable :dump_errors
    #enable :raise_errors
  end

  configure :production do
  end

  get '/*' do
    success "BB Web Broadcast - Transcoder Manager. #{Time.now}"
  end

  error do
    handle_error 500, 'Unexpected error'
  end

  error ApiError do
    handle_error 400, 'Api error'
  end

  error TranscoderError do
    handle_error 400, 'Transcoder error'
  end

  private

  def handle_error(code, result)
    status code
    e = env['sinatra.error']
    logger.error e
    {:result => result, :message => e.message}.to_json
  end


end

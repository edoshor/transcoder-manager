ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://127.0.0.1:6379/1'

require 'bundler'
Bundler.setup
Bundler.require(:test)

require 'test/unit'
require 'factory_girl'
require 'mocha/setup'
require 'redis'
require 'json'
require 'ohm'
require 'log4r'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/datefileoutputter'

require 'celluloid/test'
Celluloid.boot

require_relative '../models/init'
require_relative 'factories'

module TestHelper
  include FactoryGirl::Syntax::Methods

  def self.startup
    # initialize logging
    Log4r::YamlConfigurator.load_yaml_file "config/logging-#{ENV['RACK_ENV']}.yaml"

    # initialize connection to redis
    redis_url = ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
    Ohm.connect url: redis_url, driver: :hiredis
    Ohm.redis.ping
  end

  def setup
    puts method_name
  end

  def teardown
    Ohm.flush # clear all keys in redis after each test
  end

  def self.shutdown
    Ohm.flush # clear all keys in redis after tests finished
  end

end
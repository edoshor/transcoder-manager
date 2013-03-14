ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://127.0.0.1:6379/1'

require 'bundler'
Bundler.setup
Bundler.require(:test)

require 'test/unit'
require 'rack/test'
require 'factory_girl'
require 'mocha/setup'
require 'webmock/test_unit'
require_relative '../app'
require_relative '../app_config'
require_relative 'factories'


module TestHelper
  include FactoryGirl::Syntax::Methods

  def app
    TranscoderManager.new
  end

  def teardown
    Ohm.flush # clear all keys in redis after each test
  end


  def self.shutdown
    Ohm.flush # clear all keys in redis after tests finished
  end


end
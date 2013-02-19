require 'test/unit'
require 'rack/test'
require 'bundler'
require 'factory_girl'
require_relative '../app'
require_relative '../app_config'
require_relative 'factories'

ENV['RACK_ENV'] = 'test'
ENV['REDIS_URL'] = 'redis://127.0.0.1:6379/1'

Bundler.setup
Bundler.require(:test)

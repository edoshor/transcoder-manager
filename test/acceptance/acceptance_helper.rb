require_relative '../test_helper.rb'
require 'webmock/test_unit'
require 'rack/test'
require_relative '../../app'
require_relative '../../app_config'

module AcceptanceHelper
  include Rack::Test::Methods
  include FactoryGirl::Syntax::Methods
  include TestHelper

  def app
    TranscoderManager.new
  end

  Mail.defaults do
    delivery_method :test
  end

  def assert_successful(resp)
    puts resp.to_s unless resp.status == 200
    assert_equal 200, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    JSON.parse resp.body
  end

  def assert_successful_text(resp, text)
    assert_equal 200, resp.status
    assert_equal 'text/plain', resp.header['Content-Type']
    assert_match(text, resp.body)
  end

  def assert_json_eq(model, json)
    assert_equal JSON.parse(model.to_hash.to_json), json
  end

  def assert_successful_eq(model, resp)
    assert_json_eq model, assert_successful(resp)
  end

  def assert_validation_error(resp)
    assert_custom_error resp, 'Validation failed'
  end

  def assert_configuration_error(resp)
    assert_custom_error resp, 'Configuration'
  end

  def assert_custom_error(resp, reason)
    assert_equal 400, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    assert_match /#{reason}/, resp.header['X-Status-Reason']
    body = JSON.parse resp.body
    assert_false body.empty?
    body
  end

  def assert_api_error(resp)
    assert_equal 400, resp.status
    assert resp.header['Content-Type'].include?('text/plain')
    assert_false resp.body.empty?
    resp.body
  end

end




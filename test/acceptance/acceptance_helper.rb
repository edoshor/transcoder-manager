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

  def assert_attributes_eq(atts, model, check_id = true)
    unless atts.kind_of?(Hash)
      assert_equal(atts.to_s, model)
      return
    end

    assert_compare 0, '<', model.delete('id').to_i if check_id

    atts.each do |k, v|
      model_value = model.fetch(k.to_s)
      if v.kind_of?(Array)
        v.zip(model_value).each { |x, y| assert_attributes_eq x, y }
      elsif v.kind_of?(Hash)
        assert_attributes_eq v, model_value
      else
        assert_equal v, model_value
      end
    end
  end

  def assert_successful_eq(model, resp)
    assert_json_eq model, assert_successful(resp)
  end

  def assert_successful_atts_eq(atts, resp)
    body = assert_successful(resp)
    assert_attributes_eq atts, body
    body
  end

  def assert_not_found(resp)
    assert_equal 404, resp.status
  end

  def assert_bad_request(resp, msg = nil)
    assert_equal 400, resp.status
    assert_match /#{msg}/, resp.body if msg
  end

  def assert_validation_error(resp)
    assert_equal 400, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    assert_match /#{'Validation failed'}/, resp.header['X-Status-Reason']
    body = JSON.parse resp.body
    assert_false body.empty?
    body
  end

  def assert_api_error(resp)
    assert_equal 500, resp.status
    assert resp.header['Content-Type'].include?('text/plain')
    assert_false resp.body.empty?
    resp.body
  end

end




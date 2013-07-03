require_relative '../test_helper.rb'

module AcceptanceHelper
  include Rack::Test::Methods
  include FactoryGirl::Syntax::Methods
  include TestHelper

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

  def assert_validation_error(resp)
    assert_equal 400, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    assert resp.header['X-Status-Reason'].include?('Validation failed')
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




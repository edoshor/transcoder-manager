require_relative 'acceptance_helper'

class RoutingTest < Test::Unit::TestCase
  include AcceptanceHelper

  def test_root
    get '/'
    assert_successful_text last_response, /BB Web Broadcast - Transcoder Manager/
  end

  def test_relative_path
    get '/test-redis'
    assert_successful_text last_response, /redis is alive at/

    header 'X-Forwarded-Base-Path', '/something/unknown/goes/here'
    get '/something/unknown/goes/here/test-redis'
    assert_successful_text last_response, /redis is alive at/

    header 'X-Forwarded-Base-Path', '/'
    get '/test-redis'
    assert_successful_text last_response, /redis is alive at/
  end

end

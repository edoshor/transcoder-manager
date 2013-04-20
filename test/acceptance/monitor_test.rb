require_relative 'acceptance_helper'

class MonitorTest < Test::Unit::TestCase
  include AcceptanceHelper

  def test_monitor

    now = Time.now
    (6 * 60 * 2).times do
      now = now - 10
      Time.stubs(:now).returns(now)
      MonitorService.instance.load_status 1, {cpu: rand() * 100, temp: {:'0' => rand() * 100, :'1' => rand() * 100}}
    end
    Time.unstub(:now)

    get '/monitor/1/cpu'
    body = assert_successful last_response
    assert_not_empty body
    assert body.length.between?(358, 360)

    get '/monitor/1/cpu?period=10_minutes'
    body = assert_successful last_response
    assert_not_empty body
    assert body.length.between?(58, 60)

    get '/monitor/1/cpu?period=day'
    body = assert_successful last_response
    assert_not_empty body
    assert_equal 720, body.length

    get '/monitor/1/temp?period=10_minutes'
    body = assert_successful last_response
    assert_not_empty body
    assert body.length.between?(58, 60)
  end

end
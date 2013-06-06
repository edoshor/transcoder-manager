require_relative '../../test_helper'

class TestTranscoderMonitor < Test::Unit::TestCase
  include TestHelper

  def test_initialize
    monitor = TranscoderMonitor.new(1)
    assert_equal 1, monitor.tx_id
    assert_nil monitor.state

    timer = monitor.timer
    assert_not_nil timer
    assert_true timer.recurring
    assert_equal TranscoderMonitor::ALIVE_INTERVAL, timer.interval

    timer = monitor.load_timer
    assert_not_nil timer
    assert_true timer.recurring
    assert_equal TranscoderMonitor::LOAD_INTERVAL, timer.interval
  end

  def test_alive_no_change
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)

    MonitorService.instance.expects(:state_changed).never

    [true, false].each do |state|
      txcoder.expects(:is_alive?).returns(state)
      monitor.state = state
      monitor.check_is_alive
    end
  end

  def test_alive_change
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)

    monitor.state = false
    txcoder.expects(:is_alive?).returns(true).times(4)
    MonitorService.instance.expects(:state_changed).with(txcoder.id, true).once
    4.times { monitor.check_is_alive }

    txcoder.expects(:is_alive?).returns(false).times(TranscoderMonitor::MIN_STATE_CHANGE)
    MonitorService.instance.expects(:state_changed).with(txcoder.id, false).once
    TranscoderMonitor::MIN_STATE_CHANGE.times do
      monitor.check_is_alive
    end
  end

  def test_alive_change_on_wakeup
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)

    txcoder.expects(:is_alive?).returns(true).once
    MonitorService.instance.expects(:wakeup_state).with(txcoder.id, true).once

    monitor.check_is_alive
  end

  def test_parse_response
    resp = Object.new
    resp.expects(:body).returns({:'cpuload' => '23.4 %',
                                 :'cputemp' => [{:'0' => '61.9 C'}, {:'1' => '1.9 C'}]}.to_json)

    monitor = TranscoderMonitor.new(0)
    result = monitor.parse_response resp
    assert_not_nil result
    assert_equal 23.4, result[:cpu]
    assert_equal 61.9, result[:temp]['0']
    assert_equal 1.9, result[:temp]['1']
  end

  def test_get_load_status
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)
    body = {:'cpuload' => '23.4 %',
               :'cputemp' => [{:'0' => '61.9 C'}, {:'1' => '1.9 C'}]}.to_json
    stub_request(:get, "#{txcoder.host}:#{txcoder.status_port}")
    .to_return(status: 200, body: body, headers: {})

    resp = monitor.get_load_status
    assert_not_nil resp
    assert resp.is_a? Net::HTTPSuccess
    assert_equal body, resp.body
  end

  def test_get_load_status_error
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)
    stub_request(:get, "#{txcoder.host}:#{txcoder.status_port}").to_return(status: [500, 'Internal Server Error'])

    resp = monitor.get_load_status
    assert_not_nil resp
    assert_false resp.is_a? Net::HTTPSuccess
  end

  def test_get_load_status_eof_error
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)
    stub_request(:get, "#{txcoder.host}:#{txcoder.status_port}").to_raise(EOFError)

    resp = monitor.get_load_status
    assert_nil resp
  end

  def test_sample_load_status
    txcoder = get_mock_txcoder
    body = {:'cpuload' => '23.4 %',
            :'cputemp' => [{:'0' => '61.9 C'}, {:'1' => '1.9 C'}]}.to_json
    stub_request(:get, "#{txcoder.host}:#{txcoder.status_port}")
    .to_return(status: 200, body: body, headers: {})

    monitor = TranscoderMonitor.new(txcoder.id)
    monitor.state = true

    resp = Object.new
    resp.expects(:body).returns(body)
    MonitorService.instance.expects(:load_status).with(txcoder.id, monitor.parse_response(resp))
    monitor.sample_load_status
  end

  def test_load_status_dead
    txcoder = get_mock_txcoder
    monitor = TranscoderMonitor.new(txcoder.id)
    monitor.state = false

    monitor.sample_load_status
    assert_not_requested :get, "#{txcoder.host}:#{txcoder.status_port}"
  end

  def test_sample_load_status_error
    txcoder = get_mock_txcoder
    stub_request(:get, "#{txcoder.host}:#{txcoder.status_port}").to_raise(EOFError)
    MonitorService.instance.expects(:load_status).never

    monitor = TranscoderMonitor.new(txcoder.id)
    monitor.state = true
    monitor.sample_load_status
  end

  private

  def get_mock_txcoder
    txcoder = create(:transcoder)
    Transcoder.stubs(:[]).with(txcoder.id).returns(txcoder)
    txcoder
  end

end


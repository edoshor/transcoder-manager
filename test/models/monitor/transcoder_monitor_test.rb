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

  def test_load_status_dead
    txcoder = get_mock_txcoder
    txcoder.expects(:load_status).never

    monitor = TranscoderMonitor.new(txcoder.id)
    monitor.state = false

    monitor.sample_load_status
  end

  def test_load_status_alive
    txcoder = get_mock_txcoder
    txcoder.expects(:load_status).returns(:some_result)
    MonitorService.instance.expects(:load_status).with(txcoder.id, :some_result)

    monitor = TranscoderMonitor.new(txcoder.id)
    monitor.state = true

    monitor.sample_load_status
  end

  def test_load_status_error
    txcoder = get_mock_txcoder
    txcoder.expects(:load_status).raises(Transcoder::TranscoderError)
    MonitorService.instance.expects(:load_status).never

    monitor = TranscoderMonitor.new(txcoder.id)
    monitor.state = true

    monitor.sample_load_status
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
    4.times do
      monitor.check_is_alive
    end

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

  private

  def get_mock_txcoder
    txcoder = create(:transcoder)
    Transcoder.stubs(:[]).with(txcoder.id).returns(txcoder)
    txcoder
  end

end


require_relative '../../test_helper'

class TestMonitorService < Test::Unit::TestCase
  include TestHelper

  def test_state_changed
    txcoder = get_mock_txcoder
    MonitorService.instance.state_changed txcoder.id, true

    states = MonitorService.instance.get_metric txcoder.id, 'state', '10_minutes', [0,1]
    assert_not_empty states
    assert_match /true/, states[0]
    assert_mail subject: /UP/
  end

  def test_wakeup_state
    txcoder = get_mock_txcoder
    MonitorService.instance.remove_history txcoder.id

    MonitorService.instance.wakeup_state txcoder.id, true
    states = MonitorService.instance.get_metric txcoder.id, 'state', :all, [0,1]
    assert_not_empty states
    assert_match /true/, states[0]
    assert_no_mail

    sleep 1

    MonitorService.instance.wakeup_state txcoder.id, false
    states = MonitorService.instance.get_metric_reverse txcoder.id, 'state', :all, [0,1]
    assert_not_empty states
    final_state = states[0]
    assert_match /false/, final_state
    assert_mail subject: /DOWN/

    sleep 1

    MonitorService.instance.wakeup_state txcoder.id, false
    states = MonitorService.instance.get_metric_reverse txcoder.id, 'state', :all, [0,1]
    assert_not_empty states
    assert_equal final_state, states[0]
    assert_no_mail
  end

  def test_load_status
    txcoder = get_mock_txcoder
    (1..10).each do |i|
      status = { cpu: i, temp: (0..1).inject({}) {|h, core| h.merge! core => rand(100)} }
      MonitorService.instance.load_status txcoder.id, status
      sleep 0.3
    end

    cpu = MonitorService.instance.get_metric txcoder.id, 'cpu', :all
    cpu_reverse = MonitorService.instance.get_metric_reverse txcoder.id, 'cpu', :all
    assert_not_empty cpu
    assert_equal 10, cpu.size
    assert_equal cpu, cpu_reverse.reverse

    temp = MonitorService.instance.get_metric txcoder.id, 'temp', :all
    temp_reverse = MonitorService.instance.get_metric_reverse txcoder.id, 'temp', :all
    assert_not_empty temp
    assert_equal 2, temp.size
    assert_equal 10, temp[0].size
    assert_equal 10, temp[1].size
    assert_equal temp[0], temp_reverse[0].reverse
    assert_equal temp[1], temp_reverse[1].reverse
  end

  private

  def get_mock_txcoder
    txcoder = create(:transcoder)
    Transcoder.stubs(:[]).with(txcoder.id).returns(txcoder)
    txcoder
  end

  def assert_mail(opts)
    assert_not_empty Mail::TestMailer.deliveries
    mail = Mail::TestMailer.deliveries[0]
    assert_match opts[:subject], mail.subject if opts[:subject]
    assert_match opts[:body], mail.subject if opts[:body]
    Mail::TestMailer.deliveries.clear
  end

  def assert_no_mail
    assert_empty Mail::TestMailer.deliveries
  end

end


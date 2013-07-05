require_relative '../test_helper'

class TestSlot < Test::Unit::TestCase
  include TestHelper

  def test_start
    slot = create_slot()
    slot.transcoder.expects(:start_slot).with(){|s| s === slot}.returns(nil)
    slot.start
  end

  def test_stop
    slot = create_slot()
    slot.transcoder.expects(:stop_slot).with() {|s| s === slot}.returns(nil)
    slot.stop
  end

  def test_running
    slot = create_slot()
    slot.transcoder.expects(:get_slot_status).with() {|s| s === slot}.returns({message: 'running'})
    assert slot.running

    slot.transcoder.expects(:get_slot_status).with() {|s| s === slot}.returns({message: 'stopped'})
    assert_false slot.running

    slot.transcoder.expects(:get_slot_status).with() {|s| s === slot}.raises
    assert_false slot.running
  end

  private

  def create_slot
    slot = Slot.new(slot_id: 1)
    slot.transcoder = create(:transcoder)
    slot
  end

end


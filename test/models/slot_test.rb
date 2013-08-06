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

  def test_find_by_scheme
    scheme = create(:scheme)
    slot = Slot.create(slot_id: 1, transcoder: create(:transcoder), scheme: scheme)
    assert_not_empty Slot.find_by_scheme scheme
    slot.delete
    assert_empty Slot.find_by_scheme scheme
  end

  private

  def create_slot
    slot = Slot.new(slot_id: 1)
    slot.transcoder = create(:transcoder)
    slot
  end

end


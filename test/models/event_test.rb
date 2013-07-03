require_relative '../test_helper'

class TestEvent < Test::Unit::TestCase
  include TestHelper

  def test_add_slot
    event = Event.create(name: 'event1')
    assert_empty event.slots

    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)
    slot.expects(:start).never
    event.add_slot slot
  end

  def test_add_slot_when_running
    event = Event.create(name: 'event1')
    event.running = true

    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)
    slot.expects(:running).returns(false)
    slot.expects(:start).once
    event.add_slot slot

    event.slots.delete(slot)
    slot.expects(:running).returns(true)
    slot.expects(:start).never
    event.add_slot slot
  end

  def test_other_running_events_slots
    event1 = Event.create(name: 'event1')
    assert_empty event1.other_running_events_slots

    # we can't mock slots as they are fetched from redis in the method.
    # we need to mock the transcoder api ...

    #event2 = Event.create(name: 'event2')
    #scheme = create(:scheme)
    #txcoder = create(:transcoder)
    #slot1 = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)
    #slot1.expects(:running).returns(true)
    #
    #event2.add_slot slot1
    #event2.update running: true
    #assert_include event1.other_running_events_slots, slot1
    #assert_empty event2.other_running_events_slots
  end

end


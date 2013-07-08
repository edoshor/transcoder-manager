require_relative '../test_helper'

class TestEvent < Test::Unit::TestCase
  include TestHelper

  def test_other_running
    event1 = Event.create(name: 'event1')
    assert_empty event1.other_running_events_slots

    event2 = Event.create(name: 'event2')
    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slot1 = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)

    slot1.expects(:running).returns(true)
    event2.expects(:slots).returns([slot1])
    Event.stubs(:find).with() {|h| h[:running] }.returns([event2])

    assert_include event1.other_running_events_slots, slot1
    assert_empty event2.other_running_events_slots
  end

  def test_add_slot
    event = Event.create(name: 'event1')
    assert_empty event.slots

    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)
    slot.expects(:start).never
    event.add_slot slot

    event.add_slot slot # test duplicate
    assert_equal 1, event.slots.size
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

  def test_remove_slot
    event = Event.create(name: 'event1')
    scheme = create(:scheme)
    txcoder = create(:transcoder)

    slots = 3.times.map { |i| Slot.create(slot_id: i, transcoder: txcoder, scheme: scheme) }
    slots.each {|slot| event.add_slot slot }

    slots.each do |slot|
      slot.expects(:stop)
      event.remove_slot slot
    end

    assert_empty event.slots
  end

  def test_remove_slot_other_running
    event = Event.create(name: 'event1')
    scheme = create(:scheme)
    txcoder = create(:transcoder)

    slots = 3.times.map { |i| Slot.create(slot_id: i, transcoder: txcoder, scheme: scheme) }
    slots.each {|slot| event.add_slot slot }

    event2 = Event.create(name: 'event2')
    slots[0].expects(:running).returns(true)
    event2.expects(:slots).returns([slots[0]])
    Event.stubs(:find).with() {|h| h[:running] }.returns([event2])

    slots[0].expects(:stop).never
    event.remove_slot slots[0]
    assert_equal 2, event.slots.size

    #slots[1].expects(:stop)
    #event.remove_slot slots[1]
    #assert_equal 1, event.slots.size
    #slots[2].expects(:stop)
    #event.remove_slot slots[2]
    #assert_empty event.slots
  end

  def test_start
    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slots = 3.times.map { |i| Slot.create(slot_id: i, transcoder: txcoder, scheme: scheme) }

    slots[0].expects(:start).never
    slots[1].expects(:start).never
    slots[2].expects(:start).once

    event = Event.create(name: 'event1')
    event.expects(:other_running_events_slots).returns(Set.new slots[0..1])
    event.expects(:slots).returns([slots[0], slots[2]])

    event.start
    state = event.state
    assert state[:running]
    assert_in_epsilon Time.now.to_i, state[:last], 5
  end

  def test_stop
    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slots = 3.times.map { |i| Slot.create(slot_id: i, transcoder: txcoder, scheme: scheme) }

    slots[0].expects(:stop).never
    slots[1].expects(:stop).never
    slots[2].expects(:stop).once

    event = Event.create(name: 'event1')

    event.expects(:other_running_events_slots).returns(Set.new slots[0..1])
    event.expects(:slots).returns([slots[0], slots[2]])

    event.stop
    state = event.state
    assert_false state[:running]
    assert_in_epsilon Time.now.to_i, state[:last], 5
  end


end


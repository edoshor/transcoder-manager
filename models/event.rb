require 'ohm'
require 'ohm/datatypes'

class Event < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  attribute :running, Type::Boolean
  attribute :last_switch, Type::Timestamp
  list :slots, :Slot
  unique :name
  index :running

  def validate
    assert_present :name
  end

  def to_hash
    super.merge(name: name)
  end

  def to_s
    "Event: name=#{name}, slots count = #{slots.size}"
  end

  def start
    other_slots = other_running_events_slots
    slots.each { |slot| slot.start if other_slots.add? slot }
    update running: true, last_switch: Time.now.to_i
  end

  def stop
    other_slots = other_running_events_slots
    slots.each { |slot| slot.stop unless other_slots.delete? slot }
    update running: false, last_switch: Time.now.to_i
  end

  def state
    {running: running, last_switch: last_switch}
  end

  def add_slot(slot)
    slots.push(slot)
    slot.start if running && !slot.running
  end

  def remove_slot(slot)
    slots.delete(slot)
    other_slots = other_running_events_slots
    slot.stop unless other_slots.delete? slot
  end

  def other_running_events_slots
    slots = Set.new
    Event.find(running: true).each { |event| slots.merge(event.slots) unless event == self }
    slots.keep_if { |slot| slot.running rescue false}
  end

end
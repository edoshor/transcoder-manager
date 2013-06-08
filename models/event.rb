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
    running = true
    last_switch = Time.now.to_i
    other_slots = other_events_running_slots
    slots.each { |slot| slot.start if other_slots.add? slot }
  end

  def stop
    running = false
    last_switch = Time.now.to_i
    other_slots = other_events_running_slots
    slots.each { |slot| slot.stop unless other_slots.delete? slot }
  end

  def state
    {running: running, last_switch: last_switch}
  end

  def other_events_running_slots
    find(running: true).inject(Set.new) { |s, event| s + event.slots unless event == self }
    .keep_if { |slot| slot.running }
  end

end
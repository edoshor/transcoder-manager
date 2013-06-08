require 'ohm'
require 'ohm/datatypes'

class Event < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  attribute :running, Type::Boolean
  attribute :last_switch, Type::Timestamp
  list :slots, :Slot
  unique :name

  def validate
    assert_present :name
  end

  def to_hash
    super.merge(name: name, slots: slots.map { |s| s.to_hash })
  end

  def to_s
    "Event: name=#{name}, slots count = #{slots.size}"
  end

  def start
    running = true
    last_switch = Time.now.to_i
  end

  def stop
    running = false
    last_switch = Time.now.to_i
  end

  def state
    {running: running, last_switch: last_switch}
  end

end
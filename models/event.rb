class Event < BaseModel

  attribute :name
  attribute :csid
  attribute :running, Type::Boolean
  attribute :last_switch, Type::Timestamp
  list :slots, :Slot
  unique :name
  unique :csid
  index :running

  required_params %w(name csid)

  def validate
    assert_present :name
    assert_present :csid
  end

  def to_hash
    super.merge(name: name, csid: csid)
  end

  def to_s
    "Event: name=#{name}, csid=#{csid}, slots count = #{slots.size}"
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
    slots.push(slot) unless slots.include? slot
    slot.start if running && !slot.running
  end

  def remove_slot(slot)
    slots.delete(slot)
    slot.stop unless other_running_events_slots.delete? slot
  end

  def other_running_events_slots
    slots = Set.new
    Event.find(running: true).each do |event|
      slots.merge(event.slots) unless event == self
    end
    slots.keep_if { |slot| slot.running rescue false }
  end

  def self.slot_in_use? (slot)
    all.any? { |event| event.slots.include? slot }
  end

  def self.create_from_hash(atts)
    slot_ids = atts.delete(:slots)
    event = create(atts)
    slot_ids.each { |x| event.slots.push Slot[x] } unless slot_ids.blank?
    event
  end

end
class Event < BaseModel

  attribute :name
  attribute :csid
  attribute :state
  attribute :running, Type::Boolean
  attribute :last_switch, Type::Timestamp
  list :slots, :Slot
  unique :name
  unique :csid
  index :running
  index :csid

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

  def change_state(new_state)
    return if state == new_state

    if new_state == 'on'
      start unless running
      call_external_controllers(:on)
    elsif new_state == 'off'
      stop
      call_external_controllers(:off)
    elsif new_state == 'ready'
      start unless running
      call_external_controllers(:ready)
    else
      raise "Unknown new state #{new_state}"
    end
    update state: new_state, last_switch: Time.now.to_i
  end

  def start
    other_slots = other_running_events_slots
    slots.each { |slot| slot.start if other_slots.add? slot }
    update running: true
  end

  def stop
    other_slots = other_running_events_slots
    slots.each { |slot| slot.stop unless other_slots.delete? slot }
    update running: false
  end

  def call_external_controllers(new_state)
    urls = [STREAMS_CONTROLLER]
    mutex_csid = nil
    if csid == 'public'
      mutex_csid = 'private'
      urls.append(KABTV_CONTROLLER) unless new_state == :ready && self.state == 'off'
    end
    if csid == 'private'
      urls.append(GROUPS_CONTROLLER)
      mutex_csid = 'public'
    end

    if mutex_csid
      urls.append(AUDIO_CONTROLLER) unless Event.find(csid: mutex_csid).any? {|e| e.state == 'on'}
    end

    command = 'start'
    if new_state == :off || (new_state == :ready && self.state == 'on')
        command = 'stop'
    end

    args = {csid: csid, command: command}
    urls.each do |u|
      url = u % args
      Thread.new do
        begin
          uri = URI.parse(url)
          http = Net::HTTP.new(uri.host, uri.port)
          request = Net::HTTP::Get.new(uri.request_uri)
          resp = http.request(request)
          resp.value
          puts "calling #{url}: successful"
        rescue Exception => e
          puts "calling #{url}: failed #{e.message}"
        end
      end
    end

    # Sviva Tova is special - we need to use POST requests
    if csid=='private' || csid=='sadna'
      Thread.new do
        begin
          uri = URI.parse(SVIVA_TOVA_CONTROLLER)
          resp = Net::HTTP.post_form(uri,{ 'stream_preset_id' => SVIVA_TOVA_STREAM_PRESET_IDS[csid.to_sym],
                                           'state' => SVIVA_TOVA_STATES[new_state]})
          resp.value
          puts 'calling sviva tova: successful'
        rescue Exception => e
          puts "calling sviva tova: failed #{e.message}"
        end
      end
    end

  end

  def status
    {state: state, running: running, last_switch: last_switch}
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

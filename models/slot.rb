class Slot < BaseModel

  attribute :slot_id, Type::Integer
  reference :transcoder, :Transcoder
  reference :scheme, :Scheme
  index :slot_id

  required_params %w(transcoder_id slot_id scheme_id)

  def validate
    assert_numeric :slot_id
    assert slot_id.between?(0, 255), [:slot_id, :not_in_range]
    assert_present :transcoder
    #assert_present :scheme # we relax this for sake of config synchronization
  end

  def to_hash
    super.merge(slot_id: slot_id,
        transcoder_id: transcoder.id,
        transcoder_name: transcoder.name,
        scheme_id: scheme ? scheme.id : nil,
        scheme_name: scheme ? scheme.name : nil)
  end

  def to_s
    "Slot: slot_id=#{slot_id}, transcoder_id=#{transcoder.id}, scheme_id=#{scheme ? scheme.id : nil}"
  end

  def running
    begin
      status = transcoder.get_slot_status(self)
      status[:message].include? 'running'
    rescue
      false
    end
  end

  def start
    transcoder.start_slot self
  end

  def stop
    transcoder.stop_slot self
  end

  def self.find_by_scheme(scheme)
    find(scheme_id: scheme.id)
  end

  def self.create_from_hash(atts)
    atts.delete(:transcoder_name)
    atts.delete(:scheme_name)
    atts[:transcoder] = Transcoder[atts.delete(:transcoder_id)]
    atts[:scheme] = Scheme[atts.delete(:scheme_id)]
    Slot.create(atts)
  end

  def self.params_to_attributes(params)
    super(params) do |atts|
      atts[:transcoder] = Transcoder[atts.delete(:transcoder_id)]
      atts[:scheme] = Scheme[atts.delete(:scheme_id)]
    end
  end
end
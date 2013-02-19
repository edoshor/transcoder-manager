require 'ohm'

class Slot < Ohm::Model
  attribute :slot_id
  reference :transcoder, :Transcoder
  reference :scheme, :Scheme

  def validate
    assert_numeric :slot_id
    assert slot_id.to_i.between?(0,255), [:slot_id, :not_in_range]
    assert_present :transcoder
    assert_present :scheme
  end

  def to_hash
    super.merge(slot_id: slot_id,
        transcoder_id: transcoder.id,
        transcoder_name: transcoder.name,
        scheme_id: scheme.id,
        scheme_name: scheme.name)
  end

  def to_s
    "Slot: slot_id=#{slot_id}, transcoder_id=#{transcoder.id}, scheme_id=#{scheme.id}"
  end

end
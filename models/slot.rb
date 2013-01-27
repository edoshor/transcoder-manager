require 'ohm'

class Slot < Ohm::Model
  attribute :slot_id
  reference :transcoder, :Transcoder
  reference :preset, :Preset

  def validate
    assert_numeric :slot_id
    assert slot_id.to_i.between?(0,255), [:slot_id, :not_in_range]
  end

  def to_hash
    super.merge(slot_id: slot_id,
        transcoder_id: transcoder.id,
        transcoder_name: transcoder.name,
        preset_id: (preset.nil? ? nil : preset.id),
        preset_name: (preset.nil? ? nil : preset.name))
  end

  def to_s
    "Slot: slot_id=#{slot_id}, transcoder_id=#{transcoder.id}, preset_id=#{(preset.nil? ? nil : preset.id)}"
  end

end
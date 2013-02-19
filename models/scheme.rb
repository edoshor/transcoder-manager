require 'ohm'

class Scheme < Ohm::Model
  attribute :name
  attribute :audio_mappings
  reference :preset, :Preset
  reference :src1, :Source
  reference :src2, :Source
  unique :name


  def validate
    assert_present :name
    assert_present :audio_mappings
    assert_present :preset
    assert_present :src1
    assert audio_mappings.is_a?(Array) ,[:audio_mappings, :not_array]
    assert audio_mappings.length >= preset.tracks.size , [:audio_mappings, :less_than_preset_tracks]
  end

  def to_hash
    super.merge(name: name,
                audio_mappings: audio_mappings,
                preset_id: preset.id,
                preset_name: preset.name,
                src1_id: src1.id,
                src1_name: src1.name,
                src2_id: (src2.nil? ? nil : src2.id),
                src2_name: (src2.nil? ? nil : src2.name)
    )
  end

  def to_s
    "Scheme: name=#{name}, preset=#{preset.name}, src1=#{src1.name},
      src2=#{(src2.nil? ? nil : src2.name)}"
  end
end
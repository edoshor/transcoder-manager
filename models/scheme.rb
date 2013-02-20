require 'ohm'
require 'ohm/datatypes'

class Scheme < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  attribute :audio_mappings, Type::Array
  reference :preset, :Preset
  reference :src1, :Source
  reference :src2, :Source
  unique :name


  def validate
    assert_present :name
    assert_present :audio_mappings
    assert_present :preset
    assert_present :src1

    track_cnt = preset.tracks.size
    assert audio_mappings.is_a?(Array) ,[:audio_mappings, :not_array]
    audio_mappings.each do |e|
      assert e == e.to_i.to_s, [:audio_mappings, :not_numeric_mapping]
      assert e.to_i.between?(0, track_cnt), [:audio_mappings, :invalid_mapping]
    end
    assert audio_mappings.length >= track_cnt, [:audio_mappings, :less_than_preset_tracks]
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

  def to_start_args
    ip1 = ip2 = src1.host
    port1 = port2 = src1.port
    unless src2.nil?
      ip2 = src2.host
      port2 = src2.port
    end

    [ip1, port1, ip2, port2, audio_mappings.length, audio_mappings.map {|e| e.to_i} ]
  end
end
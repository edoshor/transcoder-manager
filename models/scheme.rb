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
      assert e.to_s == e.to_i.to_s, [:audio_mappings, :not_numeric_mapping]
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
    [src1.host, # ip1
     src1.port, # port1
     src2.nil? ? src1.host : src2.host, # ip2
     src2.nil? ? src1.port : src2.port, # port2
     audio_mappings.length, # track_cnt
     audio_mappings.map {|e| e.to_i}  # tracks
    ]
  end

  # Try to find a Scheme with the parameters returned from the given
  # low level api results.
  #
  # If no match was found we create a new scheme.
  #
  # @param preset_resp result of mod_get_slot
  # @param status_resp result of mod_get_slot_status
  #
  def self.match_or_create(preset, status)
    src1 = Source.match_or_create(status[:ip1], status[:port1])
    src2 = Source.match_or_create(status[:ip2], status[:port2])
    preset = Preset.match_or_create preset[:tracks]

    scheme = nil

    results = find(src1_id: src1.id, src2_id: src2.id, preset_id: preset.id)
    unless results.nil? || results.empty?
      results.each do |s|
        scheme = s if status[:tracks] == s.audio_mappings.map{|x| x.to_i }
        break unless scheme.nil?
      end
    end

    if scheme.nil?
      name = "unknown_scheme_#{SecureRandom.hex(2)}"
      scheme = create(name: name, src1: src1, src2: src2, preset: preset, audio_mappings: status[:tracks])
    end

    scheme
  end
end
class Scheme < BaseModel

  attribute :name
  attribute :audio_mappings, Type::Array
  reference :preset, :Preset
  reference :src1, :Source
  reference :src2, :Source
  unique :name

  required_params %w(name preset_id source1_id audio_mappings)
  optional_params %w(source2_id)

  def validate
    assert_present :name
    assert_present :audio_mappings
    assert_present :preset
    assert_present :src1

    track_cnt = preset.tracks.size
    assert audio_mappings.is_a?(Array), [:audio_mappings, :not_array]
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
                src2_id: (src2 ? src2.id : nil),
                src2_name: (src2 ? src2.name : nil)
    )
  end

  def to_s
    "Scheme: name=#{name}, preset=#{preset.name}, src1=#{src1.name},
      src2=#{(src2 ? src2.name : nil)}"
  end

  def to_start_args
    ip1 = src1.host
    port1 = src1.port
    [ip1, # ip1
     port1, # port1
     src2 ? src2.host : ip1, # ip2
     src2 ? src2.port : port1, # port2
     audio_mappings.length, # track_cnt
     audio_mappings.map { |e| e.to_i }  # tracks
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

    results = find(src1_id: src1.id, src2_id: src2.id, preset_id: preset.id)
    scheme = results ? results.detect { |s| status[:tracks] == s.audio_mappings.map { |x| x.to_i } } : nil

    if scheme
      scheme
    else
      create(name: "unknown_scheme_#{SecureRandom.hex(2)}",
             src1: src1, src2: src2, preset: preset, audio_mappings: status[:tracks])
    end
  end

  def self.source_in_use?(source)
    !find(src1_id: source.id).empty? || !find(src2_id: source.id).empty?
  end

  def self.preset_in_use?(preset)
    !find(preset_id: preset.id).empty?
  end

  def self.create_from_hash(atts)
    %w(preset_name src1_name src2_name).each {|k| atts.delete k.to_sym }
    atts[:src1] = Source[atts.delete(:src1_id)]
    atts[:src2] = Source[atts.delete(:src2_id)]
    atts[:preset] = Preset[atts.delete(:preset_id)]
    create(atts)
  end

  def self.params_to_attributes(params)
    super(params) do |atts|
      atts[:src1] = Source[atts.delete(:source1_id)]
      atts[:src2] = Source[atts.delete(:source2_id)] if atts.key?(:source2_id)
      atts[:preset] = Preset[atts.delete(:preset_id)]
    end
  end

end
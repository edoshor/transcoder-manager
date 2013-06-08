require 'ohm'

class Preset < Ohm::Model
  attribute :name
  list :tracks, :Track
  unique :name

  def validate
    assert_present :name
  end

  def to_hash
    super.merge(name: name, tracks: tracks.map { |t| t.to_hash })
  end

  def to_s
    "Preset: name=#{name}, track_cnt=#{tracks.size}"
  end

  def self.match(profiles)
    Preset.all.detect { |p| profiles == p.tracks.map { |t| t.to_a } }
  end

  def self.match_or_create(profiles)
    match(profiles) or create_unknown(profiles)
  end

  private

  def self.create_unknown(profiles)
    preset = Preset.create(name: "unknown_preset_#{SecureRandom.hex(2)}")
    profiles.each { |t| preset.tracks.push Track.from_a(t).save }
    preset
  end

end
require 'ohm'

class Preset < Ohm::Model
  attribute :name
  list :tracks, :Track
  unique :name

  def validate
    assert_present :name
  end

  def to_hash
    super.merge(name: name, tracks: tracks.map { |t| t.to_hash})
  end

  def to_s
    "Preset: name=#{name},track_cnt=#{tracks.size}"
  end

  def self.match(profiles)
    preset = nil
    Preset.all.each do |p|
      preset = p if profiles == p.tracks.map {|t| t.to_a}
      break unless preset.nil?
    end
    preset
  end

  def self.match_or_create(profiles)
    preset = Preset.match profiles
    if preset.nil?
      name = "unknown_preset_#{SecureRandom.hex(2)}"
      preset = Preset.create(name: name)
      profiles.each do |track_def|
        preset.tracks.push Track.from_a(track_def).save
      end
    end
    preset
  end

end
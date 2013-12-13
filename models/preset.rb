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

  def set_tracks(tracks_details)
    new_tracks = tracks_details.map { |t| Track.new(t) }
    raise 'not enough tracks' unless new_tracks.length > 1
    raise 'invalid tracks' unless new_tracks.all? { |t| t.valid?  }
    raise 'invalid tracks sequence' unless new_tracks[0].is_video? && new_tracks[1].is_audio?

    save
    new_tracks.each { |t| t.save and tracks.push t }
  end

  def self.match(profiles)
    Preset.all.detect { |p| profiles == p.tracks.map { |t| t.to_a } }
  end

  def self.match_or_create(profiles)
    match(profiles) or create_unknown(profiles)
  end

  def self.create_from_hash(atts)
    profiles = atts.delete(:tracks)
    preset = Preset.create(atts)
    profiles.map { |p| preset.tracks.push Track.create_from_hash(p) }
    preset
  end

  private

  def self.create_unknown(profiles)
    preset = Preset.create(name: "unknown_preset_#{SecureRandom.hex(2)}")
    profiles.each { |t| preset.tracks.push Track.from_a(t).save } unless profiles.blank?
    preset
  end

end
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

end
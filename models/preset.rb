require 'ohm'

class Preset < Ohm::Model
  attribute :name
  list :tracks, :Track

  def validate
    assert_present :name
  end

  def to_hash
    super.merge(name: name, tracks: tracks.map { |track| track.to_hash})
  end

  def to_s
    "Preset: name=#{name},track_cnt=#{tracks.size}"
  end
end
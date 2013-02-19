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
end
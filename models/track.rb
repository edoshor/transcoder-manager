require 'ohm'
require 'ohm/datatypes'

class Track < Ohm::Model
  include Ohm::DataTypes

  # for video should be 0, for audio means gain from 1 to 50, 10 means no gain
  attribute :gain, Type::Integer

  # 1 for mono, 2 for stereo, 0 for video profile
  attribute :num_channels, Type::Integer

  # 1-100 for video, 101-254 for audio
  attribute :profile_number, Type::Integer


  def validate
    assert_numeric :gain
    #assert gain.between?(0, 50) , [:gain, :not_in_range]
    assert_numeric :num_channels
    assert num_channels.between?(0, 2) , [:num_channels, :not_in_range]
    assert_numeric :profile_number
    assert profile_number.between?(1, 254) , [:profile_number, :not_in_range]

    if num_channels == 0
      assert gain == 0, [:gain, :should_be_zero_for_video]
      assert profile_number.between?(1, 100), [:profile_number, :not_in_range_for_video]
    else
      #assert gain.to_i > 0, [:gain, :should_not_be_zero_for_audio]
      assert profile_number.between?(101, 254), [:profile_number, :not_in_range_for_audio]
    end
  end

  def to_hash
    super.merge(
        gain: gain,
        num_channels: num_channels,
        profile_number: profile_number)
  end

  def to_s
    "Track: gain=#{gain}, num_channels=#{num_channels} profile_number=#{profile_number}"
  end

  def to_a
    [profile_number, num_channels, gain, 0]
  end

  def is_video?
    num_channels == 0
  end

  def self.from_a(track)
    Track.new profile_number: track[0], num_channels: track[1], gain: track[2]
  end

end
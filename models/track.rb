require 'ohm'

class Track < Ohm::Model
  attribute :gain # for video should be 0, for audio means gain from 1 to 50, 10 means no gain
  attribute :num_channels # 1 for mono, 2 for stereo, 0 for video profile
  attribute :profile_number # 1-100 for video, 101-254 for audio


  def validate
    assert_numeric :gain
    assert gain.to_i.between?(0, 50) , [:gain, :not_in_range]
    assert_numeric :num_channels
    assert num_channels.to_i.between?(0, 2) , [:num_channels, :not_in_range]
    assert_numeric :profile_number
    assert profile_number.to_i.between?(1, 254) , [:profile_number, :not_in_range]

    if num_channels.to_i == 0
      assert gain.to_i == 0, [:gain, :should_be_zero_for_video]
      assert profile_number.to_i.between?(1, 100), [:profile_number, :not_in_range_for_video]
    else
      assert gain.to_i > 0, [:gain, :should_not_be_zero_for_audio]
      assert profile_number.to_i.between?(101, 254), [:profile_number, :not_in_range_for_audio]
    end
  end

  def to_hash
    super.merge(gain: gain,
                num_channels: num_channels,
                profile_number: profile_number)
  end

  def to_s
    "Track: gain=#{gain}, num_channels=#{num_channels} profile_number=#{profile_number}"
  end

  def to_a
    [profile_number, num_channels, gain, 0]
  end

end
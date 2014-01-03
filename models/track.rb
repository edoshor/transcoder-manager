class Track < BaseModel

  # should be 0 for video continuous integer for audio
  attribute :gain, Type::Integer

  # 1 for mono, 2 for stereo, 0 for video profile
  attribute :num_channels, Type::Integer

  # 1-100 for video, 101-254 for audio
  attribute :profile_number, Type::Integer

  required_params %w(gain num_channels profile_number)

  def validate
    assert_numeric :gain
    assert_numeric :num_channels
    assert num_channels.between?(0, 2) , [:num_channels, :not_in_range]
    assert_numeric :profile_number
    assert profile_number.between?(1, 254) , [:profile_number, :not_in_range]

    if num_channels == 0
      assert gain == 0, [:gain, :should_be_zero_for_video]
      assert profile_number.between?(1, 100), [:profile_number, :not_in_range_for_video]
    else
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

  def is_audio?
    not is_video?
  end

  def self.from_a(track)
    new profile_number: track[0], num_channels: track[1], gain: track[2]
  end

  def self.create_from_hash(atts)
    create(atts)
  end

end
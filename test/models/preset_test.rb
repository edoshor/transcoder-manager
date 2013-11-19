require_relative '../test_helper'

class TestPreset < Test::Unit::TestCase
  include TestHelper

  def test_set_tracks
    preset = Preset.new(name: 'test_preset')
    assert_raise_message('not enough tracks') {
      preset.set_tracks([{gain: 0, num_channels: 0, profile_number: 1}])
    }
    assert_raise_message('invalid tracks') {
      preset.set_tracks([{gain: 0, num_channels: 0},
                         {gain: 0, num_channels: 0, profile_number: 1}])
    }
    assert_raise_message('invalid tracks sequence') {
      preset.set_tracks([{gain: 100, num_channels: 1, profile_number: 101},
                         {gain: 0, num_channels: 0, profile_number: 1}])
    }

    assert_true preset.new?
    preset.set_tracks([{gain: 0, num_channels: 0, profile_number: 1},
                       {gain: 100, num_channels: 1, profile_number: 101}])
    assert_false preset.new?
    assert_equal 2, preset.tracks.size
    preset.tracks.each {|t| assert_false t.new?}
  end

  def test_match
    presets = create_list(:preset, 10)
    presets.each do |p|
      assert_equal p, Preset.match(p.tracks.map { |t| t.to_a })
    end
  end

  def test_match_or_create
    profiles = build_list(:audio_track, 7).map { |t| t.to_a }

    assert_nil Preset.match profiles

    match = Preset.match_or_create profiles
    assert_not_nil match
    assert_match(/unknown_preset_[0-9a-f]{4}/, match.name)
    assert_equal profiles, match.tracks.map { |t| t.to_a }
  end

end


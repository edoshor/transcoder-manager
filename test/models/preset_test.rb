require_relative '../test_helper'

class TestPreset < Test::Unit::TestCase
  include TestHelper

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


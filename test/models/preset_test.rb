require_relative '../test_helper'

class TestPreset < Test::Unit::TestCase
  include TestHelper

  def test_match
    10.times do
      preset = create(:preset)
      match = Preset.match preset.tracks.map {|t| t.profile_number}
      assert_equal preset, match
    end
  end

end


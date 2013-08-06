require_relative '../test_helper'

class TestScheme < Test::Unit::TestCase
  include TestHelper

  def test_match_or_create
    10.times do
      scheme = create(:scheme)

      preset = {tracks: scheme.preset.tracks.map { |t| t.to_a } }
      status = {ip1: scheme.src1.host,
                port1: scheme.src1.port,
                ip2: scheme.src2.host,
                port2: scheme.src2.port,
                tracks: scheme.audio_mappings.to_a
      }

      match = Scheme.match_or_create preset, status
      assert_equal scheme, match
    end
  end

  def test_source_in_use
    scheme1 = create(:scheme)
    scheme2 = create(:scheme)

    assert Scheme.source_in_use? scheme1.src1
    assert Scheme.source_in_use? scheme1.src2
    assert Scheme.source_in_use? scheme2.src1
    assert Scheme.source_in_use? scheme2.src2

    assert_false Scheme.source_in_use? create(:source)
  end

  def test_preset_in_use
    scheme1 = create(:scheme)
    scheme2 = create(:scheme)

    assert Scheme.preset_in_use? scheme1.preset
    assert Scheme.preset_in_use? scheme2.preset

    assert_false Scheme.preset_in_use? create(:preset)
  end
end


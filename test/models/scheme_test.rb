require_relative '../test_helper'

class TestScheme < Test::Unit::TestCase
  include TestHelper

  def test_match_or_create
    10.times do
      scheme = create(:scheme)

      preset = {tracks: scheme.preset.tracks.map {|t| t.to_a} }
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

end


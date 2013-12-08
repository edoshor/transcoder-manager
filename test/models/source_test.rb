require_relative '../test_helper'

class TestSource < Test::Unit::TestCase
  include TestHelper

  def test_match_or_create
    sources = build_list(:source, 5)

    sources.each do |s|
      assert_nil Source.find(capture_id: s.capture.id, input: s.input).first
      match = Source.match_or_create(s.host, s.port)
      assert_not_nil match
      assert_match(/unknown_source_[0-9a-f]{4}/, match.name)
      assert_equal s.host, match.host
      assert_equal s.port, match.port
    end

  end

end


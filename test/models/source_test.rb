require_relative '../test_helper'

class TestScource < Test::Unit::TestCase
  include TestHelper

  def test_first_by_address
    sources = create_list(:source, 5)
    sources.each do |s|
      assert_equal s, Source.first_by_address(s.host, s.port)
    end

    assert_nil Source.first_by_address('host', 0)
  end

  def test_match_or_create
    sources = build_list(:source, 5)

    sources.each do |s|
      assert_nil Source.first_by_address(s.host, s.port)
      match = Source.match_or_create(s.host, s.port)
      assert_not_nil match
      assert_match /unknown_source_[0-9a-f]{4}/, match.name
      assert_equal s.host, match.host
      assert_equal s.port, match.port
    end

  end

end


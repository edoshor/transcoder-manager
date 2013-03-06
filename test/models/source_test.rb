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

end


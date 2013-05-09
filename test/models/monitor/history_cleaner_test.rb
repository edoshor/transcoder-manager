require_relative '../../test_helper'

class TestHistoryCleaner < Test::Unit::TestCase
  include TestHelper

  def test_initialize
    cleaner = HistoryCleaner.new

    timer = cleaner.timer
    assert_not_nil timer
    assert_true timer.recurring
    assert_equal HistoryCleaner::CLEAN_INTERVAL, timer.interval
  end

end


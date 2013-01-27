require 'test/unit'
require_relative '../test_helper'
require_relative '../../models/transcoder'
require_relative '../../models/slot'

class TestTranscoder < Test::Unit::TestCase

  def test_get_slot
    transcoder = Transcoder.new
    slot = Slot.new(slot_id: 1, transcoder: transcoder)
    tmp_slot = transcoder.get_slot slot.slot_id

  end

end


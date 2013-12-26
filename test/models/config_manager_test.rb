require_relative '../test_helper'

class TestConfigManager < Test::Unit::TestCase
  include TestHelper

  def test_can_delete_capture?
    capture = create(:capture)
    assert_true ConfigManager.can_delete? capture
    source = create(:source, capture: capture)
    assert_false ConfigManager.can_delete? capture
    source.delete
    assert_true ConfigManager.can_delete? capture
  end

  def test_can_delete_source?
    source = create(:source)
    assert_true ConfigManager.can_delete? source
    scheme = create(:scheme, src1: source)
    assert_false ConfigManager.can_delete? source
    scheme.delete
    assert_true ConfigManager.can_delete? source
    scheme = create(:scheme, src2: source)
    assert_false ConfigManager.can_delete? source
    scheme.delete
    assert_true ConfigManager.can_delete? source
  end

  def test_can_delete_preset?
    preset = create(:preset)
    assert_true ConfigManager.can_delete? preset
    scheme = create(:scheme, preset: preset)
    assert_false ConfigManager.can_delete? preset
    scheme.delete
    assert_true ConfigManager.can_delete? preset
  end

  def test_can_delete_scheme?
    scheme = create(:scheme)
    assert_true ConfigManager.can_delete? scheme
    slot = create(:slot, scheme: scheme)
    assert_false ConfigManager.can_delete? scheme
    slot.delete
    assert_true ConfigManager.can_delete? scheme
  end

  def test_can_delete_event?
    event = create(:event)
    assert_true ConfigManager.can_delete? event
    slot = create(:slot)
    event.add_slot slot
    assert_true ConfigManager.can_delete? event
    slot.delete
    assert_true ConfigManager.can_delete? event
  end

  def test_can_delete_slot?
    slot = create(:slot)
    assert_true ConfigManager.can_delete? slot
    event = create(:event)
    event.add_slot slot
    assert_false ConfigManager.can_delete? slot
    begin event.remove_slot slot rescue nil end
    assert_true ConfigManager.can_delete? slot
  end

  def test_can_delete_transcoder?
    transcoder = create(:transcoder)
    assert_true ConfigManager.can_delete? transcoder
    slot = create(:slot, transcoder: transcoder)
    begin transcoder.create_slot slot rescue nil end
    assert_true ConfigManager.can_delete? transcoder
    event = create(:event)
    event.add_slot slot
    assert_false ConfigManager.can_delete? transcoder
    begin event.remove_slot slot rescue nil end
    assert_true ConfigManager.can_delete? transcoder
  end

end


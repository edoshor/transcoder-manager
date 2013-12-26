class ConfigManager

  def self.can_delete?(model)
    method_name = "can_delete_#{model.class.to_s.downcase}?".to_sym
    if self.respond_to? method_name
      return self.send method_name, model
    else
      return false
    end
  end

  def self.can_delete_capture?(capture)
    Source.find(capture_id: capture.id).empty?
  end

  def self.can_delete_source?(source)
    Scheme.find(src1_id: source.id).empty? &&
    Scheme.find(src2_id: source.id).empty?
  end

  def self.can_delete_preset?(preset)
    Scheme.find(preset_id: preset.id).empty?
  end

  def self.can_delete_scheme?(scheme)
    Slot.find(scheme_id: scheme.id).empty?
  end

  def self.can_delete_event?(event)
    true
  end

  def self.can_delete_slot?(slot)
    not Event.slot_in_use? slot
  end

  def self.can_delete_transcoder?(transcoder)
    transcoder.slots.all? { |s| can_delete_slot? s }
  end

end
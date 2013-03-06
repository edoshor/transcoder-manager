require 'ohm'
require 'ohm/datatypes'

class Slot < Ohm::Model
  include Ohm::DataTypes

  attribute :slot_id, Type::Integer
  reference :transcoder, :Transcoder
  reference :scheme, :Scheme

  index :slot_id

  def validate
    assert_numeric :slot_id
    assert slot_id.between?(0,255), [:slot_id, :not_in_range]
    assert_present :transcoder
    #assert_present :scheme # we relax this for sake of synchronization
  end

  def to_hash
    super.merge(slot_id: slot_id,
        transcoder_id: transcoder.id,
        transcoder_name: transcoder.name,
        scheme_id: scheme.nil? ? nil : scheme.id,
        scheme_name: scheme.nil? ? nil : scheme.name)
  end

  def to_s
    "Slot: slot_id=#{slot_id}, transcoder_id=#{transcoder.id}, scheme_id=#{scheme.nil? ? nil : scheme.id}"
  end

end
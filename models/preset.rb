require 'ohm'

class Preset < Ohm::Model
  attribute :name

  def validate
    assert_present :name
  end

  def to_hash
    super.merge(name: name)
  end

  def to_s
    "Preset: name=#{name}"
  end
end
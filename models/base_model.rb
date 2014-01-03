require 'ohm'
require 'ohm/datatypes'

class BaseModel < Ohm::Model
  include Ohm::DataTypes

  def self.required_params(fields)
    define_singleton_method :_required_params do
      fields
    end
  end

  def self.optional_params(fields)
    define_singleton_method :_optional_params do
      fields
    end
  end

  def self.params_to_attributes(params)
    atts = HashWithIndifferentAccess.new
    get_required_params.each do |k|
      if params.key?(k)
        atts[k] = params[k]
      else
        raise ArgumentError.new("expecting #{k}")
      end
    end
    get_optional_params.each { |k| atts[k] = params[k] if params.key? k }
    yield atts if block_given?
    atts
  end

  def self.from_params(params)
    new(params_to_attributes(params))
  end

  def self.create_from_hash(atts)
    create(atts)
  end

  protected

  def self.get_required_params
    respond_to?(:_required_params) ? _required_params : []
  end

  def self.get_optional_params
    respond_to?(:_optional_params) ? _optional_params : []
  end

end

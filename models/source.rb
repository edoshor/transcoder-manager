require 'ohm'
require 'ohm/datatypes'
require 'resolv'

class Source < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  attribute :host
  attribute :port, Type::Integer

  unique :name
  index :host
  index :port

  def validate
    assert_present :name
    assert_present :host
    assert_numeric :port
    assert port.to_i.between?(0,65365), [:port, :not_in_range]
    assert_format :host, Resolv::IPv4::Regex, [:host, :not_valid_ipv4]
  end

  def to_hash
    super.merge(name: name, host: host, port: port)
  end

  def to_s
    "Source: name=#{name}, host=#{host}, port=#{port}"
  end

  def self.first_by_address(host, port)
    results = Source.find(host: host, port: port)
    (results.nil? || results.empty? ) ? nil : results.first
  end

end
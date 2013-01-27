require 'ohm'
require 'resolv'
require_relative '../app_config'

class Transcoder < Ohm::Model
  attribute :name
  attribute :host
  attribute :port
  attribute :status_port
  collection :slots, :Slot

  attr_accessor :api

  def initialize(atts)
    atts[:port] = DEFAULT_PORT if atts[:port].nil?
    atts[:status_port] = DEFAULT_STATUS_PORT if atts[:status_port].nil?
    super
  end

  def validate
    assert_present :name
    assert_present :host
    assert_numeric :port
    assert port.to_i.between?(0,65365), [:port, :not_in_range]
    assert_numeric :status_port
    assert status_port.to_i.between?(0,65365), [:status_port, :not_in_range]
    assert_format :host, Resolv::IPv4::Regex, [:host, :not_valid_ipv4]
  end

  def to_hash
    super.merge(name: name, host: host, port: port, status_port: status_port)
  end

  def to_s
    "Transcoder: atts=#{to_hash}"
  end

  def get_slot(id)
    #slots.where
  end

end
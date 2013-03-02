require 'ohm'
require 'ohm/datatypes'
require 'resolv'
require_relative '../lib/transcoder_api'
require_relative '../lib/stub_transcoder_api'
require_relative '../app_config'

class Transcoder < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  attribute :host
  attribute :port, Type::Integer
  attribute :status_port, Type::Integer
  collection :slots, :Slot
  unique :name


  # Determine which api class to use based on environment
  def self.api_class
    @api_class ||=  %w(test).include?(ENV['RACK_ENV']) ? StubTranscoderApi : TranscoderApi
  end

  def initialize(atts)
    atts[:port] = DEFAULT_PORT if atts[:port].nil?
    atts[:status_port] = DEFAULT_STATUS_PORT if atts[:status_port].nil?
    super
  end

  def validate
    assert_present :name
    assert_present :host
    assert_numeric :port
    assert port.between?(0,65365), [:port, :not_in_range]
    assert_numeric :status_port
    assert status_port.between?(0,65365), [:status_port, :not_in_range]
    assert_format :host, Resolv::IPv4::Regex, [:host, :not_valid_ipv4]
  end

  def to_hash
    super.merge(name: name, host: host, port: port, status_port: status_port)
  end

  def to_s
    "Transcoder: atts=#{to_hash}"
  end

  def api
    @api ||= self.class.api_class.new(host: host, port: port)
  end

  def api= (api)
    @api = api
  end

  def is_alive?
    api.is_alive?
  end

  def slot_taken?(slot_id)
    not slots[slot_id].nil?
  end

  def create_slot(slot)
    tracks = slot.scheme.preset.tracks.map { |t| t.to_a}
    raise_if_error api.mod_create_slot(slot.slot_id, 1, tracks.size, tracks)
  end

  def delete_slot(slot)
    raise_if_error api.mod_remove_slot(slot.slot_id)
  end

  def get_slot(slot)
    resp = raise_if_error api.mod_get_slot(slot.slot_id)
    resp[:result]
  end

  def get_slot_status(slot)
    raise_if_error api.mod_slot_get_status(slot.slot_id)
  end

  def start_slot(slot)
    ip1, port1, ip2, port2, tracks_cnt, tracks = slot.scheme.to_start_args
    result = api.mod_slot_restart(slot.slot_id, ip1, port1, ip2, port2, tracks_cnt, tracks)
    raise_if_error result
  end

  def stop_slot(slot)
    raise_if_error api.mod_slot_stop(slot.slot_id)
  end

  def save_config
    raise_if_error api.mod_save_config
  end

  def restart
    raise_if_error api.mod_restart
  end

  def get_net_config
    raise_if_error api.mod_get_net_config
  end

  def set_net_config
    raise 'not implemented'
  end

  private

  # Raise an error if api returned error
  def raise_if_error(resp)
    raise TranscoderError, "Error code: #{resp[:error]}. Message: #{resp[:message]}" \
    if resp[:error] != TranscoderApi::RET_OK
    resp
  end

end
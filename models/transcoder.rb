require 'ohm'
require 'ohm/datatypes'
require 'resolv'
require 'log4r'
require 'net/http'
require 'uri'
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

  def logger
    @logger ||= Log4r::Logger['events'] or Log4r::Logger.root
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

  def load_status
    uri = URI.parse("http://#{host}:#{status_port}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    raise TranscoderError, "Load Status Error: #{response.code}, #{response.message}" unless response.code == '200'
    body = JSON.parse response.body
    { cpu: body['cpu-load'].to_f, temp: body['temp'].to_f }
  end

  def sync
    logger.info "Synchronizing transcoder: #{name} @ #{host}"

    # check transcoder is alive
    unless is_alive?
      logger.warn 'transcoder is not responding'
      return
    end

    # compare slots count
    resp = api.mod_get_slots
    if api_error? resp
      logger.error 'api error while getting slots'
      logger.error resp
      return
    end

    actual_slot_cnt = resp[:result][:slots_cnt]
    if  actual_slot_cnt == slots.size
      logger.info "slots count match. #{actual_slot_cnt} total slots"
    else
      logger.warn "slots count mismatch. #{actual_slot_cnt} actual slots, #{slots.size} in configuration."
    end
    actual_slots_ids = resp[:result][:slots_ids]

    # remove stale slots configuration
    slots.each do |s|
      unless actual_slots_ids.include? s.slot_id
        logger.info "removing slot_id #{s.slot_id} from config. It's not present on transcoder"
        s.delete
      end
    end

    # synchronize actual slots
    actual_slots_ids.each do |s_id|
      logger.info "synchronizing slot id #{s_id}"

      # lookup slot by slot_id
      slot = slots.find(slot_id: s_id).first

      # create the slot if necessary
      if slot.nil?
        logger.info "slot #{s_id} not in configuration, creating it."
        slot = Slot.create(slot_id: s_id, transcoder: self)
      end

      # match scheme if running
      resp = api.mod_slot_get_status(s_id)
      if api_error? resp
        logger.error 'api error while getting slot status'
        logger.error resp
        next
      end

      if resp[:message].include? 'stopped'
        logger.info 'slot is not running, can not match scheme.'
      else
        get_slot = api.mod_get_slot(s_id)
        if api_error? get_slot
          logger.error 'api error while getting slot'
          logger.error get_slot
          next
        end

        scheme = Scheme.match get_slot[:result], resp[:result]
        if scheme.nil?
          logger.info 'Could not match scheme'
          logger.debug "get_slot returned: #{get_slot}"
          logger.debug "status returned: #{resp[:result]}"
        else
          logger.info "matched scheme is #{scheme.name}"
          slot.update(scheme: scheme)
        end
      end

    end

    logger.info 'synchronization completed successfully'
  end

  private

  # Raise an error if api returned error
  def raise_if_error(resp)
    raise TranscoderError, "Error code: #{resp[:error]}. Message: #{resp[:message]}" \
    if api_error? resp
    resp
  end

  def api_error? (resp)
    resp.nil? || resp[:error] != TranscoderApi::RET_OK
  end

end
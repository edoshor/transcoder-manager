require 'ohm'
require 'ohm/datatypes'
require 'resolv'
require 'log4r'
require 'net/http'
require 'uri'
require_relative '../lib/transcoder_api'
require_relative '../lib/stub_transcoder_api'
require_relative '../app_config'
require_relative 'monitor/monitor_service'

class Transcoder < Ohm::Model
  include Ohm::DataTypes

  class TranscoderError < StandardError; end

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
    assert port.between?(0, 65365), [:port, :not_in_range]
    assert_numeric :status_port
    assert status_port.between?(0, 65365), [:status_port, :not_in_range]
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
    @logger ||= Log4r::Logger['main']
  end

  def is_alive?
    api.is_alive?
  end

  def slot_taken?(slot_id)
    !slots[slot_id].nil?
  end

  def create_slot(slot)
    tracks = slot.scheme.preset.tracks.map { |t| t.to_a }
    resp = raise_if_error api.mod_create_slot(slot.slot_id, 1, tracks.size, tracks)
    log_event "slot #{slot.slot_id} created"
    resp
  end

  def delete_slot(slot)
    resp = raise_if_error api.mod_remove_slot(slot.slot_id)
    log_event "slot #{slot.slot_id} removed"
    resp
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
    resp = raise_if_error api.mod_slot_restart(slot.slot_id, ip1, port1, ip2, port2, tracks_cnt, tracks)
    log_event "slot #{slot.slot_id} started"
    resp
  end

  def stop_slot(slot)
    resp = raise_if_error api.mod_slot_stop(slot.slot_id)
    log_event "slot #{slot.slot_id} stopped"
    resp
  end

  def save_config
    raise_if_error api.mod_save_config
  end

  def restart
    resp = raise_if_error api.mod_restart
    log_event 'restart'
    resp
  end

  def get_net_config
    raise_if_error api.mod_get_net_config
  end

  def set_net_config
    raise 'not implemented'
  end

  def load_status
    # call transcoder (retry connection max 3 times)
    counter = 0
    resp = nil
    while (counter < 3) && (resp.nil? || !resp.is_a?(Net::HTTPSuccess)) do
      begin
        resp = Net::HTTP.get_response(host, '/', status_port)
        unless resp.is_a?(Net::HTTPSuccess)
          counter += 1
          logger.debug "txcoder #{id} load status failed #{counter} times: #{ resp }"
        end
      rescue EOFError => ex
        counter += 1
        logger.debug "txcoder #{id} load status failed #{counter} times: EOFError #{ ex }"
      end
    end

    # handle server response
    if resp.is_a?(Net::HTTPSuccess)
      body = JSON.parse resp.body
      cpuload = body['cpuload'].gsub(/\s|%/, '').to_f
      cputemp = {}
      body['cputemp'].each do |core_temp|
        core_temp.each_pair { |k, v| cputemp[k] = v.gsub(/\s|C/, '').to_f }
      end
      { cpu: cpuload, temp: cputemp }
    else
      msg = resp.nil?  ? 'Max number of errors occurred' : "Load Status Error: #{resp.code}, #{resp.message}"
      raise TranscoderError, msg
    end
  end

  def sync
    logger.info "Synchronizing transcoder: #{name} @ #{host}"

    # check transcoder is alive
    unless is_alive?
      logger.warn 'transcoder is not responding'
      return
    end

    # get slots
    resp = api.mod_get_slots
    if api_error? resp
      logger.error 'api error while getting slots'
      logger.error resp
      return
    end

    # compare slots count
    actual_slot_cnt = resp[:result][:slots_cnt]
    if  actual_slot_cnt == slots.size
      logger.info "slots count match. #{actual_slot_cnt} total slots"
    else
      logger.warn "slots count mismatch. #{actual_slot_cnt} actual slots, #{slots.size} in configuration."
    end
    actual_slots_ids = resp[:result][:slots_ids]
    actual_slots_ids ||= []

    # remove stale slots from configuration
    slots.each do |s|
      unless actual_slots_ids.include? s.slot_id
        logger.info "removing slot_id #{s.slot_id} from config. It's not present on transcoder"
        s.delete
      end
    end

    # synchronize actual slots
    errors = []
    actual_slots_ids.each do |s_id|
      logger.info "synchronizing slot id #{s_id}"

      begin
        # lookup slot in configuration
        slot = slots.find(slot_id: s_id).first

        # create the slot if necessary
        if slot.nil?
          logger.info "slot #{s_id} not in configuration, creating it."
          slot = Slot.create(slot_id: s_id, transcoder: self)
        end

        # get slot definition (preset)
        slot_def = api.mod_get_slot(s_id)
        if api_error? slot_def
          logger.error 'api error while getting slot'
          logger.error slot_def
          next
        end

        # match or create preset
        actual_preset = Preset.match_or_create slot_def[:result][:tracks]

        # get slot status (sources and audio mappings - if running)
        status = api.mod_slot_get_status(s_id)
        if api_error? status
          logger.error 'api error while getting slot status'
          logger.error status
          next
        end

        # match or create scheme if slot is running
        if status[:message].include? 'stopped'
          logger.info 'slot is stopped, can not match scheme.'
          logger.info "preset match configuration ? #{actual_preset.eql?(slot.scheme.preset)}" unless slot.scheme.nil?
        else
          scheme = Scheme.match_or_create slot_def[:result], status[:result]
          logger.info "matched scheme is #{scheme.name}"
          slot.update(scheme: scheme)
        end
      rescue => ex
        errors << ex
        logger.error 'unexpected error while synchronizing slot'
        logger.error ex
        logger.error ex.backtrace.join("\n")
      end
    end

    logger.info 'synchronization finished'
    log_event 'configuration synchronized'
    errors
  end

  private

  # Raise an error if api returned error
  def raise_if_error(resp)
    raise TranscoderError, "Error code: #{resp[:error]}. Message: #{resp[:message]}" \
    if api_error? resp
    resp
  end

  def log_event(event)
    MonitorService.instance.log_event id, event
    logger.info "Transcoder #{id} event: #{event}"
  end

  def api_error? (resp)
    resp.nil? || resp[:error] != TranscoderApi::RET_OK
  end

end
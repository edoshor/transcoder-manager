require 'resolv'
require 'log4r'
require_relative '../lib/transcoder_api'
require_relative '../lib/stub_transcoder_api'
require_relative '../app_config'
require_relative 'monitor/monitor_service'

class Transcoder < BaseModel

  class TranscoderError < StandardError; end

  attribute :name
  attribute :host
  attribute :port, Type::Integer
  attribute :status_port, Type::Integer
  collection :slots, :Slot
  unique :name

  required_params %w(name host)
  optional_params %w(port status_port)

  # Determine which api class to use based on environment
  def self.api_class
    @api_class ||=  %w(test).include?(ENV['RACK_ENV']) ? StubTranscoderApi : TranscoderApi
  end

  def initialize(atts)
    atts[:port] = DEFAULT_PORT unless atts[:port]
    atts[:status_port] = DEFAULT_STATUS_PORT unless atts[:status_port]
    super
  end

  def validate
    assert_present :name
    assert_present :host
    assert_numeric :port
    assert port.between?(1, 65365), [:port, :not_in_range]
    assert_numeric :status_port
    assert status_port.between?(1, 65365), [:status_port, :not_in_range]
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
    !slots.find(slot_id: slot_id).empty?
  end

  def create_slot(slot)
    tracks = slot.scheme.preset.tracks.map { |t| t.to_a }
    call_api :mod_create_slot, slot.slot_id, 1, tracks.size, tracks
  end

  def delete_slot(slot)
    call_api :mod_remove_slot, slot.slot_id
  end

  def get_slot(slot)
    call_api(:mod_get_slot, slot.slot_id) { |resp| resp[:result] }
  end

  def get_slot_status(slot)
    call_api :mod_slot_get_status, slot.slot_id
  end

  def start_slot(slot)
    call_api :mod_slot_restart, slot.slot_id, *slot.scheme.to_start_args
  end

  def stop_slot(slot)
    call_api :mod_slot_stop, slot.slot_id
  end

  def save_config
    call_api :mod_save_config
  end

  def restart
    call_api :mod_restart
  end

  def get_net_config
    call_api :mod_get_net_config
  end

  def set_net_config
    raise 'not implemented'
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
    log_event :sync
    errors
  end

  private

  def call_api(method, *args)
    resp = api.send(method, *args)
    if api_success? resp
      log_event(method, *args)
      block_given? ? yield(resp) : resp
    else
      raise TranscoderError, "Error code: #{resp[:error]}. Message: #{resp[:message]}"
    end
  end

  def api_success? (resp)
    resp and resp[:error] == TranscoderApi::RET_OK
  end

  def api_error? (resp)
    not api_success? resp
  end

  def log_event(method, *args)
    msg = event_message(method, *args)
    if msg
      MonitorService.instance.log_event id, msg
      logger.info "Transcoder #{id} event: #{msg}"
    end
  end

  def event_message(api_method, *args)
    case api_method
      when :create_slot then "slot #{args[0]} created"
      when :delete_slot then "slot #{args[0]} removed"
      when :start_slot then "started slot #{args[0]}"
      when :stop_slot then "stopped slot #{args[0]}"
      when :restart then 'restart'
      when :sync then 'configuration synchronized'
      else nil
    end
  end

end
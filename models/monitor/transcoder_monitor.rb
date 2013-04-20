require 'celluloid'
require_relative 'monitor_service'
require_relative '../transcoder'

class TranscoderMonitor
  include Celluloid
  include Celluloid::Logger

  ALIVE_INTERVAL = 3
  LOAD_INTERVAL = 5
  MIN_STATE_CHANGE = 2

  attr_reader :tx_id, :state, :timer

  def initialize(tx_id)
    @tx_id = tx_id
    @state = nil
    @change_count = MIN_STATE_CHANGE

    @timer = every(ALIVE_INTERVAL) { check_is_alive }
    @load_timer = every(LOAD_INTERVAL) { sample_load_status }
  end

  def check_is_alive
    is_alive = Transcoder[@tx_id].is_alive?

    # return immediately if no change in state
    return if @state == is_alive


    if @state.nil? # just started monitoring ?
      @state = is_alive
      MonitorService.instance.wakeup_state @tx_id, @state
    else
      @change_count -= 1
      if @change_count == 0 # did we reach stability barrier ?
        @state = is_alive
        @change_count = MIN_STATE_CHANGE
        MonitorService.instance.state_changed @tx_id, @state
      end
    end

  end

  def sample_load_status
    # avoid sample if we know transcoder is dead.
    return unless @state

    begin
      load_status = Transcoder[@tx_id].load_status
      MonitorService.instance.load_status @tx_id, load_status
    rescue => ex
      warn format_exception ex
    end
  end

end
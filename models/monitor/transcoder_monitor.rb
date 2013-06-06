require 'celluloid'
require 'net/http'
require_relative 'monitor_service'
require_relative '../transcoder'

class TranscoderMonitor
  include Celluloid
  include Celluloid::Logger

  ALIVE_INTERVAL = 3
  LOAD_INTERVAL = 5
  MIN_STATE_CHANGE = 2

  attr_reader :tx_id, :timer, :load_timer
  attr_accessor :state

  def initialize(tx_id)
    @tx_id = tx_id
    @state = nil
    @change_count = MIN_STATE_CHANGE

    @timer = every(ALIVE_INTERVAL) { check_is_alive }
    @load_timer = every(LOAD_INTERVAL) { sample_load_status }
  end

  def check_is_alive
    is_alive = Transcoder[@tx_id].is_alive?
    return if @state == is_alive # no change

    if @state.nil? # first time monitoring ?
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
    return unless @state

    begin
      resp = get_load_status
      if resp.is_a? Net::HTTPSuccess
        MonitorService.instance.load_status @tx_id, parse_response(resp)
      else
        warn resp ? "Load Status Error: #{resp.code}, #{resp.message}" : 'Max number of errors occurred'
      end
    rescue => ex
      warn format_exception ex
    end
  end

  def get_load_status(trials = 3)
    resp = nil
    txcoder = Transcoder[@tx_id]
    until resp.is_a?(Net::HTTPSuccess) or trials == 0 do
      begin
        resp = Net::HTTP.get_response(txcoder.host, '/', txcoder.status_port)
        unless resp.is_a? Net::HTTPSuccess
          trials -= 1 and debug "txcoder #{@tx_id} load status failed: #{resp}"
        end
      rescue EOFError => ex
        trials -= 1 and debug "txcoder #{@tx_id} load status EOFError: #{ex}"
      end
    end
    resp
  end

  def parse_response(resp)
    body = JSON.parse resp.body
    {cpu:  body['cpuload'].gsub(/\s|%/, '').to_f,
     temp: body['cputemp'].inject({}) do |h, core_temp|
        h.merge! Hash[core_temp.map { |k,v| [k, v.gsub(/\s|C/, '').to_f] }]
     end
    }
  end

end
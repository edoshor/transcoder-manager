require 'ohm'
require 'singleton'
require 'log4r'
require 'mail'
require_relative 'monitor_group'
require_relative 'history_cleaner'
require_relative '../transcoder'

class MonitorService
  include Singleton

  # Start monitoring transcoders
  def start
    return if @started

    Celluloid.logger = logger
    logger.debug 'Start monitoring transcoders'

    @monitor_group = MonitorGroup.run!
    Transcoder.all.each {|t| @monitor_group.add_txcoder t.id }
    @monitor_group.supervise_as 'history_cleaner', HistoryCleaner
    @started = true
  end

  # Stop monitoring transcoders and shutdown
  def shutdown
    logger.debug 'Shutting down monitor service'
    @monitor_group.finalize if @started
    @started = false
  end

  # Monitor a new transcoder
  def add_txcoder(tx_id)
    @started and @monitor_group.add_txcoder tx_id
  end

  # Stop monitoring transcoder and remove all its history.
  def remove_txcoder(tx_id)
    @started or return
    @monitor_group.remove_txcoder tx_id
    remove_history tx_id
  end

  # Transcoder state is changed
  def state_changed(tx_id, state)
    record_state(tx_id, state)
    notify_state_change(state, tx_id)
  end

  # First time we know the transcoder state
  def wakeup_state(tx_id, state)
    last_state = get_metric_reverse(tx_id, 'state', :all, [0,1]).first
    if last_state
      unless last_state =~ /#{state}/
        logger.debug "transcoder #{tx_id} changed state on downtime. Now he is #{ state_to_h state } ."
        state_changed tx_id, state
      end
    else
      record_state(tx_id, state)
    end
  end

  # handle transcoder load status sample
  def load_status(tx_id, status)
    ts = Time.now.to_i
    redis.zadd prefix_key(tx_id, 'cpu'), ts, "[#{ts},#{status[:cpu]}]"
    status[:temp].each_pair { |k, v| redis.zadd prefix_key(tx_id, "temp_#{k}"), ts, "[#{ts},#{v}]" }
  end

  # log transcoder event
  def log_event(tx_id, event)
    ts = Time.now.to_i
    redis.zadd prefix_key(tx_id, 'events'), ts, "[#{ts},#{event}]"
  end

  # get metric data in the given period
  def get_metric(tx_id, metric, period, limit = nil)
    min, max = period_to_range period
    get_history tx_id, metric: metric, min: min, max: max, limit: limit
  end

  # get metric data in reverse order
  def get_metric_reverse(tx_id, metric, period, limit = nil)
    min, max = period_to_range period
    get_history tx_id, metric: metric, min: min, max: max, limit: limit, reverse: true
  end

  # remove all transcoder monitoring history
  def remove_history(tx_id)
    keys = %w(cpu state events).map { |metric| prefix_key tx_id, metric }
    keys.concat (0..7).collect { |core| prefix_key(tx_id, "temp_#{core}") }
    redis.del keys
  end

  # clean historic monitoring data
  def clean_history_period(period = 'week')
    min,max = period_to_range period
    Transcoder.all.each do |t|
      %w(cpu state events).each { |metric| redis.zremrangebyscore prefix_key(t.id, metric), 0, min }
      (0..7).each do |core|
        key = prefix_key(t.id, "temp_#{core}")
        redis.zremrangebyscore(key, 0, min) if redis.exists(key)
      end
    end
  end

  private

  def record_state(tx_id, state)
    ts = Time.now.to_i
    redis.zadd prefix_key(tx_id, 'state'), ts, "[#{ts},#{state}]"
    logger.debug "transcoder #{tx_id} state is #{state_to_h state}"
  end

  def notify_state_change(state, tx_id)
    human_state = state_to_h state
    subject = "#{ human_state } Alert: #{Transcoder[tx_id].name}"
    begin
      Mail.deliver do
        from 'noreply.shidur@kbb1.com'
        to 'shidur@kbb1.com'
        subject subject
        body "Transcoder state changed. Now he is #{ human_state }"
      end
    rescue => ex
      logger.warn "Error sending state change mail: #{ex}"
    end
  end

  def get_history(tx_id, options = {})
    min = options.delete(:min) { 0 }
    max = options.delete(:max) { '+inf' }
    command = :zrangebyscore
    if options.delete(:reverse)
      min, max = max, min
      command = :zrevrangebyscore
    end
    metric = options.delete(:metric)
    case metric
      when 'cpu', 'state', 'events'
        redis.send command, *[prefix_key(tx_id, metric), min, max, options]
      when 'temp'
        (0..7).map do |core|
          key = prefix_key(tx_id, "temp_#{core}")
          redis.send command, *[key, min, max, options] if redis.exists(key)
        end
        .select! { |x| x }
      else
        raise "unknown metric #{metric}"
    end
  end

  def period_to_range(period)
    if :all == period
      [0, '+inf']
    else
      max = Time.now.to_i
      [max - period_in_s(period), max]
    end
  end

  TEN_MINUTES_IN_S = 10 * 60
  HOUR_IN_S = 6 * TEN_MINUTES_IN_S
  DAY_IN_S = 24 * HOUR_IN_S
  WEEK_IN_S = 7 * DAY_IN_S

  def period_in_s(period)
    case period
    when 'week'
      WEEK_IN_S
    when 'day'
      DAY_IN_S
    when 'hour'
      HOUR_IN_S
    when '10_minutes'
      TEN_MINUTES_IN_S
    else
      raise "unknown period #{period}"
    end
  end

  def tx_namespace(tx_id)
    "monitor:tx:#{tx_id}"
  end

  def prefix_key(tx_id, key)
    "#{tx_namespace(tx_id)}:#{key}"
  end

  def logger
    @logger ||= Log4r::Logger['main']
  end

  def redis
    @redis ||= Ohm.redis
  end

  def state_to_h(state)
    state ? 'UP' : 'DOWN'
  end

end

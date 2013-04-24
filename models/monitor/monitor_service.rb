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

    logger.debug 'Start monitoring transcoders'
    Celluloid.logger = logger
    @monitor_group = MonitorGroup.run!

    Transcoder.all.each do |t|
      @monitor_group.add_txcoder t.id
    end

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
    @monitor_group.add_txcoder tx_id if @started
  end

  # Stop monitoring transcoder and remove all its history.
  def remove_txcoder(tx_id)
    # stop actor
    @monitor_group.remove_txcoder tx_id

    # remove all monitoring data from redis
    keys = [prefix_key(tx_id, 'state'), prefix_key(tx_id, 'cpu')]
    (0..7).to_a.each { |core| keys << prefix_key(tx_id, "temp_#{core}") }
    redis.del prefix_key(tx_id, 'state')
  end

  # Transcoder state is changed
  def state_changed(tx_id, state)
    record_state(tx_id, state)

    subject = "#{ state ? 'UP' : 'DOWN' } Alert: #{Transcoder[tx_id].name}"
    Mail.deliver do
      from    'noreply.shidur@kbb1.com'
      to      'shidur@kbb1.com'
      subject subject
      body    'transcoder state changed'
    end
  end

  # First time we know the transcoder state
  def wakeup_state(tx_id, state)
    # get last known state
    last_state_key = redis.lindex prefix_key(tx_id, 'states'), 0
    last_state = last_state_key.nil? ? nil : redis.hmget(last_state_key, 'state')

    # first time monitoring this transcoder EVER ?
    if last_state.nil?
      record_state(tx_id, state)
    else
      if last_state == state
        logger.debug "just woke up and transcoder #{tx_id} state didn't change. He is #{state ? 'alive' : 'dead'} ."
      else
        logger.debug "just woke up and transcoder #{tx_id} changed state ! He is #{state ? 'alive' : 'dead'} ."
        state_changed tx_id, state
      end
    end
  end

  # handle transcoder load status sample
  def load_status(tx_id, status)
    ts = Time.now.to_i
    redis.zadd prefix_key(tx_id, 'cpu'), ts, "[#{ts},#{status[:cpu]}]"
    status[:temp].each_pair do |k, v|
      redis.zadd prefix_key(tx_id, "temp_#{k}"), ts, "[#{ts},#{v}]"
    end
  end

  # log transcoder event
  def log_event(tx_id, event)
    ts = Time.now.to_i
    redis.zadd prefix_key(tx_id, 'events'), ts, "[#{ts},#{event}]"
  end

  # clean historic monitoring data
  def clean_history
    max = Time.now.to_i - period_in_s('week')
    Transcoder.all.each do |t|
      %w(cpu state events).each do |metric|
        redis.zremrangebyscore prefix_key(t.id, metric), 0, max
      end
      (0..7).to_a.map do |core|
        key = prefix_key(t.id, "temp_#{core}")
        redis.zremrangebyscore(key, 0, max) if redis.exists(key)
      end
    end
  end

  # get metric data in the given period
  def get_metric(tx_id, metric, period)
    max = Time.now.to_i
    min = max - period_in_s(period)

    case metric
    when 'cpu', 'state', 'events'
      redis.zrangebyscore prefix_key(tx_id, metric), min, max
    when 'temp'
      (0..7).to_a.map do |core|
        key = prefix_key(tx_id, "temp_#{core}")
        redis.zrangebyscore(key, min, max) if redis.exists(key)
      end
      .delete_if { |x| x.nil? }
    else
      raise "unknown metric #{metric}"
    end

  end

  private

  def record_state(tx_id, state)
    ts = Time.now.to_i
    redis.zadd prefix_key(tx_id, 'state'), ts, "[#{ts},#{state}]"
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

end

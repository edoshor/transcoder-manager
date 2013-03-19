require 'ohm'
require 'singleton'
require 'log4r'
require_relative 'monitor_group'

class MonitorService
  include Singleton

  # Start monitoring transcoders
  def start
    logger.debug 'Start monitoring transcoders'
    Celluloid.logger = logger
    @monitor_group = MonitorGroup.run!
  end

  def add_txcoder(tx_id)
    @monitor_group.add_txcoder tx_id
  end

  def remove_txcoder(tx_id)
    @monitor_group.remove_txcoder tx_id
    logger.info "Removing all monitoring history for transcoder #{tx_id}"
    keys = redis.keys "#{tx_namespace(tx_id)}*"
    redis.del keys unless keys.nil? || keys.empty?
  end

  def state_changed(tx_id, state)
    logger.debug "transcoder #{tx_id} state is changed and is now #{state ? 'alive' : 'dead'} !"
    timestamp = Time.now.to_i
    key = prefix_key tx_id, "state:#{timestamp}"
    redis.hmset key, 'timestamp', timestamp.to_s, 'state', state.to_s
    redis.lpush prefix_key(tx_id, 'states'), key
  end

  def load_status(tx_id, status)
    logger.debug "transcoder #{tx_id} load status is #{status}"
    timestamp = Time.now.to_i
  end

  def get_alive(tx_id)
    results = redis.sort prefix_key(tx_id, 'states'), by: 'NOSORT', get: %w(*->timestamp *->state)
    results
  end

  private

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
require 'celluloid'
require 'celluloid/logger'
require_relative 'transcoder_monitor'

class MonitorGroup < Celluloid::SupervisionGroup

  # Start monitoring transcoder
  def add_txcoder(tx_id)
    Celluloid::Logger.info "start monitoring transcoder #{tx_id}"
    name = monitor_name tx_id
    supervise_as(name, TranscoderMonitor, tx_id) unless Celluloid::Actor[name]
  end

  # Stop monitoring transcoder
  def remove_txcoder(tx_id)
    Celluloid::Logger.info "stop monitoring transcoder #{tx_id}"
    monitor = Celluloid::Actor[monitor_name(tx_id)]
    monitor.terminate if monitor
  end

  private

  def monitor_name(tx_id)
    "t#{tx_id}_monitor".to_sym
  end

end
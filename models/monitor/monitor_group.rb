require 'celluloid'
require 'celluloid/logger'
require_relative 'transcoder_monitor'
require_relative '../transcoder'

class MonitorGroup < Celluloid::SupervisionGroup

  def self.monitor_name(id)
    "t#{id}_monitor".to_sym
  end

  # start monitoring all transcoders on startup
  Transcoder.all.each do |t|
    supervise TranscoderMonitor, as: monitor_name(t.id), args: [t.id]
  end

  # Start monitoring transcoder
  def add_txcoder(tx_id)
    Celluloid::Logger.info "start monitoring transcoder #{tx_id}"
    name = MonitorGroup.monitor_name tx_id
    if Celluloid::Actor[name].nil?
      supervise_as name, TranscoderMonitor, tx_id
    end
  end

  # Stop monitoring transcoder
  def remove_txcoder(tx_id)
    Celluloid::Logger.info "stop monitoring transcoder #{tx_id}"
    m = Celluloid::Actor[MonitorGroup.monitor_name(tx_id)]
    m.terminate unless m.nil?
  end

end
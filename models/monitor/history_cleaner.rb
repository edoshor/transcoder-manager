require 'celluloid'
require_relative 'monitor_service'

class HistoryCleaner
  include Celluloid

  CLEAN_INTERVAL = 60 * 30 # 30 MINUTES

  attr_reader :timer

  def initialize
    @timer = every(CLEAN_INTERVAL) { MonitorService.instance.clean_history_period }
  end

end
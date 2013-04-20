require 'celluloid'
require_relative 'monitor_service'

class HistoryCleaner
  include Celluloid

  CLEAN_INTERVAL = 60 * 30 # 30 MINUTES

  def initialize
    @timer = every(CLEAN_INTERVAL) { MonitorService.instance.clean_history }
  end

end
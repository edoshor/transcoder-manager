# Simple wrapper of log4r for Rack::CommonLogger
#
# @author Edo.Shor
class LogWrapper

  def initialize(logger_name, level= 'info')
    @logger_name = logger_name
    @level = level
  end

  def write(message)
    Log4r::Logger[@logger_name].send(@level, message.chomp)
  end

end
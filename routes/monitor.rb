require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  before do
    content_type :json
  end

  get '/monitor/start' do
    MonitorService.instance.start and 'success'
  end

  get '/monitor/shutdown' do
    MonitorService.instance.shutdown and 'success'
  end

  get '/monitor/:tx_id/:metric' do
    metric = params[:metric]
    raise ApiError, "Unknown metric: #{metric}" unless %w(cpu temp state events).include? metric

    period = params[:period]
    period = 'hour' if period.nil? # default period
    raise ApiError, "Unknown period: #{period}" unless %w(week day hour 10_minutes).include? period

    result = MonitorService.instance.get_metric params[:tx_id], metric, period

    if metric == 'temp'
      "[#{result.map { |core| "[#{ core.join(',') }]" }.join(',')}]"
    else
      "[#{result.join(',')}]"
    end
  end


end

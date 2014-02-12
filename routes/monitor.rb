require 'mail'
require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  get '/monitor/status' do
    {status: MonitorService.instance.started}.to_json
  end

  get '/monitor/start' do
    MonitorService.instance.start and success
  end

  get '/monitor/shutdown' do
    MonitorService.instance.shutdown and success
  end

  get '/monitor/:tx_id/:metric' do
    metric = params[:metric]
    halt 404 unless %w(cpu temp state events).include? metric
    period = params[:period] || 'hour'
    halt 404 unless %w(all week day hour 10_minutes).include? period

    reverse = params[:reverse]
    if reverse
      result = MonitorService.instance.get_metric_reverse params[:tx_id], metric, period
    else
      result = MonitorService.instance.get_metric params[:tx_id], metric, period
    end

    if metric == 'temp'
      "[#{result.map { |core| "[#{ core.join(',') }]" }.join(',')}]"
    else
      "[#{result.join(',')}]"
    end
  end

  get '/monitor/test-email' do
    to = params[:to]
    Mail.deliver do
      from    'noreply.shidur@kbb1.com'
      to      to
      subject 'test email'
      body    'test 1 2 3'
    end
  end

end

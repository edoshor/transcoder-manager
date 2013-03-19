require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  before do
    content_type :json
  end

  get '/monitor/:id/alive' do
    result = MonitorService.instance.get_alive @params[:id]
    f = result.map { |res| [Time.at(res[0].to_i), 'true' == res[1]] }
    f.to_json
  end


end

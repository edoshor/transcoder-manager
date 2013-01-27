class TranscoderManager < Sinatra::Base

  get '/admin' do
    haml :default
  end

end

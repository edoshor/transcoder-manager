require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  before do
    content_type :json
  end

  get '/test-redis' do
    counter = Ohm.redis.incr "test"
    counter.to_json
  end

  # --- Transcoders ---

  get '/transcoders' do
    Transcoder.all.map{ |transcoder| transcoder.to_hash }.to_json
  end

  post '/transcoders' do
    save_model Transcoder.new(params.select{|k,v| %w(name host port status_port).include? k})
  end

  get '/transcoders/:id' do
    transcoder = Transcoder[params[:id]]
    raise APIError, "Unknown transcoder with id #{params[:id]}" if transcoder == nil
    transcoder.to_hash.to_json
  end

  put '/transcoders/:id' do
    transcoder = Transcoder[params[:id]]
    raise APIError, "Unknown transcoder with id #{params[:id]}" if transcoder == nil
    update_model transcoder, params.select{|k,v| %w(name host port status_port).include? k}
  end

  delete '/transcoders/:id' do
    transcoder = Transcoder[params[:id]]
    raise APIError, "Unknown transcoder with id #{params[:id]}" if transcoder == nil
    transcoder.delete
    success
  end

  get '/transcoders/:id/slots' do
    transcoder = Transcoder[params[:id]]
    raise APIError, "Unknown transcoder with id #{params[:id]}" if transcoder == nil
    transcoder.slots.map { |slot| slot.to_hash}.to_json
  end

  post '/transcoders/:id/slots' do
    transcoder = Transcoder[params[:id]]
    raise APIError, "Unknown transcoder with id #{params[:id]}" if transcoder == nil

    slot = Slot.new(slot_id: params[:slot_id], transcoder: transcoder)
    save_model slot
  end

  get '/transcoders/:id/slots/:id' do |tid, sid|
    transcoder = Transcoder[tid]
    raise APIError, "Unknown transcoder with id #{tid}" if transcoder == nil
    slot = transcoder.slots[sid]
    raise APIError, "Unknown slot with slot_id #{sid}" if slot == nil

    slot.to_hash.to_json
  end

  delete '/transcoders/:id/slots/:id' do |tid, sid|
    transcoder = Transcoder[tid]
    raise APIError, "Unknown transcoder with id #{tid}" if transcoder == nil
    slot = transcoder.slots[sid]
    raise APIError, "Unknown slot with slot_id #{sid}" if slot == nil

    slot.delete
    success
  end


  # --- Sources ---

  get '/sources' do
    Source.all.map{ |source| source.to_hash }.to_json
  end

  post '/sources' do
    save_model Source.new(params.select{|k,v| %w(name host port).include? k})
  end

  get '/sources/:id' do
    source = Source[params[:id]]
    raise APIError, "Unknown source with id #{params[:id]}" if source == nil
    source.to_hash.to_json
  end

  put '/sources/:id' do
    source = Source[params[:id]]
    raise APIError, "Unknown source with id #{params[:id]}" if source == nil
    update_model source, params.select{|k,v| %w(name host port).include? k}
  end

  delete '/sources/:id' do
    source = Source[params[:id]]
    raise APIError, "Unknown source with id #{params[:id]}" if source == nil
    source.delete
    success
  end

  # --- Presets ---

  get '/presets' do
    Preset.all.map{ |preset| preset.to_hash }.to_json
  end

  post '/presets' do
    save_model Preset.new(name: params[:name])
  end

  get '/presets/:id' do
    preset = Preset[params[:id]]
    raise APIError, "Unknown preset with id #{params[:id]}" if preset == nil
    preset.to_hash.to_json
  end

  put '/presets/:id' do
    preset = Preset[params[:id]]
    raise APIError, "Unknown preset with id #{params[:id]}" if preset == nil
    update_model preset, params.select {|k,v| k == 'name'}
  end

  delete '/presets/:id' do
    preset = Preset[params[:id]]
    raise APIError, "Unknown preset with id #{params[:id]}" if preset == nil
    preset.delete
    success
  end


  private

  def save_model(model)
    if model.valid?
      model.save
      model.to_hash.to_json
    else
      validation_error model.errors
    end
  end

  def update_model(model, atts)
    return model.to_hash.to_json if atts.empty?
    model.update(atts).nil? ? validation_error(model.errors) : model.to_hash.to_json
  end

  def success(msg = 'success')
    {result: msg}.to_json
  end

  def validation_error(errors)
    status 400
    headers 'X-Status-Reason' => 'Validation failed'
    errors.to_json
  end

end

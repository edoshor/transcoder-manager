require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  before do
    content_type :json
  end

  get '/test-redis' do
    counter = Ohm.redis.incr 'test'
    counter.to_json
  end

  # --- Transcoders ---

  get '/transcoders' do
    all_to_json Transcoder
  end

  post '/transcoders' do
    transcoder = Transcoder.new(params.select{ |k, v| %w(name host port status_port).include? k })
    raise ApiError, "Transcoder at #{transcoder.host}:#{transcoder.port} is not responding" unless transcoder.is_alive?
    save_model transcoder
  end

  delete '/transcoders' do
    delete_all Transcoder and success
  end

  get '/transcoders/:id' do
    get_model(params[:id], Transcoder).to_hash.to_json
  end

  put '/transcoders/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/transcoders/:id' do
    transcoder = Transcoder[params[:id]]
    raise ApiError, "Unknown transcoder with id #{params[:id]}" if transcoder.nil?

    #TODO don't terminate if transcoder is active !

    transcoder.delete
    success
  end

  get '/transcoders/:id/slots' do
    transcoder = Transcoder[params[:id]]
    raise ApiError, "Unknown transcoder with id #{params[:id]}" if transcoder.nil?
    transcoder.slots.map { |s| s.to_hash}.to_json
  end

  post '/transcoders/:id/slots' do
    slot_id, scheme_id = expect_params 'slot_id', 'scheme_id'
    transcoder = get_model(params[:id], Transcoder)
    scheme = get_model(scheme_id, Scheme)

    slot = Slot.new(slot_id: slot_id, transcoder: transcoder, scheme: scheme)
    if slot.valid?
      raise ApiError, 'Slot exist. Try another slot_id.' if transcoder.slot_taken?(slot.slot_id)
      transcoder.create_slot slot
    else
      validation_error slot.errors
    end

    save_model slot
  end

  delete '/transcoders/:id/slots' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.each do |s|
      transcoder.delete_slot s
      s.delete
    end
    success
  end

  get '/transcoders/:id/slots/:id' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    slot.to_hash.to_json
  end

  delete '/transcoders/:id/slots/:id' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    transcoder.delete_slot slot
    slot.delete
    success
  end

  get '/transcoders/:id/net-config' do
    get_model(tid, Transcoder).get_net_config.to_json
    #TODO return net config json
  end

  put '/transcoders/:id/net-config' do
    raise 'not implemented'
  end

  get '/transcoders/save' do
    Transcoder.all.each do |t|
      t.save_config
    end
    success
  end

  get '/transcoders/restart' do
    Transcoder.all.each do |t|
      t.restart
    end
    success
  end

  get '/transcoders/reset-defaults' do
    raise 'not implemented'
  end

  get '/transcoders/:id/save' do
    get_model(params[:id], Transcoder).save_config and success
  end

  get '/transcoders/:id/restart' do
    get_model(params[:id], Transcoder).restart and success
  end

  get '/transcoders/:id/reset-defaults' do
    raise 'not implemented'
  end

  get '/transcoders/:id/slots/start' do
    raise 'not implemented'
  end

  get '/transcoders/:id/slots/stop' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.all.each do |slot|
      transcoder.stop_slot slot
    end
    success
  end

  get '/transcoders/:id/slots/:id/start' do |tid, sid|
    raise 'not implemented'
  end

  get '/transcoders/:id/slots/stop' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    transcoder.stop_slot slot
    success
  end

  get '/transcoders/:id/slots/status' do
    transcoder = get_model(params[:id], Transcoder)
    status = transcoder.slots.all.map { |slot| transcoder.get_slot_status slot}

    #TODO return status.to_json
  end

  get '/transcoders/:id/slots/status' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    status = transcoder.get_slot_status slot

    #TODO return status.to_json
  end

  # --- Sources ---

  get '/sources' do
    all_to_json Source
  end

  post '/sources' do
    save_model Source.new(params.select{|k,v| %w(name host port).include? k})
  end

  delete '/sources' do
    delete_all Source and success
  end

  get '/sources/:id' do
    get_model(params[:id], Source).to_hash.to_json
  end

  put '/sources/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/sources/:id' do
    get_model(params[:id], Source).delete and success
  end

  # --- Presets ---

  get '/presets' do
    all_to_json Preset
  end

  post '/presets' do
    name, tracks = expect_params 'name', 'tracks'

    raise ApiError, 'Expecting tracks profiles' if tracks.nil? || tracks.empty?

    preset = Preset.new(name: name)
    if preset.valid?
      invalid_tracks = tracks.select { |track| not Track.new(track).valid? }
      if invalid_tracks.empty?
        preset.save
        tracks.each do |track|
          preset.tracks.push Track.create(track)
        end
        preset.to_hash.to_json
      else
        track = Track.new(invalid_tracks[0])
        track.valid?
        validation_error track.errors
      end
    else
      validation_error preset.errors
    end
  end

  delete '/presets' do
    delete_all Preset and success
  end

  get '/presets/:id' do
    get_model(params[:id], Preset).to_hash.to_json
  end

  put '/presets/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/presets/:id' do
    get_model(params[:id], Preset).delete and success
  end

  # --- Schemes ---

  get '/schemes' do
    all_to_json Scheme
  end

  post '/schemes' do
    name, preset_id, source1_id, audio_mappings =
        expect_params 'name', 'preset_id', 'source1_id', 'audio_mappings'

    save_model Scheme.new(
                   name: name,
                   preset: get_model(preset_id, Preset),
                   src1: get_model(source1_id, Source),
                   src2: params['source2_id'].nil? ? nil : get_model(params['source2_id'], Source),
                   audio_mappings: audio_mappings)
  end

  delete '/schemes' do
    delete_all Scheme and success
  end

  get '/schemes/:id' do
    get_model(params[:id], Scheme).to_hash.to_json
  end

  put '/schemes/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/schemes/:id' do
    get_model(params[:id], Scheme).delete and success
  end

  private

  def get_model(id, clazz)
    clazz[id] or raise ApiError, "Unknown #{clazz.name} with id #{id}"
  end

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

  def all_to_json(clazz)
    clazz.all.map{ |m| m.to_hash }.to_json
  end

  def delete_all(clazz)
    clazz.all.each do |m|
      m.delete
    end
  end

  def success(msg = 'success')
    {result: msg}.to_json
  end

  def validation_error(errors)
    status 400
    headers 'X-Status-Reason' => 'Validation failed'
    errors.to_json
  end

  def expect_params(*p_names)
    p_names.map {|p|
      raise ApiError, "expecting #{p} but didn't get any" if params[p].nil?
      params[p]
    }
  end

end

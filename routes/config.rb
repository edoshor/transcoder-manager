require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  # --- Transcoders ---

  get '/transcoders' do
    all_to_json Transcoder
  end

  post '/transcoders' do
    name, host = expect_params 'name', 'host'
    transcoder = Transcoder.new(name: name, host: host, port: params['port'], status_port: params['status_port'])

    transcoder.is_alive? or raise ApiError, "Transcoder at #{transcoder.host}:#{transcoder.port} is not responding"

    if transcoder.valid?
      transcoder.save
      MonitorService.instance.add_txcoder transcoder.id
      transcoder.to_hash.to_json
    else
      validation_error transcoder.errors
    end
  end

  get '/transcoders/:id' do
    get_model(params[:id], Transcoder).to_hash.to_json
  end

  put '/transcoders/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/transcoders/:id' do
    transcoder = get_model(params[:id], Transcoder)
    if transcoder.slots.any? { |slot| Event.slot_in_use? slot }
      config_integrity_error 'Transcoder is in use. Can not delete.'
    else
      MonitorService.instance.remove_txcoder transcoder.id
      transcoder.slots.each { |slot| slot.delete }
      transcoder.delete
      success
    end
  end

  get '/transcoders/:id/slots' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.map { |s| s.to_hash }.to_json
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

  get '/transcoders/:id/slots/:id' do |tid, sid|
    pass unless sid =~ /\d+/  # pass non numeric ids

    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot
    slot.to_hash.to_json
  end

  delete '/transcoders/:id/slots/:id' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot

    if Event.slot_in_use? slot
      config_integrity_error 'Slot is in use. Can not delete.'
    else
      transcoder.delete_slot slot
      slot.delete
      success
    end
  end

  get '/transcoders/:id/net-config' do
    get_model(params[:id], Transcoder).get_net_config.to_json
  end

  put '/transcoders/:id/net-config' do
    raise 'not implemented'
  end

  # --- Sources ---

  get '/sources' do
    all_to_json Source
  end

  post '/sources' do
    name, host, port = expect_params 'name', 'host', 'port'
    save_model Source.new(name: name, host: host, port: port)
  end

  get '/sources/:id' do
    get_model(params[:id], Source).to_hash.to_json
  end

  put '/sources/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/sources/:id' do
    source = get_model(params[:id], Source)
    if Scheme.source_in_use? source
      config_integrity_error "Source #{source.name} is in use. Can not delete."
    else
      source.delete and success
    end
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
        tracks.each { |track| preset.tracks.push Track.create(track) }
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

  get '/presets/:id' do
    get_model(params[:id], Preset).to_hash.to_json
  end

  put '/presets/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/presets/:id' do
    preset = get_model(params[:id], Preset)
    if Scheme.preset_in_use? preset
      config_integrity_error "Preset #{preset.name} is in use. Can not delete."
    else
      preset.delete and success
    end
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

  get '/schemes/:id' do
    get_model(params[:id], Scheme).to_hash.to_json
  end

  put '/schemes/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/schemes/:id' do
    scheme = get_model(params[:id], Scheme)
    if Slot.find_by_scheme(scheme).any? { |slot| Event.slot_in_use? slot }
      config_integrity_error 'Scheme is in use. Can not delete.'
    else
      scheme.delete and success
    end
  end

  # --- Events ---

  get '/events' do
    all_to_json Event
  end

  post '/events' do
    name = expect_params('name')[0]
    save_model Event.new(name: name)
  end

  get '/events/:id' do
    get_model(params[:id], Event).to_hash.to_json
  end

  put '/events/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/events/:id' do
    get_model(params[:id], Event).delete and success
  end

  get '/events/:id/slots' do
    event = get_model(params[:id], Event)
    event.slots.map { |s| s.to_hash }.to_json
  end

  post '/events/:id/slots' do
    slot_id = expect_params('slot_id')[0]
    slot = get_model(slot_id, Slot)
    event = get_model(params[:id], Event)
    event.add_slot slot
    success
  end

  delete '/events/:id/slots/:id' do |eid, sid|
    slot = get_model(sid, Slot)
    event = get_model(eid, Event)
    event.remove_slot slot
    success
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
    model.update(atts) ? model.to_hash.to_json : validation_error(model.errors)
  end

  def all_to_json(clazz)
    clazz.all.map { |m| m.to_hash }.to_json
  end

  def validation_error(errors)
    custom_error 'Validation', 'Validation failed', errors
  end

  def config_integrity_error(msg)
    custom_error 'Configuration', 'Configuration constraint failed', msg
  end

  def custom_error(type, reason, error)
  request.body.rewind  # in case someone already read it
  logger.info "#{type} error: #{error}"
  logger.debug "request.body= #{request.body.read}"

  status 400
  headers 'X-Status-Reason' => reason
  error.is_a?(String) ? {error: error}.to_json : error.to_json
end

end
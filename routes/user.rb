require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  before do
    content_type :json
    headers \
     'Access-Control-Allow-Origin' => '*',
     'Access-Control-Allow-Methods' => 'POST, GET, OPTIONS',
     'Access-Control-Allow-Headers' => 'Content-Type'
  end

  get '/test-redis' do
    if 'PONG' == Ohm.redis.ping
      "redis is alive at #{Ohm.conn.options[:url]}"
    else
      'redis is dead.'
    end
  end

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

  delete '/transcoders' do
    Transcoder.all.each do |t|
      MonitorService.instance.remove_txcoder t.id
      t.delete
    end
    success
  end

  get '/transcoders/:id' do
    get_model(params[:id], Transcoder).to_hash.to_json
  end

  put '/transcoders/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/transcoders/:id' do
    transcoder = get_model(params[:id], Transcoder)
    #TODO don't terminate if transcoder is active !

    MonitorService.instance.remove_txcoder transcoder.id
    transcoder.delete
    success
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

  delete '/transcoders/:id/slots' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.each do |s|
      transcoder.delete_slot s
      s.delete
    end
    success
  end

  get '/transcoders/:id/slots/:id' do |tid, sid|
    pass unless sid =~ /\d+/  # pass non numeric ids

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
    get_model(params[:id], Transcoder).get_net_config.to_json
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

  get '/transcoders/:id/sync' do
    get_model(params[:id], Transcoder).sync and success
  end

  get '/transcoders/:id/slots/start' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.each do |slot|
      transcoder.start_slot slot unless slot.scheme.nil?
    end
    success
  end

  get '/transcoders/:id/slots/stop' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.each do |slot|
      transcoder.stop_slot slot
    end
    success
  end

  get '/transcoders/:id/slots/status' do
    transcoder = get_model(params[:id], Transcoder)
    status = transcoder.slots.map do |slot|
      prepare_slot_status(transcoder.get_slot_status(slot)).merge({id: slot.id, slot_id: slot.slot_id})
    end
    status.to_json
  end

  get '/transcoders/:id/slots/:id/start' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    raise ApiError, 'Slot has no scheme, delete it and start again.' if slot.scheme.nil?
    transcoder.start_slot slot
    success
  end

  get '/transcoders/:id/slots/:id/stop' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    transcoder.stop_slot slot
    success
  end

  get '/transcoders/:id/slots/:id/status' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" if slot.nil?
    resp = transcoder.get_slot_status(slot)
    prepare_slot_status(resp).to_json
  end

  get '/transcoders/:id/status' do
    t = get_model(params[:id], Transcoder)
    redirect "http://#{t.host}:#{t.status_port}"
  end

  get '/transcoders/:id/load-status' do
    t = get_model(params[:id], Transcoder)
    t.load_status.to_json
  end

  # --- Sources ---

  get '/sources' do
    all_to_json Source
  end

  post '/sources' do
    name, host, port = expect_params 'name', 'host', 'port'
    save_model Source.new(name: name, host: host, port: port)
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
    clazz.all.map { |m| m.to_hash }.to_json
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
    request.body.rewind  # in case someone already read it
    logger.info "Validation error: #{errors}"
    logger.debug "request.body= #{request.body.read}"

    status 400
    headers 'X-Status-Reason' => 'Validation failed'
    errors.to_json
  end

  def expect_params(*p_names)
    p_names.map do |p|
      raise ApiError, "expecting #{p} but didn't get any" if params[p].nil?
      params[p]
    end
  end

  def prepare_slot_status(resp)
    if resp[:error] == TranscoderApi::RET_OK
      if resp[:message].include? 'stop'
        { status: 'success', running: false }
      else
        { status: 'success',
          running: true,
          signal: resp[:result][:signal],
          uptime: format_duration(resp[:result][:uptime]) }
      end
    else
      { status: 'error', type: resp[:error], message: resp[:message]}
    end
  end

  def format_duration(secs)
    mins  = secs / 60
    hours = mins / 60
    days  = hours / 24

    time_in_day = format('%02d:%02d:%02d', hours % 24, mins % 60, secs % 60)
    days > 0 ? "#{days} days #{time_in_day}" : time_in_day
  end

end

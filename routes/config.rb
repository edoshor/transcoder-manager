require_relative '../app_config'
require 'active_support/ordered_hash'

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
    delete_model get_model(params[:id], Transcoder) do |txcoder|
      MonitorService.instance.remove_txcoder txcoder.id
      txcoder.slots.each { |slot| slot.delete }
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
    pass unless sid =~ /\d+/ # pass non numeric ids

    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot
    slot.to_hash.to_json
  end

  delete '/transcoders/:id/slots/:id' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot

    delete_model(slot) { |s| transcoder.delete_slot s }
  end

  get '/transcoders/:id/net-config' do
    get_model(params[:id], Transcoder).get_net_config.to_json
  end

  put '/transcoders/:id/net-config' do
    raise 'not implemented'
  end

  # --- Captures ---

  get '/captures' do
    all_to_json Capture
  end

  post '/captures' do
    name, host = expect_params 'name', 'host'
    atts = {name: name, host: host}
    (1..4).map { |i| "input#{i}" }.each { |i| atts.store(i.to_sym, params[i]) if params[i] }
    save_model Capture.new(atts)
  end

  get '/captures/:id' do
    get_model(params[:id], Capture).to_hash.to_json
  end

  put '/captures/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/captures/:id' do
    delete_model get_model(params[:id], Capture)
  end

  # --- Sources ---

  get '/sources' do
    all_to_json Source
  end

  post '/sources' do
    name, capture_id, input = expect_params 'name', 'capture_id', 'input'
    save_model Source.new(name: name,
                          capture: get_model(capture_id, Capture),
                          input: input)
  end

  get '/sources/:id' do
    get_model(params[:id], Source).to_hash.to_json
  end

  put '/sources/:id' do
    raise ApiError, 'Operation not supported'
  end

  delete '/sources/:id' do
    delete_model get_model(params[:id], Source)
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
      begin
        preset.set_tracks tracks
        preset.to_hash.to_json
      rescue Exception => e
        validation_error e.message
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
    delete_model get_model(params[:id], Preset)
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
    delete_model get_model(params[:id], Scheme)
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
    delete_model get_model(params[:id], Event)
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

  get '/export' do
    attachment 'tm-config.json'
    JSON.pretty_generate(config_to_json)
  end

  post '/import' do
    upload = expect_params('file')[0]
    json = JSON.load upload[:tempfile]
    raise 'Incomplete configuration' unless \
         %w(captures sources presets schemes transcoders slots events).all? { |x| json.key? x }

    config_backup = config_to_json
    MonitorService.instance.shutdown
    begin
      config_from_json(json)
      success
    rescue => ex
      log_exception ex
      config_from_json(config_backup)
      raise 'Error importing configuration. Check logs.'
    ensure
        MonitorService.instance.start
    end
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

  def delete_model(model)
    if ConfigManager.can_delete? model
      yield(model) if block_given?
      model.delete and success
    else
      config_integrity_error "#{model.class} is in use. Can not delete."
    end
  end

  def all_to_hash(clazz)
    clazz.all.map { |m| m.to_hash }
  end

  def all_to_json(clazz)
    all_to_hash(clazz).to_json
  end

  def validation_error(errors)
    custom_error 'Validation', 'Validation failed', errors
  end

  def config_integrity_error(msg)
    custom_error 'Configuration', 'Configuration constraint failed', msg
  end

  def custom_error(type, reason, error)
    request.body.rewind # in case someone already read it
    logger.info "#{type} error: #{error}"
    logger.debug "request.body= #{request.body.read}"

    status 400
    headers 'X-Status-Reason' => reason
    error.is_a?(String) ? {error: error}.to_json : error.to_json
  end

  def config_to_json
    conf = %w(capture source preset scheme transcoder slot)
    .inject(ActiveSupport::OrderedHash.new) { |h, x|
      h.store("#{x}s", all_to_hash(x.camelize.constantize)) and h
    }
    conf.store('events', Event.all.map { |event| event.to_hash.merge({slots: event.slots.map(&:id)}) })
    conf
  end

  def config_from_json(json)
    %w(capture source preset scheme transcoder slot event).each do |e|
      model = e.camelize.constantize
      model.all.map &:delete
      json["#{e}s"].each { |x| model.create_from_hash HashWithIndifferentAccess.new(x) }
    end
  end

end

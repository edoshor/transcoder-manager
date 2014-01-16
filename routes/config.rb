require_relative '../app_config'
require 'active_support/ordered_hash'
require 'active_support/core_ext/string'

class TranscoderManager < Sinatra::Base

  # --- Transcoders ---

  get '/transcoders' do
    all_to_json Transcoder
  end

  post '/transcoders' do
    txcoder = Transcoder.from_params(params)
    save_model txcoder do |model|
      MonitorService.instance.add_txcoder model.id
    end
  end

  get '/transcoders/:id' do
    get_model(params[:id], Transcoder).to_hash.to_json
  end

  put '/transcoders/:id' do
    update_model get_model(params[:id], Transcoder), Transcoder.params_to_attributes(params)
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
    transcoder = get_model(params[:id], Transcoder)
    params['transcoder_id'] = transcoder.id
    slot = Slot.from_params(params)
    raise ArgumentError.new('slot id taken') if slot.valid? && transcoder.slot_taken?(slot.slot_id)
    save_model(slot) { |model| transcoder.create_slot model }
  end

  get '/transcoders/:id/slots/:id' do |tid, sid|
    pass unless sid =~ /\d+/ # pass non numeric ids
    txcoder, slot = get_slot(tid, sid)
    slot.to_hash.to_json
  end

  put '/transcoders/:id/slots/:id' do |tid, sid|
    halt 405, 'can not update existing slot'
  end

  delete '/transcoders/:id/slots/:id' do |tid, sid|
    txcoder, slot = get_slot(tid, sid)
    delete_model(slot) { |s| txcoder.delete_slot s }
  end

  def get_slot(tid, sid)
    txcoder = get_model(tid, Transcoder)
    slot = txcoder.slots[sid]
    raise MissingModelError, "Unknown slot with id #{sid}" unless slot
    [txcoder, slot]
  end

  get '/transcoders/:id/net-config' do
    get_model(params[:id], Transcoder).get_net_config.to_json
  end

  put '/transcoders/:id/net-config' do
    halt 405, 'Operation not supported'
  end

  # --- Captures ---

  get '/captures' do
    all_to_json Capture
  end

  post '/captures' do
    save_model Capture.from_params(params)
  end

  get '/captures/:id' do
    get_model(params[:id], Capture).to_hash.to_json
  end

  put '/captures/:id' do
    update_model get_model(params[:id], Capture), Capture.params_to_attributes(params)
  end

  delete '/captures/:id' do
    delete_model get_model(params[:id], Capture)
  end

  # --- Sources ---

  get '/sources' do
    all_to_json Source
  end

  post '/sources' do
    save_model Source.from_params(params)
  end

  get '/sources/:id' do
    get_model(params[:id], Source).to_hash.to_json
  end

  put '/sources/:id' do
    update_model get_model(params[:id], Source), Source.params_to_attributes(params)
  end

  delete '/sources/:id' do
    delete_model get_model(params[:id], Source)
  end

  # --- Presets ---

  get '/presets' do
    all_to_json Preset
  end

  post '/presets' do
    atts = Preset.params_to_attributes(params)
    tracks = atts.delete(:tracks)
    save_model Preset.new(atts) do |model|
      begin
        model.set_tracks tracks
      rescue ArgumentError => e
        model.delete
        validation_error(error: e.message)
      end
    end
  end

  get '/presets/:id' do
    get_model(params[:id], Preset).to_hash.to_json
  end

  put '/presets/:id' do
    preset = get_model(params[:id], Preset)
    atts = Preset.params_to_attributes(params)
    atts.delete(:tracks)
    update_model preset, atts
  end

  delete '/presets/:id' do
    delete_model get_model(params[:id], Preset)
  end

  # --- Schemes ---

  get '/schemes' do
    all_to_json Scheme
  end

  post '/schemes' do
    save_model Scheme.from_params(params)
  end

  get '/schemes/:id' do
    get_model(params[:id], Scheme).to_hash.to_json
  end

  put '/schemes/:id' do
    update_model get_model(params[:id], Scheme), Scheme.params_to_attributes(params)
  end

  delete '/schemes/:id' do
    delete_model get_model(params[:id], Scheme)
  end

  # --- Events ---

  get '/events' do
    all_to_json Event
  end

  post '/events' do
    save_model Event.from_params(params)
  end

  get '/events/:id' do
    get_model(params[:id], Event).to_hash.to_json
  end

  put '/events/:id' do
    update_model get_model(params[:id], Event), Event.params_to_attributes(params)
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

  # --- Import / Export ---

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
      tx_ids = Transcoder.all.map(&:id)
      config_from_json(json)
      tx_ids.each { |tx_id| MonitorService.instance.remove_history tx_id }
      success
    rescue => ex
      log_exception ex
      config_from_json(config_backup)
      raise 'Error importing configuration. Check logs.'
    ensure
        MonitorService.instance.start
    end
  end

  # --- Private methods ---

  private

  def get_model(id, clazz)
    clazz[id] or raise MissingModelError, "Unknown #{clazz.name} with id #{id}"
  end

  def save_model(model)
    if model.valid?
      model.save
      yield model if block_given?
      model.to_hash.to_json
    else
      validation_error model.errors
    end
  end

  def update_model(model, atts)
    model.update_attributes(atts)
    block_given? ? save_model(model, &Proc.new) : save_model(model)
  end

  def delete_model(model)
    if ConfigManager.can_delete? model
      yield(model) if block_given?
      model.delete and success
    else
      raise ApiError, "#{model.class} is in use. Can not delete."
    end
  end

  def all_to_hash(clazz)
    clazz.all.map { |m| m.to_hash }
  end

  def all_to_json(clazz)
    all_to_hash(clazz).to_json
  end

  def validation_error(errors)
    request.body.rewind # in case someone already read it
    logger.info "#Validation error: #{errors}"
    logger.debug "request.body= #{request.body.read}"
    halt 400, {'X-Status-Reason' => 'Validation failed'}, errors.to_json
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

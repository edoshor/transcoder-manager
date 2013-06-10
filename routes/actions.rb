require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  # --- Transcoders ---

  get '/transcoders/:id/save' do
    get_model(params[:id], Transcoder).save_config and success
  end

  get '/transcoders/:id/restart' do
    get_model(params[:id], Transcoder).restart and success
  end

  get '/transcoders/:id/sync' do
    get_model(params[:id], Transcoder).sync and success
  end

  get '/transcoders/:id/status' do
    t = get_model(params[:id], Transcoder)
    redirect "http://#{t.host}:#{t.status_port}"
  end

  get '/transcoders/:id/load-status' do
    t = get_model(params[:id], Transcoder)
    t.load_status.to_json
  end

  # --- Slots ---

  get '/transcoders/:id/slots/status' do
    transcoder = get_model(params[:id], Transcoder)
    slots_status(transcoder.slots).to_json
  end

  get '/transcoders/:id/slots/:id/start' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot
    raise ApiError, 'Slot has no scheme, delete it and start again.' unless slot.scheme
    transcoder.start_slot slot
    success
  end

  get '/transcoders/:id/slots/:id/stop' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot
    transcoder.stop_slot slot
    success
  end

  get '/transcoders/:id/slots/:id/status' do |tid, sid|
    transcoder = get_model(tid, Transcoder)
    slot = transcoder.slots[sid]
    raise ApiError, "Unknown slot with id #{sid}" unless slot
    resp = transcoder.get_slot_status(slot)
    prepare_slot_status(resp).to_json
  end

  # --- Broadcast events ---

  get '/events/:id/start' do
    event = get_model(params[:id], Event)
    event.start and success
  end

  get '/events/:id/stop' do
    event = get_model(params[:id], Event)
    event.stop and success
  end

  get '/events/:id/status' do
    event = get_model(params[:id], Event)
    state = event.state
    state[:uptime] = format_duration(Time.now.to_i - state[:last_switch].to_i) if state[:running]
    (params[:with_slots] ? state.merge(slots: slots_status(event.slots)) : state).to_json
  end

  private

  def slots_status(slots)
    slots.map do |slot|
      status = slot.transcoder.get_slot_status(slot)
      prepare_slot_status(status).merge({id: slot.id, slot_id: slot.slot_id})
    end
  end

  def prepare_slot_status(resp)
    if resp[:message].include? 'running'
      { status: 'success',
        running: true,
        signal: resp[:result][:signal],
        uptime: format_duration(resp[:result][:uptime]) }
    else
      { status: 'success', running: false }
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

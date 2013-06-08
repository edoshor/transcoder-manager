require_relative '../app_config'

class TranscoderManager < Sinatra::Base

  get '/transcoders/save' do
    Transcoder.all.each { |t| t.save_config }
    success
  end

  get '/transcoders/restart' do
    Transcoder.all.each { |t| t.restart }
    success
  end

  get '/transcoders/:id/save' do
    get_model(params[:id], Transcoder).save_config and success
  end

  get '/transcoders/:id/restart' do
    get_model(params[:id], Transcoder).restart and success
  end

  get '/transcoders/:id/sync' do
    get_model(params[:id], Transcoder).sync and success
  end

  get '/transcoders/:id/slots/start' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.each { |slot| transcoder.start_slot slot if slot.scheme }
    success
  end

  get '/transcoders/:id/slots/stop' do
    transcoder = get_model(params[:id], Transcoder)
    transcoder.slots.each { |slot| transcoder.stop_slot slot }
    success
  end

  get '/transcoders/:id/slots/status' do
    transcoder = get_model(params[:id], Transcoder)
    status = transcoder.slots.map do |slot|
      prepare_slot_status(transcoder.get_slot_status(slot))
      .merge({id: slot.id, slot_id: slot.slot_id})
    end
    status.to_json
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

  get '/transcoders/:id/status' do
    t = get_model(params[:id], Transcoder)
    redirect "http://#{t.host}:#{t.status_port}"
  end

  get '/transcoders/:id/load-status' do
    t = get_model(params[:id], Transcoder)
    t.load_status.to_json
  end

  private

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

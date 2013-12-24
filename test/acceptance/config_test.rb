require_relative 'acceptance_helper'
require 'tempfile'

class ConfigTest < Test::Unit::TestCase
  include AcceptanceHelper

  # --- Transcoders ---

  def test_create_transcoder
    atts = attributes_for(:transcoder)
    post '/transcoders', atts
    txcoder = assert_successful last_response
    assert_attributes_eq atts, txcoder
  end

  def test_transcoder_create_slot
    transcoder = create(:transcoder)
    scheme = create(:scheme)
    atts = {slot_id: 10, scheme_id: scheme.id}
    post "/transcoders/#{transcoder.id}/slots", atts
    slot = assert_successful last_response
    assert_attributes_eq atts, slot
    assert_equal transcoder.id, slot['transcoder_id']
    assert_equal transcoder.name, slot['transcoder_name']
    assert_equal scheme.name, slot['scheme_name']
  end

  def test_transcoder_get_slots
    get '/transcoders/1/slots'
    assert_not_found last_response

    transcoder = create(:transcoder)
    get "/transcoders/#{transcoder.id}/slots"
    body = assert_successful last_response
    assert_empty body

    scheme = create(:scheme)
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, scheme_id: scheme.id
    assert_successful last_response
    get "/transcoders/#{transcoder.id}/slots"
    body = assert_successful last_response
    assert_equal 1, body.size
    assert_equal '1', body[0]['id']
    assert_equal 10, body[0]['slot_id']
    assert_equal transcoder.id, body[0]['transcoder_id']
    assert_equal transcoder.name, body[0]['transcoder_name']
    assert_equal scheme.id, body[0]['scheme_id']
    assert_equal scheme.name, body[0]['scheme_name']
  end

  def test_get_slot
    get '/transcoders/1/slots/1'
    assert_not_found last_response

    transcoder = create(:transcoder)
    get "/transcoders/#{transcoder.id}/slots/1"
    assert_not_found last_response

    scheme = create(:scheme)
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, scheme_id: scheme.id
    body = assert_successful last_response
    get "/transcoders/#{transcoder.id}/slots/#{body['id']}"
    body = assert_successful last_response
    assert_equal '1', body['id']
    assert_equal 10, body['slot_id']
    assert_equal transcoder.id, body['transcoder_id']
    assert_equal transcoder.name, body['transcoder_name']
    assert_equal scheme.id, body['scheme_id']
    assert_equal scheme.name, body['scheme_name']
  end

  def test_delete_slot
    delete '/transcoders/1/slots/1'
    assert_not_found last_response

    transcoder = create(:transcoder)
    delete "/transcoders/#{transcoder.id}/slots/1"
    assert_not_found last_response

    scheme = create(:scheme)
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, scheme_id: scheme.id
    body = assert_successful last_response
    delete "/transcoders/#{transcoder.id}/slots/#{body['id']}"
    body = assert_successful last_response
    assert_match(/success/, body['result'])
  end

  def test_delete_transcoder
    txcoder = create(:transcoder)
    scheme = create(:scheme)
    5.times { |i| Slot.create(slot_id: i, transcoder: txcoder, scheme: scheme) }

    delete "/transcoders/#{txcoder.id}"
    assert_successful last_response
    assert_equal 0, Slot.all.size
  end

  # --- Captures ---

  def test_create_capture
    atts = attributes_for(:capture)
    post '/captures', atts
    capture = assert_successful last_response
    assert_attributes_eq atts, capture
  end

  def test_get_capture
    get '/captures/1'
    assert_not_found last_response

    capture = create(:capture)
    get "/captures/#{capture.id}"
    assert_successful_eq capture, last_response
  end

  def test_edit_capture
    put '/captures/1'
    assert_not_found last_response

    atts = create(:capture).to_hash
    atts[:name] = 'new name'
    put "/captures/#{atts.delete(:id)}", atts
    assert_successful_atts_eq atts, last_response
  end

  def test_edit_capture_error
    atts = create(:capture).to_hash
    atts[:host] = 'Illegal ip'
    put "/captures/#{atts.delete(:id)}", atts
    errors = assert_validation_error last_response
    assert_not_nil errors['host']
  end

  def test_delete_capture
    delete '/captures/1'
    assert_not_found last_response

    capture = create(:capture)
    delete "/captures/#{capture.id}"
    body = assert_successful last_response
    assert body['result'].include? 'success'

    source = create(:source)
    delete "/captures/#{source.capture.id}"
    assert_api_error last_response
  end

  # --- Sources ---

  def test_get_sources
    get '/sources'
    body = assert_successful last_response
    assert_empty body

    sources = 5.times.map { create(:source) }
    get '/sources'
    body = assert_successful last_response
    assert_not_nil body
    assert_equal sources.length, body.length
    sources.zip(body).each { |source, source_json| assert_json_eq source, source_json}
  end

  def test_create_source
    capture = create(:capture)
    atts = attributes_for(:source).merge!({capture_id: capture.id})
    post '/sources', atts
    atts['capture_name'] = capture.name
    assert_successful_atts_eq atts, last_response
  end

  def test_create_source_validations
    post '/sources', name: 'source3', capture_id: '1'
    assert_bad_request last_response, 'expecting input'

    post '/sources', name: 'source3', input: 1
    assert_bad_request last_response, 'expecting capture_id'

    post '/sources', capture_id: '1', input: 4
    assert_bad_request last_response, 'expecting name'

    post '/sources', name: 'source3', capture_id: '1', input: 5
    assert_bad_request last_response

    capture = create(:capture)
    post '/sources', name: 'source3', capture_id: capture.id, input: 5
    body = assert_validation_error last_response
    assert_equal 'not_in_range', body['input'][0]
  end

  def test_get_source
    get '/sources/1'
    assert_not_found last_response

    source = create(:source)
    get "/sources/#{source.id}"
    assert_successful_eq source, last_response
  end

  def test_edit_source
    put '/sources/1'
    assert_not_found last_response

    atts = create(:source).to_hash
    path = "/sources/#{atts.delete(:id)}"
    atts[:name] = 'new name'
    put path, atts
    assert_successful_atts_eq atts, last_response

    new_capture = create(:capture)
    atts[:capture_id] = new_capture.id
    atts[:capture_name] = new_capture.name
    put path, atts
    assert_successful_atts_eq atts, last_response
  end

  def test_edit_source_error
    source = create(:source)
    atts = source.to_hash.merge!({capture_id: 1111})
    put "/sources/#{source.id}", atts
    assert_bad_request last_response

    atts = source.to_hash.merge!({input: 5})
    put "/sources/#{source.id}", atts
    errors = assert_validation_error last_response
    assert_not_nil errors['input']
  end

  def test_delete_source
    delete '/sources/1'
    assert_not_found last_response

    source = create(:source)
    delete "/sources/#{source.id}"
    body = assert_successful last_response
    assert body['result'].include? 'success'
  end

  # --- Presets ---

  def test_create_preset
    atts = attributes_for(:preset)
    atts[:tracks] = build_list(:video_track, 1) + build_list(:audio_track, 7)
    atts[:tracks].map! { |t| t.to_hash }

    post '/presets', atts
    assert_successful_atts_eq atts, last_response
  end

  def test_create_preset_error
    atts = attributes_for(:preset)

    atts[:tracks] = [{gain: 0, num_channels: 0, profile_number: 1}]
    post '/presets', atts
    assert_validation_error last_response

    atts[:tracks] = [{gain: 0, num_channels: 0},
                     {gain: 0, num_channels: 0, profile_number: 1}]
    post '/presets', atts
    assert_validation_error last_response

    atts[:tracks] = [{gain: 100, num_channels: 1, profile_number: 101},
                     {gain: 0, num_channels: 0, profile_number: 1}]
    post '/presets', atts
    assert_validation_error last_response
  end

  # --- Schemes ---

  def test_create_scheme
    preset = create(:preset)
    source = create(:source)
    atts = {name: 'scheme1',
            source1_id: source.id,
            preset_id: preset.id,
            audio_mappings: (0..preset.tracks.size).to_a}
    post '/schemes', atts
    atts[:src1_id] = atts.delete :source1_id
    scheme = assert_successful_atts_eq atts, last_response
    assert_equal source.name, scheme['src1_name']
    assert_equal preset.name, scheme['preset_name']
  end

  def test_delete_scheme_source
    preset = create(:preset)
    source = create(:source)
    post '/schemes', { name: 'scheme1',
                       source1_id: source.id,
                       preset_id: preset.id,
                       audio_mappings: (0..preset.tracks.size).to_a }
    scheme = assert_successful last_response

    delete "/sources/#{scheme['src1_id']}"
    assert_api_error last_response
  end

  def test_delete_scheme_preset
    preset = create(:preset)
    source = create(:source)
    post '/schemes', { name: 'scheme1',
                       source1_id: source.id,
                       preset_id: preset.id,
                       audio_mappings: (0..preset.tracks.size).to_a }
    scheme = assert_successful last_response

    delete "/presets/#{scheme['preset_id']}"
    assert_api_error last_response
  end

  # --- Events ---

  def test_create_event
    atts = {name: 'event1'}
    post '/events', atts
    assert_successful_atts_eq atts, last_response
  end

  def test_event_add_slot
    txcoder = create(:transcoder)
    scheme = create(:scheme)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)

    post '/events', {name: 'event1'}
    event = assert_successful last_response

    post "/events/#{event['id']}/slots", {slot_id: slot.id}
    body = assert_successful last_response
    assert_match(/success/, body['result'])

    get "/events/#{event['id']}/slots"
    slots = assert_successful last_response
    assert_not_empty slots
    assert_equal 1, slots.size
    assert_equal slot.id, slots[0]['id']
  end

  def test_event_remove_slot
    post '/events', {name: 'event1'}
    event = assert_successful last_response
    txcoder = create(:transcoder)
    scheme = create(:scheme)

    slots_models = 5.times.inject([]) do |a, i|
      slot = Slot.create(slot_id: i, transcoder: txcoder, scheme: scheme)
      post "/events/#{event['id']}/slots", {slot_id: slot.id}
      body = assert_successful last_response
      assert_match(/success/, body['result'])
      a << slot
    end
    get "/events/#{event['id']}/slots"
    slots = assert_successful last_response
    assert_not_empty slots
    assert_equal 5, slots.size

    event_model = Event[event['id']]
    Event.stubs(:[]).with(event['id']).returns(event_model)
    slots_models.each do |slot|
      event_model.expects(:remove_slot).with() {|s| s.id == slot.id}
      delete "/events/#{event['id']}/slots/#{slot.id}"
      body = assert_successful last_response
      assert_match(/success/, body['result'])
    end
  end

  def test_event_transcoder_deleted
    t1 = create(:transcoder)
    t2 = create(:transcoder)
    scheme = create(:scheme)
    slot = Slot.create(slot_id: 1, transcoder: t1, scheme: scheme)

    post '/events', {name: 'event1'}
    event = assert_successful last_response
    assert_not_nil event
    post "/events/#{event['id']}/slots", slot_id: slot.id
    assert_successful last_response
    delete "/transcoders/#{t1.id}"
    assert_api_error last_response
    delete "/transcoders/#{t2.id}"
    assert_successful last_response

    delete "/transcoders/#{t1.id}/slots/#{slot.id}"
    assert_api_error last_response
  end

  def test_event_scheme_deleted
    txcoder = create(:transcoder)
    scheme = create(:scheme)
    scheme2 = create(:scheme)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)

    post '/events', {name: 'event1'}
    event = assert_successful last_response
    assert_not_nil event
    post "/events/#{event['id']}/slots", slot_id: slot.id
    assert_successful last_response
    delete "/schemes/#{scheme.id}"
    assert_api_error last_response
    delete "/schemes/#{scheme2.id}"
    assert_successful last_response
  end

  # --- Import Export ---

  def test_export_empty
    get '/export'
    resp = last_response
    assert_equal 200, resp.status
    assert_not_nil resp.header['Content-Disposition']
    assert resp.header['Content-Type'].include?('application/json')
    body = JSON.parse resp.body
    %w(captures sources presets schemes transcoders slots events).each do |x|
      assert body.key? x
      assert_empty body[x]
    end
  end

  def test_export
    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)
    event = create(:event)
    event.add_slot slot

    get '/export'
    config = assert_successful last_response
    assert_json_eq txcoder, config['transcoders'][0]
    assert_json_eq scheme, config['schemes'][0]
    assert_json_eq slot, config['slots'][0]
    assert_json_eq scheme.preset, config['presets'][0]
    assert_json_eq scheme.src1, config['sources'][0]
    assert_json_eq scheme.src2, config['sources'][1]
    assert_json_eq scheme.src1.capture, config['captures'][0]
    assert_json_eq scheme.src2.capture, config['captures'][1]
    assert_equal event.id, config['events'][0]['id']
    assert_equal event.name, config['events'][0]['name']
    assert_equal [slot.id], config['events'][0]['slots']
  end

  def test_import
    scheme = create(:scheme)
    txcoder = create(:transcoder)
    slot = Slot.create(slot_id: 1, transcoder: txcoder, scheme: scheme)
    event = create(:event)
    event.add_slot slot

    get '/export'
    json = last_response.body
    file = Tempfile.new(%w(tm-config .json))
    begin
      file.write json
      file.close
      create(:scheme) #create another scheme to change the configuration at this step
      post '/import', 'file' => Rack::Test::UploadedFile.new(file.path, 'application/json')
      assert_successful last_response
    ensure
      file.unlink
    end

    get '/export'
    config = assert_successful last_response
    assert_json_eq txcoder, config['transcoders'][0]
    assert_json_eq scheme, config['schemes'][0]
    assert_json_eq slot, config['slots'][0]
    assert_json_eq scheme.preset, config['presets'][0]
    assert_json_eq scheme.src1, config['sources'][0]
    assert_json_eq scheme.src2, config['sources'][1]
    assert_json_eq scheme.src1.capture, config['captures'][0]
    assert_json_eq scheme.src2.capture, config['captures'][1]
    assert_equal event.id, config['events'][0]['id']
    assert_equal event.name, config['events'][0]['name']
    assert_equal [slot.id], config['events'][0]['slots']
  end

end
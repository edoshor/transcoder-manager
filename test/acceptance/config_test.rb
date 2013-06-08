require_relative 'acceptance_helper'

class ConfigTest < Test::Unit::TestCase
  include AcceptanceHelper

  # --- Transcoders ---

  def test_create_transcoder
    post '/transcoders', name: 'transcoder1', host: '10.65.6.104'
    body = assert_successful last_response
    assert_not_nil body
    assert_equal '1', body['id']
    assert_equal 'transcoder1', body['name']
    assert_equal '10.65.6.104', body['host']
    assert_equal DEFAULT_PORT, body['port']
    assert_equal DEFAULT_STATUS_PORT, body['status_port']
  end

  def test_transcoder_create_slot
    transcoder = create(:transcoder)
    scheme = create(:scheme)
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, scheme_id: scheme.id
    body = assert_successful last_response
    assert_equal '1', body['id']
    assert_equal 10, body['slot_id']
    assert_equal transcoder.id, body['transcoder_id']
    assert_equal transcoder.name, body['transcoder_name']
    assert_equal scheme.id, body['scheme_id']
    assert_equal scheme.name, body['scheme_name']
  end

  def test_transcoder_get_slots
    get '/transcoders/1/slots'
    body = assert_api_error last_response
    assert_match(/Unknown Transcoder/, body)

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
    body = assert_api_error last_response
    assert_match(/Unknown Transcoder/, body)

    transcoder = create(:transcoder)
    get "/transcoders/#{transcoder.id}/slots/1"
    body = assert_api_error last_response
    assert_match(/Unknown slot/, body)

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
    body = assert_api_error last_response
    assert_match(/Unknown Transcoder/, body)

    transcoder = create(:transcoder)
    delete "/transcoders/#{transcoder.id}/slots/1"
    body = assert_api_error last_response
    assert_match(/Unknown slot/, body)

    scheme = create(:scheme)
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, scheme_id: scheme.id
    body = assert_successful last_response
    delete "/transcoders/#{transcoder.id}/slots/#{body['id']}"
    body = assert_successful last_response
    assert_match(/success/, body['result'])
  end

  # --- Sources ---

  def test_get_sources
    get '/sources'
    body = assert_successful last_response
    assert_empty body

    source1 = create(:source)
    source2 = create(:source)
    get '/sources'
    body = assert_successful last_response
    assert_not_nil body
    assert_equal 2, body.length
    assert_equal '1', body[0]['id']
    assert_equal source1.name, body[0]['name']
    assert_equal source1.host, body[0]['host']
    assert_equal source1.port, body[0]['port']
    assert_equal '2', body[1]['id']
    assert_equal source2.name, body[1]['name']
    assert_equal source2.host, body[1]['host']
    assert_equal source2.port, body[1]['port']
  end

  def test_create_source
    attributes = attributes_for(:source)
    post '/sources', attributes
    source = assert_successful last_response
    assert_not_nil source
    assert_equal '1', source['id']
    assert_equal attributes[:name], source['name']
    assert_equal attributes[:host], source['host']
    assert_equal attributes[:port], source['port'].to_i
  end

  def test_create_source_validations
    post '/sources', name: 'source3', host: '192.168.2.1'
    body = assert_api_error last_response
    assert_match(/expecting port/, body)

    post '/sources', name: 'source3', port: 3000
    body = assert_api_error last_response
    assert_match(/expecting host/, body)

    post '/sources', host: '192.168.2.1', port: 3000
    body = assert_api_error last_response
    assert_match(/expecting name/, body)

    post '/sources', name: 'source3', host: '192.168.2.1', port: 99999
    body = assert_validation_error last_response
    assert_equal 'not_in_range', body['port'][0]

    post '/sources', name: 'source3', host: '192.168.2.1.1', port: 3000
    body = assert_validation_error last_response
    assert_equal 'not_valid_ipv4', body['host'][0]
  end

  def test_get_source
    get '/sources/1'
    body = assert_api_error last_response
    assert_match(/Unknown Source/, body)

    post '/sources', attributes_for(:source)
    source = assert_successful last_response
    get "/sources/#{source['id']}"
    body = assert_successful last_response
    assert_equal source, body
  end

  def test_delete_source
    delete '/sources/1'
    body = assert_api_error last_response
    assert_match(/Unknown Source/, body)

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
    preset = assert_successful last_response
    assert_not_nil preset
    assert_equal '1', preset['id']
    assert_equal atts[:tracks].length, preset['tracks'].length
    assert_equal atts[:name], preset['name']
    atts[:tracks].each_index do |i|
      assert_equal atts[:tracks][i][:gain], preset['tracks'][i]['gain'].to_i
      assert_equal atts[:tracks][i][:num_channels], preset['tracks'][i]['num_channels'].to_i
      assert_equal atts[:tracks][i][:profile_number], preset['tracks'][i]['profile_number'].to_i
    end
  end

  # --- Schemes ---

  def test_create_scheme
    preset = create(:preset)
    source = create(:source)
    post '/schemes', { name: 'scheme1',
                       source1_id: source.id,
                       preset_id: preset.id,
                       audio_mappings: (0..preset.tracks.size).to_a }

    scheme = assert_successful last_response
    assert_not_nil scheme
  end

end
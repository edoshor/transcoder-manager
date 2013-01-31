require_relative '../test_helper'
require_relative '../../app'
require_relative '../../app_config'
require 'test/unit'
require 'rack/test'

class UserTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    TranscoderManager.new
  end

  def setup
    Ohm.flush # clear all keys in redis before each test
  end

  def self.shutdown
    Ohm.flush # clear all keys in redis after tests finished
  end

  def test_root
    get '/'
    body = assert_successful last_response
    assert body['result'].include? 'BB Web Broadcast - Transcoder Manager'
  end

  # --- Transcoders ---

  def test_create_transcoder
    post '/transcoders',name: 'transcoder1', host: '10.65.6.104'
    body = assert_successful last_response
    assert_not_nil body
    assert_equal '1', body['id']
    assert_equal 'transcoder1', body['name']
    assert_equal '10.65.6.104', body['host']
    assert_equal DEFAULT_PORT, body['port']
    assert_equal DEFAULT_STATUS_PORT, body['status_port']
  end

  def test_transcoder_create_slot
    transcoder = Transcoder.create(name: 'transcoder1', host: '10.65.6.104')
    preset = Preset.create(name: 'preset1')
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, preset_id: preset.id
    body = assert_successful last_response
    assert_equal '1', body['id']
    assert_equal '10', body['slot_id']
    assert_equal '1', body['transcoder_id']
    assert_equal 'transcoder1', body['transcoder_name']
    assert_equal '1', body['preset_id']
    assert_equal 'preset1', body['preset_name']
  end

  def test_transcoder_get_slots
    get '/transcoders/1/slots'
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown transcoder'

    transcoder = Transcoder.create(name: 'transcoder1', host: '10.65.6.104')
    get "/transcoders/#{transcoder.id}/slots"
    body = assert_successful last_response
    assert_empty body

    preset = Preset.create(name: 'preset1')
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, preset_id: preset.id
    assert_successful last_response
    get "/transcoders/#{transcoder.id}/slots"
    body = assert_successful last_response
    assert_equal 1, body.size
    assert_equal '1', body[0]['id']
    assert_equal '10', body[0]['slot_id']
    assert_equal '1', body[0]['transcoder_id']
    assert_equal 'transcoder1', body[0]['transcoder_name']
    assert_equal '1', body[0]['preset_id']
    assert_equal 'preset1', body[0]['preset_name']
  end

  def test_get_slot
    get '/transcoders/1/slots/1'
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown transcoder'

    transcoder = Transcoder.create(name: 'transcoder1', host: '10.65.6.104')
    get "/transcoders/#{transcoder.id}/slots/1"
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown slot'

    preset = Preset.create(name: 'preset1')
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, preset_id: preset.id
    body = assert_successful last_response
    get "/transcoders/#{transcoder.id}/slots/#{body['id']}"
    body = assert_successful last_response
    assert_equal '1', body['id']
    assert_equal '10', body['slot_id']
    assert_equal '1', body['transcoder_id']
    assert_equal 'transcoder1', body['transcoder_name']
    assert_equal '1', body['preset_id']
    assert_equal 'preset1', body['preset_name']
  end

  def test_delete_slot
    delete '/transcoders/1/slots/1'
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown transcoder'

    transcoder = Transcoder.create(name: 'transcoder1', host: '10.65.6.104')
    delete "/transcoders/#{transcoder.id}/slots/1"
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown slot'

    preset = Preset.create(name: 'preset1')
    post "/transcoders/#{transcoder.id}/slots", slot_id: 10, preset_id: preset.id
    body = assert_successful last_response
    delete "/transcoders/#{transcoder.id}/slots/#{body['id']}"
    body = assert_successful last_response
    assert body['result'].include? 'success'
  end

  # --- Sources ---

  def test_get_sources
    get '/sources'
    body = assert_successful last_response
    assert_empty body

    source1 = Source.create(name: 'source1', host: '192.168.2.1', port: 3000)
    source2 = Source.create(name: 'source2', host: '192.168.2.1', port: 3001)
    get '/sources'
    body = assert_successful last_response
    assert_not_nil body
    assert_equal 2, body.length
    assert_equal '1', body[0]['id']
    assert_equal source1.name, body[0]['name']
    assert_equal source1.host, body[0]['host']
    assert_equal source1.port.to_s, body[0]['port']
    assert_equal '2', body[1]['id']
    assert_equal source2.name, body[1]['name']
    assert_equal source2.host, body[1]['host']
    assert_equal source2.port.to_s, body[1]['port']
  end

  def test_create_source
    post '/sources', name: 'source3', host: '192.168.2.1', port: 3000
    source = assert_successful last_response
    assert_not_nil source
    assert_equal '1', source['id']
    assert_equal 'source3', source['name']
    assert_equal '192.168.2.1', source['host']
    assert_equal '3000', source['port']
  end

  def test_create_source_validations
    post '/sources', name: 'source3', host: '192.168.2.1'
    body = assert_validation_error last_response
    assert_equal 1, body['port'].length
    assert_equal 'not_numeric', body['port'][0]

    post '/sources', name: 'source3', host: '192.168.2.1', port: 99999
    body = assert_validation_error last_response
    assert_equal 'not_in_range', body['port'][0]

    post '/sources', name: 'source3', port: 3000
    body = assert_validation_error last_response
    assert_equal 'not_present', body['host'][0]

    post '/sources', name: 'source3', host: '192.168.2.1.1', port: 3000
    body = assert_validation_error last_response
    assert_equal 'not_valid_ipv4', body['host'][0]

    post '/sources', host: '192.168.2.1', port: 3000
    body = assert_validation_error last_response
    assert_equal 'not_present', body['name'][0]
  end

  def test_get_source
    get '/sources/1'
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown source'

    post '/sources', name: 'source3', host: '192.168.2.1', port: 3000
    source = assert_successful last_response
    get "/sources/#{source['id']}"
    body = assert_successful last_response
    assert_equal source, body
  end

  def test_update_source
    source = Source.create(name: 'source1', host: '192.168.2.1', port: 3000)

    put "/sources/#{source.id}", name: 'new_name'
    body = assert_successful last_response
    assert_equal source.id, body['id']
    assert_equal source.host, body['host']
    assert_equal source.port.to_s, body['port']
    assert_equal 'new_name', body['name']

    put "/sources/#{source.id}", host: '192.168.2.100', port: 3001
    body = assert_successful last_response
    assert_equal source.id, body['id']
    assert_equal '192.168.2.100', body['host']
    assert_equal '3001', body['port']
    assert_equal 'new_name', body['name']
  end

  def test_update_source_validations
    put '/sources/1', name: 'source1'
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown source'

    source = Source.create(name: 'source1', host: '192.168.2.1', port: 3000)

    put "/sources/#{source.id}", host: '192.168.2.1.1'
    body = assert_validation_error last_response
    assert body['host'][0].include? 'not_valid_ipv4'

    put "/sources/#{source.id}", port: 99999
    body = assert_validation_error last_response
    assert body['port'][0].include? 'not_in_range'

    put '/sources/1'
    body = assert_successful last_response
    assert_equal source.id, body['id']
    assert_equal 'source1', body['name']
    assert_equal '192.168.2.1', body['host']
    assert_equal '3000', body['port']
  end

  def test_delete_source
    delete '/sources/1'
    body = assert_api_error last_response
    assert body['message'].include? 'Unknown source'

    source = Source.create(name: 'source1', host: '192.168.2.1', port: 3000)
    delete "/sources/#{source.id}"
    body = assert_successful last_response
    assert body['result'].include? 'success'
  end

  # --- Presets ---

  def test_create_preset
    post '/presets', name: 'preset1', tracks: [
        {gain: 20, num_channels: 2, profile_number: 101},
        {gain: 0, num_channels: 0, profile_number: 1}]
    preset = assert_successful last_response
    assert_not_nil preset
    assert_equal '1', preset['id']
    assert_equal 'preset1', preset['name']
    assert_equal 2, preset['tracks'].length
    assert_equal '20', preset['tracks'][0]['gain']
    assert_equal '2', preset['tracks'][0]['num_channels']
    assert_equal '101', preset['tracks'][0]['profile_number']
    assert_equal '0', preset['tracks'][1]['gain']
    assert_equal '0', preset['tracks'][1]['num_channels']
    assert_equal '1', preset['tracks'][1]['profile_number']
  end

  private

  def assert_successful(resp)
    assert_equal 200, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    JSON.parse resp.body
  end

  def assert_validation_error(resp)
    assert_equal 400, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    assert resp.header['X-Status-Reason'].include?('Validation failed')
    body = JSON.parse resp.body
    assert_false body.empty?
    body
  end

  def assert_api_error(resp)
    assert_equal 400, resp.status
    assert resp.header['Content-Type'].include?('application/json')
    body = JSON.parse resp.body
    assert_equal 'Api error', body['result']
    assert_not_nil body['message']
    body
  end

end

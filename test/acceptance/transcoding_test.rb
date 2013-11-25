require_relative 'acceptance_helper'

class TranscodingTest < Test::Unit::TestCase
  include AcceptanceHelper

  def test_start_slot
    post '/transcoders', name: 'transcoder1', host: '10.65.6.104'
    post '/captures', name: 'capture1', host: '192.168.2.1', input1:3000, input2: 3001
    post '/sources', name: 'source1', capture_id: 1, input:1
    post '/sources', name: 'source2', capture_id: 1, input:2
    post '/presets', name: 'preset1', tracks: [
        {gain: 0, num_channels: 0, profile_number: 1},
        {gain: 10, num_channels: 2, profile_number: 101},
        {gain: 20, num_channels: 1, profile_number: 102}]
    post '/schemes', name: 'scheme1', preset_id: 1, source1_id: 1, source2_id: 2, audio_mappings: [0, 1, 2]
    post '/transcoders/1/slots', slot_id: 1, scheme_id: 1

    get '/transcoders/1/slots/1/start'
    body = assert_successful last_response
    assert_equal 'success', body['result']

    get '/transcoders/1/slots/1/status'
    body = assert_successful last_response
    assert_equal 'success', body['status']
    assert body['signal'].to_i.between?(1, 2)
    assert body['uptime'].to_i >= 0
  end

end

require_relative 'acceptance_helper'

class TranscodingTest < Test::Unit::TestCase
  include AcceptanceHelper

  def test_root
    get '/'
    body = assert_successful last_response
    assert body['result'].include? 'BB Web Broadcast - Transcoder Manager'
  end

  def test_start_slot
    post '/transcoders', name: 'transcoder1', host: '10.65.6.104'
    post '/sources', name: 'source1', host: '192.168.2.1', port: 3000
    post '/sources', name: 'source2', host: '192.168.2.1', port: 3001
    post '/presets', name: 'preset1', tracks: [
        {gain: 0, num_channels: 0, profile_number: 1},
        {gain: 10, num_channels: 2, profile_number: 101},
        {gain: 20, num_channels: 1, profile_number: 102}]
    post '/schemes', name: 'scheme1', preset_id: 1, source1_id: 1, source2_id: 2, audio_mappings: [0, 1, 2]
    post '/transcoders/1/slots', slot_id: 1, scheme_id: 1

    get '/transcoders/1/slots/1/start'
    body = assert_successful last_response
    assert_match /success/, body
  end

end

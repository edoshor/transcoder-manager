require_relative '../test_helper'

class TestTranscoder < Test::Unit::TestCase
  include TestHelper

  def test_sync_no_slots
    api, transcoder = transcoder_with_api_mock

    api.expects(:is_alive?).returns(true)
    api.expects(:mod_get_slots).returns({result: {slots_cnt: 0, slots_ids: []}})

    transcoder.sync
  end

  def test_sync_one_slot_stopped
    api, transcoder = transcoder_with_api_mock

    api.expects(:is_alive?).returns(true)
    api.expects(:mod_get_slots).returns({error:1, result: {slots_cnt: 1, slots_ids: [1]}})
    api.expects(:mod_slot_get_status).with(1).returns({error:1, message: 'Slot is stopped'})

    assert_equal 0, transcoder.slots.size
    transcoder.sync
    assert_equal 1, transcoder.slots.size
  end

  def test_sync_one_slot_running
    api, transcoder = transcoder_with_api_mock

    scheme = create(:scheme)
    src1 = scheme.src1
    src2 = scheme.src2
    preset = scheme.preset
    audio_mappings = scheme.audio_mappings

    api.expects(:is_alive?).returns(true).times(2)
    api.expects(:mod_get_slots).returns({error:1, result: {slots_cnt: 1, slots_ids: [1]}}).times(2)
    api.expects(:mod_slot_get_status).with(1)
    .returns({error:1, message: 'Slot is running',
              result: {ip1: src1.host, port1: src1.port,
                       ip2: src2.host, port2: src2.port,
                       tracks_cnt: audio_mappings.size,
                       tracks: audio_mappings}})
    .times(2)
    api.expects(:mod_get_slot).with(1)
    .returns({error:1, result: {total_tracks: 8, tracks: [0..7]}},
             {error: 1, result: {total_tracks: preset.tracks.size,
                                 tracks: preset.tracks.map { |t| t.profile_number }}})
    .times(2)

    assert_equal 0, transcoder.slots.size
    transcoder.sync
    assert_equal 1, transcoder.slots.size
    assert_nil transcoder.slots.first.scheme

    transcoder.sync
    assert_equal 1, transcoder.slots.size
    assert_equal scheme, transcoder.slots.first.scheme
  end

  def test_load_status
    transcoder = create(:transcoder)

    stub_request(:get, "#{transcoder.host}:#{transcoder.status_port}")
    .to_return(status: 200, body: {:'cpu-load' => 23.4, :'temp' =>  61.9}.to_json)

    result = transcoder.load_status
    assert_equal 23.4, result[:cpu]
    assert_equal 61.9, result[:temp]
  end

  def test_load_status_error
    transcoder = create(:transcoder)

    stub_request(:get, "#{transcoder.host}:#{transcoder.status_port}")
    .to_return(status: [500, 'Internal Server Error'])

    assert_raise TranscoderError do
      transcoder.load_status
    end

  end

  private

  def transcoder_with_api_mock
    transcoder = create(:transcoder)
    api = TranscoderApi.new(host: transcoder.host, port: transcoder.port)
    transcoder.api = api
    return api, transcoder
  end

end


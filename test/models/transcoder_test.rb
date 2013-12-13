require_relative '../test_helper'

class TestTranscoder < Test::Unit::TestCase
  include TestHelper

  def test_get_slot
    api, transcoder = transcoder_with_api_mock

    slot_resp = {error: 1, result: {slot: 'hash w slot details'}}
    api.expects(:mod_get_slot).returns(slot_resp)
    resp = transcoder.get_slot Slot.new(slot_id: 1)
    assert_equal slot_resp[:result], resp

    assert_raise(Transcoder::TranscoderError) do
      api.expects(:mod_get_slot).returns({error:3, message: 'expecting error'})
      transcoder.get_slot Slot.new(slot_id: 1)
    end
  end

  def test_get_slot_status
    api, transcoder = transcoder_with_api_mock

    status_resp = {error: 1, message: 'Slot is stopped'}
    api.expects(:mod_slot_get_status).returns(status_resp)
    resp = transcoder.get_slot_status Slot.new(slot_id: 1)
    assert_equal status_resp, resp

    assert_raise(Transcoder::TranscoderError) do
      api.expects(:mod_slot_get_status).returns({error:3, message: 'expecting error'})
      transcoder.get_slot_status Slot.new(slot_id: 1)
    end
  end

  def test_sync_no_slots
    api, transcoder = transcoder_with_api_mock

    api.expects(:is_alive?).returns(true)
    api.expects(:mod_get_slots).returns({error: 1, result: {slots_cnt: 0, slots_ids: []}})

    errors = transcoder.sync
    assert_empty errors
  end

  def test_sync_one_slot_stopped
    api, transcoder = transcoder_with_api_mock

    api.expects(:is_alive?).returns(true)
    api.expects(:mod_get_slots).returns({error: 1, result: {slots_cnt: 1, slots_ids: [1]}})
    preset = create(:preset)
    api.expects(:mod_get_slot).with(1)
    .returns({error: 1, result: {total_tracks: preset.tracks.size,
                                 tracks: preset.tracks.map { |t| t.to_a }}})
    api.expects(:mod_slot_get_status).with(1).returns({error: 1, message: 'Slot is stopped'})

    assert_equal 0, transcoder.slots.size
    errors = transcoder.sync
    assert_empty errors
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
    api.expects(:mod_get_slots).returns({error: 1, result: {slots_cnt: 1, slots_ids: [1]}}).times(2)
    api.expects(:mod_slot_get_status).with(1)
    .returns({error: 1, message: 'Slot is stopped'},
             {error: 1, message: 'Slot is running',
              result: {ip1: src1.host, port1: src1.port,
                       ip2: src2.host, port2: src2.port,
                       tracks_cnt: audio_mappings.size,
                       tracks: audio_mappings.to_a}})
    .times(2)
    api.expects(:mod_get_slot).with(1)
    .returns({error: 1, result: {total_tracks: 2, tracks: [[1, 0, 0, 0], [101, 2, 10, 0]]}},
             {error: 1, result: {total_tracks: preset.tracks.size,
                                 tracks: preset.tracks.map { |t| t.to_a }}})
    .times(2)

    assert_equal 0, transcoder.slots.size
    errors = transcoder.sync
    assert_empty errors
    assert_equal 1, transcoder.slots.size
    assert_nil transcoder.slots.first.scheme

    errors = transcoder.sync
    assert_empty errors
    assert_equal 1, transcoder.slots.size
    assert_equal scheme, transcoder.slots.first.scheme
  end

  def test_self_create_from_hash
    transcoder = create(:transcoder)
    other = Transcoder.create_from_hash(transcoder.to_hash)
    assert_equal transcoder.to_hash, other.to_hash
  end

  private

  def transcoder_with_api_mock
    transcoder = create(:transcoder)
    api = TranscoderApi.new(host: transcoder.host, port: transcoder.port)
    transcoder.api = api
    return api, transcoder
  end

end


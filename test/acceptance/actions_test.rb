require_relative 'acceptance_helper'

class ActionsTest < Test::Unit::TestCase
  include AcceptanceHelper

  def test_transcoder_save
    txcoder = create(:transcoder)
    txcoder.expects(:save_config).once.returns(true)
    Transcoder.expects(:[]).with(txcoder.id).returns(txcoder)
    get "/transcoders/#{txcoder.id}/save"
    assert_successful last_response
  end

  def test_transcoder_restart
    txcoder = create(:transcoder)
    txcoder.expects(:restart).once.returns(true)
    Transcoder.expects(:[]).with(txcoder.id).returns(txcoder)
    get "/transcoders/#{txcoder.id}/restart"
    assert_successful last_response
  end

  def test_transcoder_sync
    txcoder = create(:transcoder)
    txcoder.expects(:sync).once.returns(true)
    Transcoder.expects(:[]).with(txcoder.id).returns(txcoder)
    get "/transcoders/#{txcoder.id}/sync"
    assert_successful last_response
  end

  def test_transcoder_status
    txcoder = create(:transcoder)
    get "/transcoders/#{txcoder.id}/status"
    resp = last_response
    assert_equal 302, resp.status
    assert_not_nil resp.header['Location']
    assert_equal resp.header['Location'], "http://#{txcoder.host}:#{txcoder.status_port}"
  end

  def test_slot_start
    #TODO implement testing for actions routes !
    assert_true false
  end

  def test_slot_stop
    assert_true false
  end
end
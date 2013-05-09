require 'test/unit'
require 'mocha/setup'
require 'socket'
require_relative '../../lib/transcoder_api'

class TestTranscoderApi < Test::Unit::TestCase

  def self.startup
    puts name
  end

  def setup
    puts method_name
  end

  def test_initialize
    api = TranscoderApi.new host: 'host', port: 1
    assert_equal 'host', api.host
    assert_equal 1, api.port
    assert_nil api.debug
  end

  def test_mod_get_slots_no_slots
    api, socket = mock_api(TranscoderApi::MOD_GET_SLOTS, 'C')
    expect_ok(socket, [TranscoderApi::RET_OK, 0], 'CC')

    resp = api.mod_get_slots
    assert_not_nil resp
    assert_equal TranscoderApi::RET_OK, resp[:error]
    assert_equal 0, resp[:result][:slots_cnt]
    assert_empty resp[:result][:slots_ids]
  end



  private

  def mock_api(*command, pack_mask)
    api = TranscoderApi.new host: 'host', port: 1

    socket = mock()
    TCPSocket.stubs(:open).returns(socket)
    socket.expects(:send).with(command.flatten.pack(pack_mask), 0)

    return api, socket
  end

  def expect_ok(socket, res, pack_mask)
    socket.expects(:recv).with(TranscoderApi::SOCKET_BLOCK).returns(res.pack(pack_mask))
    socket.expects(:close).once
  end

end

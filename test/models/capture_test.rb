require_relative '../test_helper'

class TestCapture < Test::Unit::TestCase
  include TestHelper

  def test_capture_valid
    assert_invalid Capture.new, :name, :not_present
    assert_invalid Capture.new(name:'cap1'), :host, :not_present
    assert_invalid Capture.new(name:'cap1', host:'host'), :host, :not_valid_ipv4
    assert_invalid Capture.new(name:'cap1', host:'0.0.0.0', input1:99999), :input1, :not_in_range
    assert_true Capture.new(name:'cap1', host:'0.0.0.0').valid?
    assert_true Capture.new(name:'cap1', host:'0.0.0.0',
                            input1: 3000, input2: 3001,
                            input3: 3002, input4: 3003,).valid?
  end

  def test_capture_port
    capture = Capture.create(name:'c', host:'0.0.0.0')
    (1..4).each { |input| assert_equal 0, capture.port(input) }
    capture.input1 = 10
    assert_equal 10, capture.port(1)
  end

  def test_capture_input
    capture = Capture.create(name:'c', host:'0.0.0.0')
    assert_nil capture.input(1111)

    capture.input1=11
    capture.input2=22
    capture.input3=33
    capture.input4=44

    assert_equal 1, capture.input(11)
    assert_equal 2, capture.input(22)
    assert_equal 3, capture.input(33)
    assert_equal 4, capture.input(44)
  end

  def test_capture_free_input?
    capture = Capture.new
    assert_true capture.free_input?
    capture.input1=1
    assert_true capture.free_input?
    capture.input2=1
    assert_true capture.free_input?
    capture.input3=1
    assert_true capture.free_input?
    capture.input4=1
    assert_false capture.free_input?

    capture.input3=0
    assert_true capture.free_input?
  end

  def test_capture_add_port
    capture = Capture.new
    capture.add_port 1
    assert_equal 1, capture.input1
    capture.add_port 2
    assert_equal 2, capture.input2
    assert_equal 1, capture.input1
    capture.add_port 3
    assert_equal 3, capture.input3
    assert_equal 2, capture.input2
    assert_equal 1, capture.input1
    capture.add_port 4
    assert_equal 4, capture.input4
    assert_equal 3, capture.input3
    assert_equal 2, capture.input2
    assert_equal 1, capture.input1
  end

  def test_capture_add_port_errors
    capture = Capture.new(input1:1, input2:2, input3:3, input4:4)
    assert_raise_message('invalid port') { capture.add_port 0 }
    assert_raise_message('invalid port') { capture.add_port 65366 }
    assert_raise_message('capture is full') { capture.add_port 1111 }
  end

  def test_capture_port_mapped?
    capture = Capture.new(input1:1, input2:2, input3:3, input4:4)
    (1..4).each { |port| assert_true capture.port_mapped? port }
    assert_false capture.port_mapped? 5
  end

  def test_self_match
    c1, c2 = *create_list(:capture, 2)

    assert_equal c1, Capture.match(c1.host, c1.input1)
    assert_equal c1, Capture.match(c1.host, c1.input2)
    assert_equal c1, Capture.match(c1.host, c1.input3)
    assert_equal c1, Capture.match(c1.host, c1.input4)
    assert_equal c2, Capture.match(c2.host, c2.input1)
    assert_equal c2, Capture.match(c2.host, c2.input2)
    assert_equal c2, Capture.match(c2.host, c2.input3)
    assert_equal c2, Capture.match(c2.host, c2.input4)

    assert_nil Capture.match('host', 1111)
  end

  def test_self_match_or_create
    c1, c2 = *create_list(:capture, 2)

    assert_equal c1, Capture.match_or_create(c1.host, c1.input1)
    c1.update(input4:0)
    c = Capture.match_or_create(c1.host, 4)
    assert_equal c1, c
    assert_equal 4, c.input4

    c = Capture.match_or_create('192.168.4.4', 1111)
    assert_false [c1,c2].include? c
    assert_not_nil c.name
    assert_equal '192.168.4.4', c.host
    assert_equal 1111, c.input1

  end

  def test_self_create_from_hash
    capture = create(:capture)
    other = Capture.create_from_hash(capture.to_hash)
    assert_equal capture.to_hash, other.to_hash
  end

  private

  def assert_invalid(model, att, err)
    assert_false model.valid?
    assert_not_empty model.errors
    assert_equal err, model.errors[att][0]
  end

end


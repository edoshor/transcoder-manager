require 'ohm'
require 'ohm/datatypes'
require 'resolv'

class Capture < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  attribute :host
  attribute :input1, Type::Integer
  attribute :input2, Type::Integer
  attribute :input3, Type::Integer
  attribute :input4, Type::Integer

  unique :name
  index :host

  def validate
    assert_present :name
    assert_present :host
    assert_format :host, Resolv::IPv4::Regex, [:host, :not_valid_ipv4]
    (1..4).each { |i| validate_port "input#{i}".to_sym }
  end

  def validate_port(port)
    assert_numeric port
    assert send(port).to_i.between?(0, 65365), [port, :not_in_range]
  end

  def to_hash
    super.merge(
        name: name,
        host: host,
        input1: input1,
        input2: input2,
        input3: input3,
        input4: input4
    )
  end

  def to_s
    "Capture: name=#{name}, host=#{host}"
  end

  def port(input_number)
    send("input#{input_number}")
  end

  def input(port)
    (1..4).detect { |input| port(input) == port}
  end

  def free_input?
    port_mapped? 0
  end

  def port_mapped?(port)
    (1..4).any? { |input| port(input) == port}
  end

  def add_port(port)
    raise 'invalid port' unless port.between?(1,65365)
    raise 'capture is full' unless free_input?

    if input1 == 0
      update(input1: port)
    elsif input2 == 0
      update(input2: port)
    elsif input3 == 0
      update(input3: port)
    elsif input4 == 0
      update(input4: port)
    end
  end

  def self.match(host, port)
    find(host: host).detect { |c| c.port_mapped? port }
  end

  # Look for a capture at the given host with some input mapped to the given port.
  # Create a new host if none was found, map port to input1.
  # Or maps port to first empty input.
  # If no empty input, create a new Capture.
  def self.match_or_create(host, port)
    capture = match(host, port)
    return capture if capture

    capture = find(host: host).detect { |c| c.free_input?}
    capture.add_port(port) and return capture if capture

    capture = create_unknown(host)
    capture.add_port(port) and return capture
  end

  def self.create_from_hash(atts)
    Capture.create(atts)
  end

  def self.params_to_attributes(params)
    atts = HashWithIndifferentAccess.new
    %w(name host input1 input2 input3 input4).each{ |k| atts[k] = params[k] if params.key?(k) }
    %w(name host).each { |k| raise ArgumentError.new("expecting #{k}") unless atts.key? k}
    atts
  end

  def self.from_params(params)
    Capture.new(Capture.params_to_attributes(params))
  end

  private

  def self.create_unknown(host)
    Capture.create(name: "unknown_capture_#{SecureRandom.hex(2)}", host: host)
  end

end
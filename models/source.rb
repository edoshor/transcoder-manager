class Source < BaseModel

  attribute :name
  reference :capture, :Capture
  attribute :input, Type::Integer
  unique :name
  index :input

  required_params %w(name capture_id input)

  def validate
    assert_present :name
    assert_present :capture
    assert_numeric :input
    assert input.to_i.between?(1, 4), [:input, :not_in_range]
  end

  def to_hash
    super.merge(name: name,
                capture_id: capture.id,
                capture_name: capture.name,
                input: input)
  end

  def to_s
    "Source: name=#{name}, capture=#{capture.name}, input=#{input}"
  end

  def host
    capture.host
  end

  def port
    capture.port(input)
  end

  def self.match_or_create(host, port)
    capture = Capture.match_or_create(host, port)
    input = capture.input(port)
    source = find(capture_id: capture.id, input: input).first
    source ? source : create(name: "unknown_source_#{SecureRandom.hex(2)}", capture: capture, input: input)
  end

  def self.create_from_hash(atts)
    atts.delete(:capture_name)
    atts[:capture] = Capture[atts.delete(:capture_id)]
    create(atts)
  end

  def self.params_to_attributes(params)
    super(params) do |atts|
      atts[:capture] = Capture[atts.delete(:capture_id)]
    end
  end

end
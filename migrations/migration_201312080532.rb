require_relative '../models/init'
require 'redis'
require 'json'
require 'ohm'
require 'ohm/datatypes'

puts 'migrating redis data...'

redis_url = ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
Ohm.connect url: redis_url, driver: :hiredis
puts 'redis is ready.' if 'PONG' == Ohm.redis.ping

module Migration

  class Source < Ohm::Model
    include Ohm::DataTypes

    attribute :name
    attribute :host
    attribute :port, Type::Integer

    unique :name
    index :host
    index :port

    def to_s
      "Migration::Source: name=#{name}, host=#{host}, port=#{port}"
    end
  end

end

puts 'renaming sources keys'
Ohm.redis.keys('Source*').each do |k|
  Ohm.redis.rename k, "Migration::#{k}"
end

puts 'creating captures and new sources'
sources = Migration::Source.all.to_a
sources.sort_by! { |s| "#{s.host}:#{s.port}" }
sources.each do |s|
  c = Capture.match_or_create(s.host, s.port)
  new_source = Source.create(name: s.name, capture: c, input: c.input(s.port))
  Scheme.find(src1_id: s.id).each { |scheme| scheme.update(src1: new_source) }
  Scheme.find(src2_id: s.id).each { |scheme| scheme.update(src2: new_source) }
end

puts 'deleting migration keys'
Ohm.redis.del Ohm.redis.keys('Migration*')
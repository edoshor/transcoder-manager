require_relative '../models/init'
require 'redis'
require 'ohm'


redis_url = ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
Ohm.connect url: redis_url
Ohm.redis.ping

Ohm.flush

# transcoders
Transcoder.create(name: 'local-mock', host:'127.0.0.1')
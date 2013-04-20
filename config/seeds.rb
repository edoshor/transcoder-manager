require_relative '../models/init'
require 'redis'
require 'ohm'


redis_url = ENV['REDIS_URL'] || 'redis://127.0.0.1/0'
Ohm.connect url: redis_url
Ohm.redis.ping

Ohm.flush

# helper methods

def create_preset(name, tracks)
  preset = Preset.create(name: name)
  tracks.each do |t|
    preset.tracks.push Track.create(profile_number: t, num_channels: t <= 100 ? 0 : 2, gain: t <= 100 ? 0 : 10)
  end
  preset
end

# create configuration

# Sources
sources = [
Source.create(name: 'tv66', host: '192.168.1.2', port: 3000),
Source.create(name: 'tvrus', host: '192.168.1.2', port: 3001),
Source.create(name: 'live1', host: '192.168.1.2', port: 3002),
Source.create(name: 'live2', host: '192.168.1.2', port: 3003)
]

# Presets
presets = [
create_preset('preset1', [1, 101]),
create_preset('preset2', [2, 102]),
create_preset('preset3', [3, 102]),
create_preset('preset4', [4, 103]),
create_preset('tv66', [1, 101, 2, 3, 102, 101, 102]),
create_preset('tvrus', [1, 101, 2, 3, 102]),
create_preset('live1', [1, 101, 2, 3, 102, 101, 102, 101, 102, 101, 102, 101, 102, 101, 102, 101, 102]),
create_preset('live2', [1, 101, 2, 3, 102, 101, 102, 101, 102, 101, 102, 101, 102, 101, 102])
]

# Schemes
Scheme.create(name: 'tv66',
              src1: sources[0],
              src2: sources[0],
              preset: presets[4],
              audio_mappings: %w(0 1 0 0 1 2 2))

# transcoders
Transcoder.create(name: 'transcoder1', host: '10.65.6.101')
Transcoder.create(name: 'transcoder2', host: '10.65.6.102')
Transcoder.create(name: 'transcoder3', host: '10.65.6.103')
Transcoder.create(name: 'transcoder4', host: '10.65.6.104')
require 'redis'
require 'benchmark'

# initialize connection to redis
$redis = Redis.new(url: (ENV['REDIS_URL'] || 'redis://127.0.0.1/3'))
puts $redis.ping

$redis.flushdb

puts 'create initial data'
t = (Time.now.to_f * 1000.0).to_i
$redis.pipelined do
  (6 * 60 * 24 * 7).times do
    t = t - 10 * 1000
    key = "t:1:load_status:#{t}"
    cpuload = rand() * 100
    $redis.zadd 't:1:load_status', t, "#{t},#{cpuload}"
  end
end


puts 'benchmark data'
puts Benchmark.measure('last_24_hours') do
  now = (Time.now.to_f * 1000.0).to_i
  last_day = now - 24 * 60 * 60 * 1000
  data = $redis.zrevrangebyscore 't:1:load_status', now, last_day
  puts data.length
end





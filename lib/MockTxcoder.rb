require 'socket'
require 'thread'
require 'json'


t1 = Thread.new do
  server = TCPServer.open(10000)
  loop do
    client = server.accept
    puts "#{Time.now}: serving client from #{client.peeraddr}"
    client.puts(Time.now.ctime)
    client.puts 'Closing the connection. Bye!'
    client.close
  end
end

t2 = Thread.new do
  server = TCPServer.open(11000)
  loop do
    client = server.accept
    puts "#{Time.now}: serving load status for client from #{client.peeraddr}"

    result = JSON.generate({ cpuload: sprintf('%2.2f %', rand * 100),
        cputemp: [{:'0' => sprintf('%2.2f C', rand * 100)},
                  {:'1' => sprintf('%2.2f C', rand * 100)}]})

    headers = [
        'HTTP/1.1 200 OK',
        "Date: #{Time.now}",
        'Server: Mock Transcoder',
        'Content-Type: application/json; charset=iso-8859-1',
        "Content-Length: #{result.length}\r\n\r\n"].join("\r\n")
    client.puts headers
    client.puts result
    client.close
  end
end

puts 'Mock transcoder is running.'

t1.join
t2.join
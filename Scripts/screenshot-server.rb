#!/usr/bin/env ruby
# frozen_string_literal: true

# Stands in for the yadosearch-api proxy while the screenshots are taken.
#
#   Scripts/screenshot-server.rb --port 8099
#
# The App Store shots have to come out the same on every run, in both
# languages, on three devices — and the real proxy cannot promise that. Prices
# move, 楽天 rate-limits, and a search run twice can return the inns in a
# different order. So the app is pointed at this instead, with `-APIHost
# localhost:<port>`, and it answers from the same fixtures the decoding tests
# read: the proxy's own committed examples.
#
# Written against the socket library rather than a web framework so that the
# capture run needs nothing installed. It speaks exactly as much HTTP as
# URLSession asks of it.

require 'json'
require 'socket'
require 'uri'

port = 8099
fixtures = File.expand_path('../Tests/YadoSearchCoreTests/Fixtures/api', __dir__)
until ARGV.empty?
  case ARGV.shift
  when '--port' then port = Integer(ARGV.shift)
  when '--fixtures' then fixtures = File.expand_path(ARGV.shift)
  end
end

FIXTURES = fixtures

def fixture(name)
  File.read(File.join(FIXTURES, "#{name}.json"))
end

# Which fixture answers which request. The paths are the proxy's, and the
# fixtures line up with each other on purpose: the first row of the keyword
# search is 東京ステーションホテル, and so is the inn behind the detail and the
# plans, so the shots tell one story rather than three.
def body_for(path, query)
  case path
  when '/v1/hotels'
    query.key?('latitude') ? fixture('hotels_by_coordinate') : fixture('hotels_by_keyword')
  when '/v1/areas/jalan'
    fixture('areas_jalan_full')
  when '/v1/areas/rakuten'
    fixture('areas_rakuten_full')
  when %r{\A/v1/hotels/(jalan|rakuten)/[^/]+/plans\z}
    fixture(Regexp.last_match(1) == 'rakuten' ? 'plans_rakuten' : 'plans_jalan')
  when %r{\A/v1/hotels/(jalan|rakuten)/[^/]+\z}
    fixture('hotel_jalan')
  end
end

def handle(request_line)
  method, target, = request_line.split
  return [405, { error: 'method not allowed' }.to_json] unless method == 'GET'

  uri = URI.parse(target)
  query = URI.decode_www_form(uri.query.to_s).to_h
  body = body_for(uri.path, query)
  body ? [200, body] : [404, { error: "no fixture for #{uri.path}" }.to_json]
end

server = TCPServer.new('127.0.0.1', port)
warn "screenshot-server: listening on http://127.0.0.1:#{port} (fixtures: #{FIXTURES})"
$stderr.flush

loop do
  Thread.start(server.accept) do |socket|
    request_line = socket.gets
    next socket.close if request_line.nil?

    # Drain the headers. Nothing here reads them, but leaving them unread makes
    # the client see the response before its own request finished sending.
    while (line = socket.gets)
      break if line == "\r\n" || line == "\n"
    end

    status, body = handle(request_line)
    socket.print("HTTP/1.1 #{status} #{status == 200 ? 'OK' : 'Error'}\r\n")
    socket.print("Content-Type: application/json; charset=utf-8\r\n")
    socket.print("Content-Length: #{body.bytesize}\r\n")
    socket.print("Connection: close\r\n\r\n")
    socket.print(body)
  rescue StandardError => e
    warn "screenshot-server: #{e.class}: #{e.message}"
  ensure
    socket.close
  end
end

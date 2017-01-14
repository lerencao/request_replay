#!/usr/bin/env ruby
# encoding: utf-8

require './handler'
raise 'no output dir' unless ARGV[0]

out_dir = ARGV[0]
log_level = ARGV[1] || :info

message_handler = MessageHandler.new(out_dir, log_level)

while data = STDIN.gets # continiously read line from STDIN
  next unless data

  data = data.chomp

  decoded = [data].pack("H*") # decode base64 encoded request

  header, http_data = decoded.split("\n", 2)

  message_handler.on_message(http_data, header)

  # dedoded value is raw HTTP payload, example:
  #
  #   POST /post HTTP/1.1
  #   Content-Length: 7
  #   Host: www.w3.org
  #
  #   a=1&b=2"
  payload_type, _request_id, _timestamp, _latency = header.split(' ')
  if payload_type.to_i == 1
    # Emit request back
    encoded = decoded.unpack("H*").first # encoding back to base64
    STDOUT.puts encoded
  end
end



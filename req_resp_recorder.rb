#!/usr/bin/env ruby
# encoding: utf-8
require 'dotenv'
Dotenv.load

require './handler'

log_path = 'tmp.log'
log_level = :info

require 'mongo'

Mongo::Logger.level = Logger::ERROR

raise 'MONGO_URL environment variable is not set' unless ENV['MONGO_URL']
mongo = Mongo::Client::new(ENV['MONGO_URL'])

message_handler = MessageHandler.new(mongo, log_path, log_level)

while data = STDIN.gets # continiously read line from STDIN
  next unless data

  data = data.chomp

  decoded = [data].pack('H*') # decode base64 encoded request

  if decoded.nil?
    exit
  end

  header, http_data = decoded.split("\n", 2)

  if header.nil?
    exit
  end

  message_handler.on_message(http_data, header)

  # dedoded value is raw HTTP payload, example:
  #
  #   POST /post HTTP/1.1
  #   Content-Length: 7
  #   Host: www.w3.org
  #
  #   a=1&b=2"

  # Emit request back
  encoded = decoded.unpack('H*').first # encoding back to base64
  STDOUT.puts encoded
end



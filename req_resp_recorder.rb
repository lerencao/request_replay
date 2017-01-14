#!/usr/bin/env ruby
# encoding: utf-8
require 'http-parser-lite'

@parser = HTTP::Parser.new

require 'tempfile'
tmp = File.open("/tmp/tmp.txt", 'w+')
tmp.sync = true

@parser.on_message_begin do
  tmp.puts "message begin: #{Time.now.to_f}"
end
@parser.on_message_complete do
  tmp.puts "message complete, #{Time.now.to_f}"
end


@results = {}

@current_request_id, @url, @body = nil


@parser.on_url do |url|
  @url = url
end

@parser.on_body do |body|
  @body = body
end

def format_req_resp(request_id, v)
  origin_request = v[:origin_request]
  origin_response = v[:origin_response]
  replayed_response = v[:replayed_response]

  if origin_request
    method, url = origin_request[:method], origin_request[:url]
  end
  if origin_response
    origin_resp_status,
    origin_resp_body = origin_response[:status], origin_response[:body]
  end

  if replayed_response
    replayed_resp_status,
    replayed_resp_body = replayed_response[:status], replayed_response[:body]
  end

  "#{request_id}, #{url}, #{method}, #{origin_resp_status}, #{replayed_resp_status}, #{origin_resp_body}, #{replayed_resp_body}"
end

@f = File.open('comparision.txt', 'w')

while data = STDIN.gets # continiously read line from STDIN
  next unless data

  data = data.chomp # remove end of line symbol

  decoded = [data].pack("H*") # decode base64 encoded request

  header, http_data = decoded.split("\n", 2)
  payload_type, @current_request_id, _timestamp, _ = header.split(" ")

  _ = @parser.parse http_data

  @results[@current_request_id] ||= {}
  tmp.puts "#{Time.now.to_f}, #{@results[@current_request_id]}"
  case payload_type.to_i
  when 1 # request
    @results[@current_request_id][:origin_request] = {
      method: @parser.http_method,
      url: @url
    }
  when 2 # origin response
    @results[@current_request_id][:origin_response] = {
      status: @parser.http_status,
      body: @body
    }
  when 3 # replayed response
    @results[@current_request_id][:replayed_response] = {
      status: @parser.http_status,
      body: @body
    }
  end

  if @results[@current_request_id].size == 2
    @f.puts format_req_resp(@current_request_id, @results[@current_request_id])
    @f.flush
  end

  @current_request_id, @url, @body = nil
  @parser.reset


  # dedoded value is raw HTTP payload, example:
  #
  #   POST /post HTTP/1.1
  #   Content-Length: 7
  #   Host: www.w3.org
  #
  #   a=1&b=2"

  if payload_type.to_i == 1
    # Emit request back
    encoded = decoded.unpack("H*").first # encoding back to base64
    STDOUT.puts encoded
  end
end



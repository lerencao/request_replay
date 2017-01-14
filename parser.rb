require 'http-parser-lite'

def http_parse(http_data, type = :request)

  parser = HTTP::Parser.new(
    type == :request ? HTTP::Parser::TYPE_REQUEST : HTTP::Parser::TYPE_RESPONSE
  )

  request_url, request_method, response_status, response_body = nil


  # parser.on_message_begin do
  #   puts "message begin"
  # end

  # parser.on_message_complete do
  #   puts "message complete"
  # end

  parser.on_status_complete do
    response_status = parser.http_status
  end

  parser.on_headers_complete do
  end

  parser.on_url do |url|
    request_url = url
  end

  headers = []
  parser.on_header_field do |name|
    headers << name
  end

  parser.on_header_value do |value|
    headers << value
  end

  parser.on_body do |body|
    response_body = body
  end

  parser.parse http_data

  request_method = parser.http_method

  headers = headers.each_slice(2).to_h
  case type
  when :request
    # require 'pry'
    # binding.pry
    return {
      request_url: request_url,
      request_method: request_method,
      headers: headers
    }
  when :response
    return {
      response_status: response_status,
      response_body: response_body,
      headers: headers
    }
  else
    raise "invalid http message type #{type}"
  end
end

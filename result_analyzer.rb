require 'logging'
require 'json'
raise 'no input_dir' unless ARGV[0]

input_dir = ARGV[0]

@origin_requests, @origin_responses, @replayed_respones = [
  'origin_requests',
  'origin_responses',
  'replayed_responses'
].map do |kind|
  Dir[File.join(input_dir, kind, '*')]
end.map do |path|
  path.map do |f|
    request_id = f.split('/').last
    [request_id, JSON.parse(File.read(f))]
  end.to_h
end

@logger = Logging.logger(STDOUT)

left_behind = @origin_requests.keys - @replayed_respones.keys

@logger.info("#{left_behind.size} request left behind\n" + left_behind.join("\n") + "\n")

@replayed_respones.each_with_index do |kv, index|
  request_id, resp = kv
  url = @origin_requests[request_id]['request_url']

  origin_response = @origin_responses[request_id]
  if origin_response.nil?
    @logger.warn("#{request_id} not exists in origin_response\n")
    next
  end

  origin_status = origin_response['response_status']
  replayed_status = resp['response_status']

  origin_body = origin_response['response_body']
  replayed_body = resp['response_body']
  if replayed_status != origin_status
    @logger.warn "#{request_id}, #{url}, #{origin_status}, #{replayed_status}"
    @logger.info("#{request_id}, origin_body: #{origin_body}")
    @logger.info("#{request_id}, replayed_body: #{replayed_body}\n")
  else
    # @logger.info("#{request_id}, normal")
  end
end

@logger.info("Response total number: #{@replayed_respones.size}")

info_api_num = @replayed_respones.keys.count do |request_id|
  url = @origin_requests[request_id]['request_url']
  url =~ %r{/info/api}
end

@logger.info("Response total number of (info/api): #{info_api_num}")

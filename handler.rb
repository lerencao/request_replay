require 'fileutils'
require 'logging'
require 'json'
require 'divergent'

require_relative './parser'

class MessageHandler
  def initialize(output_dir, log_level = :info)
    FileUtils.mkdir_p output_dir
    @output_dir = output_dir
    @origin_requests, @origin_responses, @replayed_respones = [
      'origin_requests',
      'origin_responses',
      'replayed_responses'
    ].map do |kind|
      fp = File.join(@output_dir, kind)
      File.new(fp, 'w')
    end

    @logger = Logging.logger[self]
    @logger.level = log_level
    log_path = File.join(@output_dir, '.log')
    @logger.add_appenders Logging.appenders.file(log_path)
  end

  def on_message(http_data, header)
    payload_type, request_id, timestamp, latency = header.split(' ')
    payload_type = payload_type.to_i
    timestamp = timestamp.to_i / 1_000_000_000.0
    latency = latency.to_i / 1_000_000_000.0 if latency

    @logger.info("Receive message #{payload_type}, #{request_id}, #{Time.at timestamp}")

    _ = Divergent.Try {
      http_parse(http_data, payload_type == 1 ? :request : :response)
    }.map do |parsed_data|
      extra_info = {
        request_id: request_id,
        timestamp: Time.at(timestamp)
      }
      extra_info[:latency] = latency if latency

      @logger.debug('prepare json data')
      replace_invalid_string(parsed_data.merge(extra_info)).to_json
    end.map do |json_data|
      @logger.debug("start to write result")
      save_file = get_save_file(payload_type)
      save_file.puts(json_data)

      @logger.info("Handle message done: #{request_id}")
      :ok
    end.recover_with do |e|
      @logger.error("failed to handle message #{request_id}, #{e.class}, #{e.message}")
      Divergent.Try { raise e }
    end
  end

  private

  def get_save_file(payload_type)
    selected = case payload_type.to_i
    when 1
      @origin_requests
    when 2
      @origin_responses
    when 3
      @replayed_respones
    end
    if rand > 0.5
      selected.flush
    end
    selected
  end

  def replace_invalid_string(obj)
    case obj
    when Hash
      obj.inject({}) do |memo, (k, v)|
        memo[k] = replace_invalid_string(v)
        memo
      end
    when Array
      obj.map do |v|
        replace_invalid_string(v)
      end
    when String
      obj.encode 'UTF-8', invalid: :replace, undef: :replace
    else
      obj
    end
  end
end

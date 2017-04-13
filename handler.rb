require 'fileutils'
require 'logging'
require 'json'
require 'divergent'


require_relative './parser'

class MessageHandler
  def initialize(mongo, log_path, log_level = :info)
    @collection = mongo['goreplay']
    @collection.indexes.create_one({ 'uuid' => 1 }, unique: true)

    @logger = Logging.logger[self]
    @logger.level = log_level
    @logger.add_appenders Logging.appenders.file(log_path)
  end

  def on_message(http_data, header)
    @logger.info("#{header}")
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

      parsed_data.merge(extra_info)
    end.map do |data|
      field_name = case payload_type.to_i
      when 1
        'origin_request'
      when 2
        'origin_response'
      when 3
        'replayed_response'
      else
        'unknown'
      end

      @collection.update_one(
        { 'uuid' => data[:request_id] },
        { '$set' => { field_name => data } },
        upsert: true
      )

      @logger.info("Handle message done: #{request_id}")
      :ok
    end.recover_with do |e|
      @logger.error("failed to handle message #{request_id}, #{e.class}, #{e.message}")
      Divergent.Try { raise e }
    end
  end

  private

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

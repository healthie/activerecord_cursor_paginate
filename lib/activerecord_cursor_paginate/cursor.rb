# frozen_string_literal: true

require "base64"
require "json"

module ActiveRecordCursorPaginate
  # @private
  class Cursor
    class << self
      def from_record(record, columns:)
        columns = columns.map { |column| column.to_s.split(".").last }
        values = columns.map { |column| record[column] }
        new(columns: columns, values: values)
      end

      def decode(cursor_string:, columns:)
        decoded = JSON.parse(Base64.strict_decode64(cursor_string))

        if (columns.size == 1 && decoded.is_a?(Array)) ||
           (decoded.is_a?(Array) && decoded.size != columns.size)
          raise InvalidCursorError,
                "The given cursor `#{cursor_string}` was decoded as `#{decoded}` but could not be parsed"
        end

        decoded =
          if decoded.is_a?(Array)
            decoded.map { |value| deserialize_time_if_needed(value) }
          else
            deserialize_time_if_needed(decoded)
          end

        new(columns: columns, values: decoded)
      rescue ArgumentError, JSON::ParserError # ArgumentError is raised by strict_decode64
        raise InvalidCursorError, "The given cursor `#{cursor_string}` could not be decoded"
      end

      private
        def deserialize_time_if_needed(value)
          if value.is_a?(String) && value.start_with?(TIMESTAMP_PREFIX)
            seconds_with_frac = value.delete_prefix(TIMESTAMP_PREFIX).to_r / (10**6)
            Time.at(seconds_with_frac).utc
          else
            value
          end
        end
    end

    attr_reader :columns, :values

    def initialize(columns:, values:)
      @columns = Array.wrap(columns)
      @values = Array.wrap(values)

      raise ArgumentError, "Cursor values can not be nil" if @values.any?(nil)
      raise ArgumentError, ":columns and :values have different sizes" if @columns.size != @values.size
    end

    def encode
      serialized_values = values.map do |value|
        if value.is_a?(Time)
          TIMESTAMP_PREFIX + value.strftime("%s%6N")
        else
          value
        end
      end
      unencoded_cursor = (serialized_values.size == 1 ? serialized_values.first : serialized_values)
      Base64.strict_encode64(unencoded_cursor.to_json)
    end

    TIMESTAMP_PREFIX = "0aIX2_" # something random
    private_constant :TIMESTAMP_PREFIX
  end
end

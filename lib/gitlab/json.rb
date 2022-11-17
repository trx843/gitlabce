# frozen_string_literal: true

# This is a GitLab-specific JSON interface. You should use this instead
# of using `JSON` directly. This allows us to swap the adapter and handle
# legacy issues.

module Gitlab
  module Json
    INVALID_LEGACY_TYPES = [String, TrueClass, FalseClass].freeze

    class << self
      # Parse a string and convert it to a Ruby object
      #
      # @param string [String] the JSON string to convert to Ruby objects
      # @param opts [Hash] an options hash in the standard JSON gem format
      # @return [Boolean, String, Array, Hash]
      # @raise [JSON::ParserError] raised if parsing fails
      def parse(string, opts = {})
        # Parse nil as nil
        return if string.nil?

        # First we should ensure this really is a string, not some other
        # type which purports to be a string. This handles some legacy
        # usage of the JSON class.
        string = string.to_s unless string.is_a?(String)

        legacy_mode = legacy_mode_enabled?(opts.delete(:legacy_mode))
        data = adapter_load(string, **opts)

        handle_legacy_mode!(data) if legacy_mode

        data
      end

      alias_method :parse!, :parse
      alias_method :load, :parse
      alias_method :decode, :parse

      # Restricted method for converting a Ruby object to JSON. If you
      # need to pass options to this, you should use `.generate` instead,
      # as the underlying implementation of this varies wildly based on
      # the adapter in use.
      #
      # This method does, in some situations, differ in the data it returns
      # compared to .generate. Counter-intuitively, this is closest in
      # terms of response to JSON.generate and to the default ActiveSupport
      # .to_json method.
      #
      # @param object [Object] the object to convert to JSON
      # @return [String]
      def dump(object)
        adapter_dump(object)
      end

      # Generates JSON for an object. In Oj this takes fewer options than .dump,
      # in the JSON gem this is the only method which takes an options argument.
      #
      # @param object [Hash, Array, Object] must be hash, array, or an object that responds to .to_h or .to_json
      # @param opts [Hash] an options hash with fewer supported settings than .dump
      # @return [String]
      def generate(object, opts = {})
        adapter_generate(object, opts)
      end

      alias_method :encode, :generate

      # Generates JSON for an object and makes it look purdy
      #
      # The Oj variant in this looks seriously weird but these are the settings
      # needed to emulate the style generated by the JSON gem.
      #
      # NOTE: This currently ignores Oj, because Oj doesn't generate identical
      #       formatting, issue: https://github.com/ohler55/oj/issues/608
      #
      # @param object [Hash, Array, Object] must be hash, array, or an object that responds to .to_h or .to_json
      # @param opts [Hash] an options hash with fewer supported settings than .dump
      # @return [String]
      def pretty_generate(object, opts = {})
        ::JSON.pretty_generate(object, opts)
      end

      # The standard parser error we should be returning. Defined in a method
      # so we can potentially override it later.
      #
      # @return [JSON::ParserError]
      def parser_error
        ::JSON::ParserError
      end

      private

      # Convert JSON string into Ruby through toggleable adapters.
      #
      # Must rescue adapter-specific errors and return `parser_error`, and
      # must also standardize the options hash to support each adapter as
      # they all take different options.
      #
      # @param string [String] the JSON string to convert to Ruby objects
      # @param opts [Hash] an options hash in the standard JSON gem format
      # @return [Boolean, String, Array, Hash]
      # @raise [JSON::ParserError]
      def adapter_load(string, *args, **opts)
        opts = standardize_opts(opts)

        Oj.load(string, opts)
      rescue Oj::ParseError, EncodingError, Encoding::UndefinedConversionError => ex
        raise parser_error, ex
      end

      # Take a Ruby object and convert it to a string. This method varies
      # based on the underlying JSON interpreter. Oj treats this like JSON
      # treats `.generate`. JSON.dump takes no options.
      #
      # This supports these options to ensure this difference is recorded here,
      # as it's very surprising. The public interface is more restrictive to
      # prevent adapter-specific options being passed.
      #
      # @overload adapter_dump(object, opts)
      #   @param object [Object] the object to convert to JSON
      #   @param opts [Hash] options as named arguments, only supported by Oj
      #
      # @overload adapter_dump(object, anIO, limit)
      #   @param object [Object] the object, will have JSON.generate called on it
      #   @param anIO [Object] an IO-like object that responds to .write, default nil
      #   @param limit [Fixnum] the nested array/object limit, default nil
      #   @raise [ArgumentError] when depth limit exceeded
      #
      # @return [String]
      def adapter_dump(object, *args, **opts)
        Oj.dump(object, opts)
      end

      # Generates JSON for an object but with fewer options, using toggleable adapters.
      #
      # @param object [Hash, Array, Object] must be hash, array, or an object that responds to .to_h or .to_json
      # @param opts [Hash] an options hash with fewer supported settings than .dump
      # @return [String]
      def adapter_generate(object, opts = {})
        opts = standardize_opts(opts)

        Oj.generate(object, opts)
      end

      # Take a JSON standard options hash and standardize it to work across adapters
      # An example of this is Oj taking :symbol_keys instead of :symbolize_names
      #
      # @param opts [Hash, Nil]
      # @return [Hash]
      def standardize_opts(opts)
        opts ||= {}
        opts[:mode] = :rails
        opts[:symbol_keys] = opts[:symbolize_keys] || opts[:symbolize_names]

        opts
      end

      # @param [Nil, Boolean] an extracted :legacy_mode key from the opts hash
      # @return [Boolean]
      def legacy_mode_enabled?(arg_value)
        arg_value.nil? ? false : arg_value
      end

      # If legacy mode is enabled, we need to raise an error depending on the values
      # provided in the string. This will be deprecated.
      #
      # @param data [Boolean, String, Array, Hash, Object]
      # @return [Boolean, String, Array, Hash, Object]
      # @raise [JSON::ParserError]
      def handle_legacy_mode!(data)
        return data unless Feature.feature_flags_available?
        return data unless Feature.enabled?(:json_wrapper_legacy_mode)

        raise parser_error if INVALID_LEGACY_TYPES.any? { |type| data.is_a?(type) }
      end
    end

    # GrapeFormatter is a JSON formatter for the Grape API.
    # This is set in lib/api/api.rb

    class GrapeFormatter
      # Convert an object to JSON.
      #
      # The `env` param is ignored because it's not needed in either our formatter or Grape's,
      # but it is passed through for consistency.
      #
      # If explicitly supplied with a `PrecompiledJson` instance it will skip conversion
      # and return it directly. This is mostly used in caching.
      #
      # @param object [Object]
      # @return [String]
      def self.call(object, env = nil)
        return object.to_s if object.is_a?(PrecompiledJson)

        Gitlab::Json.dump(object)
      end
    end

    # Wrapper class used to skip JSON dumping on Grape endpoints.

    class PrecompiledJson
      UnsupportedFormatError = Class.new(StandardError)

      # @overload PrecompiledJson.new("foo")
      #   @param value [String]
      #
      # @overload PrecompiledJson.new(["foo", "bar"])
      #   @param value [Array<String>]
      def initialize(value)
        @value = value
      end

      # Convert the value to a String. This will invoke
      # `#to_s` on the members of the value if it's an array.
      #
      # @return [String]
      # @raise [NoMethodError] if the objects in an array doesn't support to_s
      # @raise [PrecompiledJson::UnsupportedFormatError] if the value is neither a String or Array
      def to_s
        return @value if @value.is_a?(String)
        return "[#{@value.join(',')}]" if @value.is_a?(Array)

        raise UnsupportedFormatError
      end

      def render_in(_view_context)
        to_s
      end

      def format
        :json
      end
    end

    class LimitedEncoder
      LimitExceeded = Class.new(StandardError)

      # Generates JSON for an object or raise an error if the resulting json string is too big
      #
      # @param object [Hash, Array, Object] must be hash, array, or an object that responds to .to_h or .to_json
      # @param limit [Integer] max size of the resulting json string
      # @return [String]
      # @raise [LimitExceeded] if the resulting json string is bigger than the specified limit
      def self.encode(object, limit: 25.megabytes)
        buffer = StringIO.new
        buffer_size = 0

        ::Yajl::Encoder.encode(object) do |data_chunk|
          chunk_size = data_chunk.bytesize

          raise LimitExceeded if buffer_size + chunk_size > limit

          buffer << data_chunk
          buffer_size += chunk_size
        end

        buffer.string
      end
    end

    class RailsEncoder < ActiveSupport::JSON::Encoding::JSONGemEncoder
      # Rails doesn't provide a way of changing the JSON adapter for
      # render calls in controllers, so here we're overriding the parent
      # class method to use our generator, and it's monkey-patched in
      # config/initializers/active_support_json.rb
      def stringify(jsonified)
        Gitlab::Json.dump(jsonified)
      rescue EncodingError => ex
        # Raise the same error as the default implementation if we encounter
        # an error. These are usually related to invalid UTF-8 errors.
        raise JSON::GeneratorError, ex
      end
    end
  end
end

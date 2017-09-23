require 'enjoy/parts/params'

module Enjoy
  module Parts
    class Validator
      attr_accessor :errors
      attr_reader :params_wrapper
      private :errors, :params_wrapper

      def initialize(params_wrapper = ::Enjoy::Parts::Params.new)
        @params_wrapper = params_wrapper
      end

      def self.build(&block)
        self.new.build(&block)
      end

      def build(&block)
        instance_eval(&block)
        self
      end

      def requires(name, options = {})
        options[:required] = true
        define_rule(name, options)
      end

      def optional(name, options = {})
        options[:required] = false
        define_rule(name, options)
      end

      def allow_undefined_params=(allow)
        @allow_undefined_params = allow
      end

      def undefined_params(params)
        self.allow_undefined_params = true
        params.reject { |name, value| rules[name] }
      end

      def validate(params)
        self.errors = []
        validate_undefined(params) unless allow_undefined_params?
        validate_required(params)
        params.each do |name, value|
          validate_types(name, value)
          validate_allowed(name, value)
        end
        errors
      end

      def default_params
        rules
          .select {|_, value| value.keys.include?("default") }
          .inject({}) {|memo, (k,v)| memo[k] = v[:default]; memo}
      end

      private

      def defined_params(params)
        params.select { |name| rules.keys.include?(name) }
      end

      def allow_undefined_params?
        !!@allow_undefined_params
      end

      def rules
        @rules ||= { children: { required: false } }
      end

      def define_rule(name, options = {})
        rules[name] = options
        ::Enjoy::Parts::Params.define_param(name, options)
      end

      def errors
        @errors ||= []
      end

      def validate_types(param_name, value)
        return unless klass = rules[param_name][:type]
        if !klass.is_a?(Array)
          allow_nil = !!rules[param_name][:allow_nil]
          type_check("`#{param_name}`", value, klass, allow_nil)
        elsif klass.length > 0
          validate_value_array(param_name, value)
        else
          allow_nil = !!rules[param_name][:allow_nil]
          type_check("`#{param_name}`", value, Array, allow_nil)
        end
      end

      def type_check(param_name, value, klass, allow_nil)
        return if allow_nil && value.nil?
        return if value.is_a?(klass)
        errors << "Provided param #{param_name} could not be converted to #{klass}"
      end

      def validate_allowed(param_name, value)
        return unless values = rules[param_name][:values]
        return if values.include?(value)
        errors << "Value `#{value}` for param `#{param_name}` is not an allowed value"
      end

      def validate_required(params)
        (rules.keys - params.keys).each do |name|
          next unless rules[name][:required]
          errors << "Required param `#{name}` was not specified"
        end
      end

      def validate_undefined(params)
        (params.keys - rules.keys).each do |param_name|
          errors <<  "Provided param `#{param_name}` not specified in spec"
        end
      end

      def validate_value_array(name, value)
        klass = rules[name][:type]
        allow_nil = !!rules[name][:allow_nil]
        value.each_with_index do |item, index|
          type_check("`#{name}`[#{index}]", item, klass[0], allow_nil)
        end
      rescue NoMethodError
        errors << "Provided param `#{name}` was not an Array"
      end

      def coerce_native_hash_values(hash)
        hash.each do |key, value|
          hash[key] = value
        end
      end
    end
  end
end

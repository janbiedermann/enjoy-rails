require 'enjoy/parts/observable'

module Enjoy
  module Parts
    class Params

      def self.define_param(name, options, default_value_given = false, default_value = nil)
        param_type = options[:type]
        if param_type == ::Enjoy::Parts::Observable
          define_method("#{name}") do
            value_for(name)
          end
          define_method("#{name}!") do |*args|
            current_value = value_for(name)
            if args.count > 0
              @params[name].call args[0]
              current_value
            else
              @params[name]
            end
          end
        elsif param_type == Proc
          define_method("#{name}") do |*args, &block|
            @params[name].call(*args, &block) if @params[name]
          end
        else
          if options.has_key?(:default)
            default_value = options[:default]
            define_method("#{name}") do
              @params.has_key?(name) ? @params[name] : default_value
            end
          else
            define_method("#{name}") do
              @params[name]
            end
          end
        end
      end

      def initialize
        @params = {}
      end

      def [](prop)
        @params[prop]
      end

      private

      def value_for(name)
        self[name].instance_variable_get("@value") if self[name]
      end
    end
  end
end

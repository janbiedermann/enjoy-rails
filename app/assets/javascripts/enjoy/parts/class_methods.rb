require 'enjoy/parts/params'
require 'enjoy/parts/v_node'
require 'enjoy/parts/validator'

module Enjoy
  module Parts
    # class level methods (macros) for components
    module ClassMethods
      def backtrace(*args)
        @dont_catch_exceptions = (args[0] == :none)
        @backtrace_off = @dont_catch_exceptions || (args[0] == :off)
      end

      def process_exception(e, component, reraise = @dont_catch_exceptions)
        unless @dont_catch_exceptions
          message = ["Exception raised while rendering #{component}: #{e.message}"]
          if e.backtrace && e.backtrace.length > 1 && !@backtrace_off
            append_backtrace(message, e.backtrace)
          end
          `console.error(#{message.join("\n")})`
        end
        raise e if reraise
      end

      def append_backtrace(message_array, backtrace)
        message_array << "    #{backtrace[0]}"
        backtrace[1..-1].each { |line| message_array << line }
      end

      def render(tag, *params, &block)
        if tag
          define_method(:render) do
            self.node_name = tag
            internal_render(*params, &block)
          end
        else
          define_method(:render) do
            internal_render(*params, &block)
          end
        end
      end

      # method missing will assume the method is a class name, and will treat this a render of
      # of the component, i.e. Foo::Bar.baz === Foo::Bar().baz

      # def method_missing(name, *args, &block)
      #   component_class = find_component(name)
      #   return component_class.new('div', nil, nil).render if component_class
      #   VNode.new(name, nil, nil, *args, &block)
      #   # Object.method_missing(name, *args, &block)
      # end

      private

      # def find_component(name)
      #   component = lookup_const(name)
      #   if component && !component.method_defined?(:render)
      #     raise "#{name} does not appear to be a component."
      #   end
      #   component
      # end
      #
      # def lookup_const(name)
      #   return nil unless name =~ /^[A-Z]/
      #   scopes = self.class.name.to_s.split('::').inject([Module]) do |nesting, next_const|
      #     nesting + [nesting.last.const_get(next_const)]
      #   end.reverse
      #   scope = scopes.detect { |s| s.const_defined?(name) }
      #   scope.const_get(name) if scope
      # end

      def validator
        @validator ||= ::Enjoy::Parts::Validator.new(params_wrapper)
      end

      # def prop_types
      #   if self.validator
      #     {
      #       _componentValidator: %x{
      #         function(props, propName, componentName) {
      #           var errors = #{validator.validate(Hash.new(`props`))};
      #           var error = new Error(#{"In component `#{name}`\n" + `errors`.join("\n")});
      #           return #{`errors`.count > 0 ? `error` : `undefined`};
      #         }
      #       }
      #     }
      #   else
      #     {}
      #   end
      # end
      #
      # def default_props
      #   validator.default_props
      # end

      def params(&block)
        validator.build(&block)
      end

      def params_wrapper
        @params_wrapper ||= ::Enjoy::Parts::Params
      end

      def param(*args)
        if args[0].is_a? Hash
          options = args[0]
          name = options.first[0]
          default = options.first[1]
          options.delete(name)
          options.merge!({default: default})
        else
          name = args[0]
          options = args[1] || {}
        end
        if options[:default]
          validator.optional(name, options)
        else
          validator.requires(name, options)
        end
      end

      # def collect_other_params_as(name)
      #   validator.allow_undefined_props = true
      #   validator_in_lexical_scope = validator
      #   props_wrapper.define_method(name) do
      #     @_all_others ||= validator_in_lexical_scope.undefined_props(props)
      #   end
      #
      #   validator_in_lexial_scope = validator
      #   props_wrapper.define_method(name) do
      #     @_all_others ||= validator_in_lexial_scope.undefined_props(props)
      #   end
      # end
      #
      #
      # def native_mixin(item)
      #   native_mixins << item
      # end
      #
      # def native_mixins
      #   @native_mixins ||= []
      # end
      #
      # def static_call_back(name, &block)
      #   static_call_backs[name] = block
      # end
      #
      # def static_call_backs
      #   @static_call_backs ||= {}
      # end
      #
      # def export_component(opts = {})
      #   export_name = (opts[:as] || name).split('::')
      #   first_name = export_name.first
      #   Native(`Opal.global`)[first_name] = add_item_to_tree(
      #     Native(`Opal.global`)[first_name],
      #     [React::API.create_native_react_class(self)] + export_name[1..-1].reverse
      #   ).to_n
      # end
      #
      # def imports(component_name)
      #   React::API.import_native_component(
      #     self, React::API.eval_native_react_component(component_name)
      #   )
      #   define_method(:render) {} # define a dummy render method - will never be called...
      # rescue Exception => e # rubocop:disable Lint/RescueException : we need to catch everything!
      #   raise "#{self} cannot import '#{component_name}': #{e.message}."
      #     # rubocop:enable Lint/RescueException
      # ensure
      #   self
      # end
      #
      # def add_item_to_tree(current_tree, new_item)
      #   if Native(current_tree).class != Native::Object || new_item.length == 1
      #     new_item.inject { |a, e| { e => a } }
      #   else
      #     Native(current_tree)[new_item.last] = add_item_to_tree(
      #       Native(current_tree)[new_item.last], new_item[0..-2]
      #     )
      #     current_tree
      #   end
      # end
    end
  end
end

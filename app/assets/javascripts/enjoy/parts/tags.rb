require 'enjoy/parts/v_node'

module Enjoy
  module Parts
    # contains the name of all HTML tags, and the mechanism to register a component class as a new tag
    module Tags
      HTML_TAGS = %w[a abbr address area article aside audio b base bdi bdo big blockquote body br
                     button canvas caption cite code col colgroup data datalist dd del details dfn
                     dialog div dl dt em embed fieldset figcaption figure footer form h1 h2 h3 h4 h5
                     h6 head header hr html i iframe img input ins kbd keygen label legend li link
                     main map mark menu menuitem meta meter nav noscript object ol optgroup option
                     output p picture pre progress q rp rt ruby s samp script section select
                     small source span strong style sub summary sup table tbody td textarea tfoot th
                     thead time title tr track u ul var video wbr] +
                  # TODO param taken out from above
                  # The SVG Tags
                  %w[circle clipPath defs ellipse g line linearGradient mask path pattern polygon polyline
                     radialGradient rect stop svg text tspan]

      HTML_TAGS.each do |tag|
        # we override Kernel.p and we define div hoping that it would not matter in this context
        # TODO: document p and div issue
        define_method(tag) do |*params, &block|
          ::Enjoy::Parts::VNode.new(tag, self, self.base_dom_node, *params, &block)
        end
        alias_method tag.upcase, tag
        const_set tag.upcase, tag
      end

      # use method_missing to look up component names in the form of "Foo(..)"
      # where there is no preceeding scope.
      def method_missing(name, *params, &block)
        component_class = find_component(name)
        return component_class.new('div', self, self.base_dom_node, *params).render if component_class
        # @self_before_instance_eval.send(name, *params, &block) if @self_before_instance_eval && @self_before_instance_eval.respond_to?(name)
        @component.send(name, *params, &block) if @component && @component.respond_to?(name)
        # Object.method_missing(name, *params, &block)
      end

      # install methods with the same name as the component in the parent class/module
      # thus component names in the form Foo::Bar(...) will work
      class << self
        def included(component)
          name, parent = find_name_and_parent(component)
          tag_names_module = Module.new do
            define_method name do |*params, &block|
              component.new('div', self, base_dom_node).internal_render({}, *params, &block)
            end
          end
          parent.extend(tag_names_module)
        end

        private

        def find_name_and_parent(component)
          split_name = component.name && component.name.split('::')
          if split_name && split_name.length > 1
            [split_name.last, split_name.inject([Module]) { |a, e| a + [a.last.const_get(e)] }[-2]]
          end
        end
      end

      private

      def find_component(name)
        component_class = lookup_const(name)
        if component_class && !component_class.method_defined?(:render)
          raise "#{name} does not appear to be a component."
        end
        component_class
      end

      def lookup_const(name)
        return nil unless name =~ /^[A-Z]/
        scopes = self.class.name.to_s.split('::').inject([Module]) do |nesting, next_const|
          nesting + [nesting.last.const_get(next_const)]
        end.reverse
        scope = scopes.detect { |s| s.const_defined?(name) }
        scope.const_get(name) if scope
      end
    end
  end
end

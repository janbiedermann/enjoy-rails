require 'enjoy/parts/tags'
require 'enjoy/parts/event_support'

module Enjoy
  module Parts
    class VNode
      module Mixin
        def self.included(base)
          base.include(::Enjoy::Parts::Tags)
          base.include(::Enjoy::Parts::EventSupport)
        end

        # virtual dom node
        attr_accessor :attributes, :base_dom_node, :children, :component, :key, :node_name, :opts, :parent_dom_node, :parent_v_node

        def initialize(tag, parent_v_node = nil, parent_dom_node = nil, attributes = {}, &block)
          @attributes = attributes || {}
          @children = []
          @events = {}
          @key = @attributes[:key] if @attributes[:key]
          @node_name = tag
          @opts = {}
          if parent_v_node
            @parent_v_node = parent_v_node
            @parent_v_node.children << self
          end
          @parent_dom_node = parent_dom_node
          internal_render(attributes, &block) if block_given?
        end

        def internal_render(attributes = nil, &block)
          @attributes = @attributes.merge(attributes) if attributes
          if block_given?
            res = instance_exec &block
            return if res.respond_to?(:is_vnode?)
            @children << res
          end
        end unless method_defined?(:internal_render)

        def is_vnode?
          true
        end

        def is_component?
          false
        end

        def render(tag, params, &block)
          @node_name = tag
          internal_render(params, &block)
        end
      end
    end
  end
end

module Enjoy
  module Parts
    class VNode
      include Enjoy::Parts::VNode::Mixin
    end
  end
end

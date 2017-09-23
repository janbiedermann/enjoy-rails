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
          @attributes = attributes ? attributes : {}
          @children = []
          @events = {}
          @key = @attributes[:key] if @attributes[:key]
          @node_name = tag
          @opts = {}
          if parent_v_node && parent_v_node.respond_to?(:is_vnode?)
            @component = parent_v_node.component
            @parent_v_node = parent_v_node
            @parent_v_node.children << self
          end
          @parent_dom_node = parent_dom_node
          internal_render(attributes, &block) if block_given?
          # puts "VNode: s: #{self} nn: #{@node_name} pvn: #{@parent_v_node} pdn: #{@parent_dom_node} bdn: #{@base_dom_node} c: #{@component} o: #{@opts} e: #{@events} c: #{@children}"
        end

        def internal_render(attributes = nil, &block)
          @attributes = @attributes.merge(attributes) if attributes
          res = instance_exec(&block)
          return if res.respond_to?(:is_vnode?)
          @children << res
          # puts "VNode: s: #{self} nn: #{@node_name} pvn: #{@parent_v_node} pdn: #{@parent_dom_node} bdn: #{@base_dom_node} c: #{@component} o: #{@opts} e: #{@events} c: #{@children}"
          self
        end

        def is_vnode?
          true
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

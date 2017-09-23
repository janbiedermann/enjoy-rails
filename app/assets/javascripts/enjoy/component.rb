require 'enjoy/parts/v_node'
require 'enjoy/parts/component_render'
require 'enjoy/parts/callbacks'
require 'enjoy/parts/api'
require 'enjoy/parts/class_methods'
require 'enjoy/parts/dsl_instance_methods'
require 'enjoy/parts/tags'

module Enjoy
  class Component
    module Mixin
      def self.included(base)
        base.include(::Enjoy::Parts::VNode::Mixin)
        base.include(::Enjoy::Parts::API)
        base.include(::Enjoy::Parts::Callbacks)
        base.include(::Enjoy::Parts::DslInstanceMethods)
        base.include(::Enjoy::Parts::ComponentRender) # this is required to override internal_render from VNode::Mixin
        base.class_eval do
          define_callback :before_mount
          define_callback :after_mount
          define_callback :before_receive_props
          define_callback :before_update
          define_callback :after_update
          define_callback :before_unmount
        end
        base.extend(::Enjoy::Parts::ClassMethods)
      end

      # base_dom_node: the dom_node of this component
      # state: state
      attr_accessor :prev_attributes, :prev_state, :state

      def clean!
        @dirty = false
      end

      def dirty!
        @dirty = true
      end

      def dirty?
        @dirty
      end

      def disable!
        @disabled = true
      end

      def disabled?
        @disabled
      end

      def enable!
        @disabled = false
      end

      def is_component?
        true
      end

      # ** Remove a component from the DOM and recycle it.
      #  *	@param {Component} component	The Component instance to unmount
      def unmount
        base_dn = @base_dom_node
        disable!
        component_will_unmount
        @base_dom_node = nil
        # recursively tear down & recollect high-order component children:
        Enjoy.remove_from_dom(base_dn)
        Enjoy.remove_children(base_dn)
        @mounted = false
      end

      private

      def private_enjoy_housekeeping_and_invoke_did_update(is_update, skip, opts, prev_attributes, prev_state)
        if !is_update || opts[:mount_all]
          Enjoy.mounts.unshift(self)
        elsif !skip && is_update
          # // Ensure that pending componentDidMount() hooks of child components
          # // are called before the componentDidUpdate() hook in the parent.
          component_did_update(prev_attributes, prev_state)
        end
        Enjoy.flush_mounts if Enjoy.diff_level == 0 && !opts[:is_child]
      end

      def private_invoke_will_update(prev_attributes, prev_state, attributes, state)
        @attributes = prev_attributes
        @state = prev_state
        if !opts[:force_render] && respond_to?(:should_component_update?) && !send(:should_component_update?, attributes, state)
          @skip = true
        elsif
          component_will_update(attributes, state)
        end
        @attributes = attributes
        @state = state
        @prev_attributes = @prev_state = nil
      end

      def private_render_and_diff(is_update, &block)
        res = instance_exec(&block)
        @parent_v_node.children << res if @parent_v_node && @parent_v_node.respond_to?(:is_vnode?) && !res.respond_to?(:is_vnode?)

        prev_base_dom_node = @base_dom_node
        if opts[:sync_render] || is_update
          opts[:mount_all] = opts[:mount_all] || !is_update
          @base_dom_node = Enjoy.diff(@base_dom_node, self, @opts, @parent_dom_node, true)
        end

        if @base_dom_node && `this.base_dom_node!==prev_base_dom_node`
          `this.base_dom_node.parentNode = this.parent_dom_node`
          `this.parent_dom_node.replaceChild(prev_base_dom_node, this.base_dom_node)` if @parent_dom_node && prev_base_dom_node
        end
      end

      # Set a component's `props` (generally derived from JSX attributes).
      #   *	@param {Object} props
      #   *	@param {Object} [opts]
      #   *	@param {boolean} [opts.renderSync=false]	If `true` and {@link options.syncComponentUpdates} is `true`, triggers synchronous rendering.
      #   *	@param {boolean} [opts.render=true]			If `false`, no render will be triggered.
      def private_set_properties(attributes, opts)
        # TODO: run callback?
        return if disabled?
        disable!

        @key = attributes[:key]
        attributes.delete(:key) if @key

        if !@base_dom_node || opts[:mount_all]
          component_will_mount
        else
          component_will_receive_props(attributes)
        end

        @prev_attributes = @attributes unless @prev_attributes
        @attributes = opts[:replace] ? attributes : @prev_attributes.merge(attributes)

        enable!

        if opts[:sync_render] || Enjoy.options[:sync_component_updates] || !@base_dom_node
          internal_render()
        else
          Enjoy.enqueue_render(self)
        end
      end

      # /** Update component state by copying properties from `state` to `this.state`.
      #    *	@param {object} state		A hash of state properties to update with new values
      #    *	@param {function} callback	A function to be called once component state is updated
      def private_set_state(state, opts)
        # TODO: run callback?
        @prev_state = @state unless @prev_state
        @state = opts[:replace] ? state : @prev_state.merge(state)
        Enjoy.enqueue_render(self)
      end
    end
  end
end

module Enjoy
  class Component
    include Enjoy::Component::Mixin
  end
end

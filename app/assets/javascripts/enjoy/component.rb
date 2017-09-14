require 'enjoy/v_node'
require 'enjoy/parts/callbacks'
require 'enjoy/parts/api'
require 'enjoy/parts/class_methods'
require 'enjoy/parts/dsl_instance_methods'
require 'enjoy/parts/tags'

module Enjoy
  class Component
    module Mixin
      def self.included(base)
        base.include(Enjoy::Parts::API)
        base.include(Enjoy::Parts::Callbacks)
        base.include(Enjoy::Parts::DslInstanceMethods)
        base.include(Enjoy::Parts::Tags)
        base.class_eval do
          define_callback :before_mount
          define_callback :after_mount
          define_callback :before_receive_props
          define_callback :before_update
          define_callback :after_update
          define_callback :before_unmount
        end
        base.extend(Enjoy::Parts::ClassMethods)
      end

      # base_dom_node: the dom_node of this component
      # parent_dom_node: the dom node this component is atached to
      # props: properties
      # state: state
      attr_accessor :base_dom_node, :base_v_node, :opts, :parent_dom_node, :parent_v_node, :prev_props, :prev_state, :props, :state

      def initialize(parent_v_node = nil, parent_dom_node = nil)
        @disable = false
        @opts = {}
        @parent_dom_node = parent_dom_node
        @parent_v_node = parent_v_node
        @props = {}
        @state = {}
      end

      # supported callbacks:
      # component_will_mount: before the component gets mounted to the DOM
      # component_did_mount: after the component gets mounted to the DOM
      # component_will_unmount: prior to removal from the DOM
      #
      # component_will_receive_props: before new props get accepted
      #
      # should_component_update: before render(). Return false to skip render
      # component_will_update: before render()
      # component_did_update: after render()

      def component_will_mount
        run_callback(:before_mount)
      rescue Exception => e
        self.class.process_exception(e, self)
      end

      def component_did_mount
        run_callback(:after_mount)
      rescue Exception => e
        self.class.process_exception(e, self)
      end

      def component_will_receive_props(next_props)
        run_callback(:before_receive_props, Hash.new(next_props))
      rescue Exception => e
        self.class.process_exception(e, self)
      end

      def component_will_update(next_props, next_state)
        run_callback(:before_update, Hash.new(next_props), Hash.new(next_state))
      rescue Exception => e
        self.class.process_exception(e, self)
      end

      def component_did_update(prev_props, prev_state)
        run_callback(:after_update, Hash.new(prev_props), Hash.new(prev_state))
      rescue Exception => e
        self.class.process_exception(e, self)
      end

      def component_will_unmount
        run_callback(:before_unmount)
      rescue Exception => e
        self.class.process_exception(e, self)
      end

      unless method_defined?(:render)
        def render
          raise 'no render defined'
        end
      end

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

      # ** Render a Component, triggering necessary lifecycle events.
      # *	@param {Object} [opts] { mount_all: false, is_child: false, sync_render: false, force_render: false }
      # *	@param {boolean} [opts.build=false]		If `true`, component will build and store a DOM node if not already associated with one.
      # *	returns reference to rendered dom_node
      def render_component(props, &block)
        # return if component is busy rendering or out of dom
        return if disabled?

        raise self.class.name + ': at least either tag or block must be given for render' unless base_v_node || block

        state = @state
        prev_props = @prev_props || props
        prev_state = @prev_state || state

        # if @base_dom_node exists, component has been rendered, so it will be an update
        # !! makes it a boolean
        is_update = !!@base_dom_node
        skip = false

        # if updating, ask component if it wants to be updated
        # otherwise invoke :component_will_update callback
        private_invoke_will_update(prev_props, prev_state, props, state) if is_update

        # component will be rendered
        clean!

        private_render_and_diff(is_update, &block) unless skip

        private_enjoy_housekeeping_and_invoke_did_update(is_update, skip, opts, prev_props, prev_state)
        @base_v_node
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

      def private_enjoy_housekeeping_and_invoke_did_update(is_update, skip, opts, prev_props, prev_state)
        if !is_update || opts[:mount_all]
          Enjoy.mounts.unshift(self)
        elsif !skip && is_update
          # // Ensure that pending componentDidMount() hooks of child components
          # // are called before the componentDidUpdate() hook in the parent.
          component_did_update(prev_props, prev_state)
        end
        Enjoy.flush_mounts if Enjoy.diff_level == 0 && !opts[:is_child]
      end

      def private_invoke_will_update(prev_props, prev_state, props, state)
        @props = prev_props
        @state = prev_state
        if !opts[:force_render] && respond_to?(:should_component_update?) && !send(:should_component_update?, props, state)
          skip = true
        elsif
          component_will_update(props, state)
        end
        @props = props
        @state = state
        @prev_props = @prev_state = nil
      end

      def private_render_and_diff(is_update, &block)
        res = instance_exec &block
        @parent_v_node.children << res if @parent_v_node && !@base_v_node
        @base_v_node = res unless @base_v_node
        @base_v_node.component = self
        prev_base_dom_node = @base_dom_node
        if opts[:sync_render] || is_update
          opts[:mount_all] = opts[:mount_all] || !is_update
          @base_dom_node = Enjoy.diff(@base_dom_node, @base_v_node, opts, @parent_dom_node, true)
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
      def private_set_properties(props, opts)
        # TODO: run callback?
        return if disabled?
        disable!

        @key = props[:key]
        props.delete(:key) if @key

        if !@base_dom_node || opts[:mount_all]
          component_will_mount
        else
          component_will_receive_props(props)
        end

        @prev_props = @props unless @prev_props
        @props = opts[:replace] ? props : @prev_props.merge(props)

        enable!

        if opts[:sync_render] || Enjoy.options[:sync_component_updates] || !@base_dom_node
          render_component()
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

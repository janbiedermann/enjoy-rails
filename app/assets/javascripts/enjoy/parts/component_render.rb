module Enjoy
  module Parts
    module ComponentRender
      # ** Render a Component, triggering necessary lifecycle events.
      # *	@param {Object} [opts] { mount_all: false, is_child: false, sync_render: false, force_render: false }
      # *	@param {boolean} [opts.build=false]		If `true`, component will build and store a DOM node if not already associated with one.
      # *	returns reference to rendered dom_node
      def internal_render(attributes = {}, &block)
        # return if component is busy rendering or out of dom
        return if disabled?

        attr = @attributes.merge(attributes)

        params.instance_variable_get('@params').merge!(attr) if self.class.validator.validate(attr) == []

        @component = self

        # state = @state
        prev_attributes = @prev_attributes || attr
        prev_state = @prev_state || state

        # if @base_dom_node exists, component has been rendered, so it will be an update
        # !! makes it a boolean
        is_update = !!@base_dom_node
        @skip = false

        # if updating, ask component if it wants to be updated
        # otherwise invoke :component_will_update callback
        private_invoke_will_update(prev_attributes, nil, attr, nil) if is_update

        # component will be rendered
        clean!

        private_render_and_diff(is_update, &block) unless @skip

        private_enjoy_housekeeping_and_invoke_did_update(is_update, @skip, opts, prev_attributes, prev_state)
        # puts "VNode: s: #{self} nn: #{@node_name} pvn: #{@parent_v_node} pdn: #{@parent_dom_node} bdn: #{@base_dom_node} c: #{@component} o: #{@opts} e: #{@events} c: #{@children}"
        self
      end
    end
  end
end
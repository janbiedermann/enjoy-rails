module Enjoy
  module Parts
    module ComponentRender
      # ** Render a Component, triggering necessary lifecycle events.
      # *	@param {Object} [opts] { mount_all: false, is_child: false, sync_render: false, force_render: false }
      # *	@param {boolean} [opts.build=false]		If `true`, component will build and store a DOM node if not already associated with one.
      # *	returns reference to rendered dom_node
      def internal_render(attributes = nil, &block)
        # return if component is busy rendering or out of dom
        return if disabled?

        state = @state
        prev_attributes = @prev_attributes || attributes
        prev_state = @prev_state || state

        # if @base_dom_node exists, component has been rendered, so it will be an update
        # !! makes it a boolean
        is_update = !!@base_dom_node
        @skip = false

        # if updating, ask component if it wants to be updated
        # otherwise invoke :component_will_update callback
        private_invoke_will_update(prev_attributes, prev_state, attributes, state) if is_update

        # component will be rendered
        clean!

        private_render_and_diff(is_update, &block) unless @skip

        private_enjoy_housekeeping_and_invoke_did_update(is_update, @skip, opts, prev_attributes, prev_state)
        self
      end
    end
  end
end
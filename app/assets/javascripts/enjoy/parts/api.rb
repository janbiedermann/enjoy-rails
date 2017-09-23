module Enjoy
  module Parts
    module API
      def dom_node
        @base_dom_node
      end

      def mounted?
        @disabled
      end

      # /** Immediately perform a synchronous re-render of the component.
      def force_update!
        opts[:force_render] = true
        internal_render
        opts[:force_render] = false
      end

      def set_props(props, &block)
        private_set_properties(props, {}, block)
      end

      def set_props!(props, &block)
        private_set_properties(props, { replace: true }, block)
      end

      def set_state(state, &block)
        private_set_state(state, {}, block)
      end

      def set_state!(state, &block)
        private_set_state(state, { replace: true }, block)
      end
    end
  end
end

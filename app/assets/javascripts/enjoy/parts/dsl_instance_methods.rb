module Enjoy
  module Parts
    module DslInstanceMethods
      def children
        # TODO
        # Children.new(`#{@native}.props.children`)
      end

      def params
        # TODO
        # @params ||= self.class.props_wrapper.new(self)
      end
    end
  end
end

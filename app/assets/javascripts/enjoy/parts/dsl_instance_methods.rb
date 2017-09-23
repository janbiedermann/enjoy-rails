module Enjoy
  module Parts
    module DslInstanceMethods
      def params
        @params_wrapper ||= self.class.params_wrapper.new(self)
      end

      def props
        @attributes
      end
    end
  end
end

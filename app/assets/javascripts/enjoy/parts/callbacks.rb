module Enjoy
  module Parts
    module Callbacks
      def self.included(base)
        base.extend(ClassMethods)
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

      def run_callback(name, *args)
        self.class.callbacks_for(name).each do |callback|
          if callback.is_a?(Proc)
            instance_exec(*args, &callback)
          else
            send(callback, *args)
          end
        end
      end

      module ClassMethods
        def define_callback(callback_name)
          wrapper_name = "_#{callback_name}_callbacks"
          define_singleton_method(wrapper_name) do
            # Hyperloop::Context.set_var(self, "@#{wrapper_name}", force: true) { [] }
            []
          end
          define_singleton_method(callback_name) do |*args, &block|
            send(wrapper_name).concat(args)
            send(wrapper_name).push(block) if block_given?
          end
        end

        def callbacks_for(callback_name)
          wrapper_name = "_#{callback_name}_callbacks"
          if superclass.respond_to? :callbacks_for
            superclass.callbacks_for(callback_name)
          else
            []
          end + send(wrapper_name)
        end
      end
    end
  end
end
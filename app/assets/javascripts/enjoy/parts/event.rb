module Enjoy
  module Parts
    class Event
      SUPPORTED_EVENTS = [[:copy, :copied],
                          [:cut, :cut],
                          [:paste, :pasted],
                          [:keydown, :key_down],
                          [:keypress, :key_pressed],
                          [:keyup, :key_up],
                          [:focus, :focused],
                          [:blur, :blurred],
                          [:change, :changed],
                          [:input, :input],
                          [:submit, :submitted],
                          [:click, :clicked],
                          [:double_click, :double_clicked],
                          [:drag, :dragged],
                          [:dragend, :drag_ended],
                          [:dragenter, :drag_entered],
                          [:dragexit, :drag_exited],
                          [:dragleave, :drag_left],
                          [:dragover, :drag_ended],
                          [:dragstart, :drag_started],
                          [:drop, :dropped],
                          [:mousedown, :mouse_down],
                          [:mouseenter, :mouse_enter],
                          [:mouseleave, :mouse_leave],
                          [:mousemove, :mouse_move],
                          [:mouseout, :mouse_out],
                          [:mouseover, :mouse_over],
                          [:mouseup, :mouse_up],
                          [:touchcancel, :touch_cancelled],
                          [:touchend, :touch_ended],
                          [:touchmove, :touch_move],
                          [:touchstart, :touch_started],
                          [:scroll, :scrolling]]

      SUPPORTED_EVENTS.each do |event_ar|
        method_name = (event_ar[1] ? event_ar[1] : event_ar[0]).to_s + '?'
        define_method(method_name) do
          event_type_is?(event_ar[0])
        end
      end

      def initialize(js_event)
        @js_event = js_event
      end

      def event_type_is?(evt_type)
        self.type == evt_type
      end

      def prevent_default
        `this.js_event.preventDefault()`
      end

      def target_js
        `js_event.target`
      end

      def type
        `js_event.type`
      end
    end
  end
end
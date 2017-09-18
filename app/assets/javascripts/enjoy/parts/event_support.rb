require 'promise'
require 'enjoy/parts/event'

module Enjoy
  module Parts
    module EventSupport

      def event_handler(js_evt)
        evt_type = `js_evt.type`
        @events[evt_type].each do |cb_info|
          if cb_info[:promise]
            event = ::Enjoy::Parts::Event.new(js_evt)
            cb_info[:promise].resolve(event) unless cb_info[:promise].resolved?
          elsif cb_info[:block]
            cb_info[:block].call(js_evt)
          end
        end
      end

      def on(v_event, *v_events, &block)
        v_events_a = [v_event]
        v_events_a += v_events if v_events
        v_events_a.each do |v_e|
          v_ed = v_e.downcase
          @events[v_ed] ||= []
          @events[v_ed] << { block: block }
          @attributes['on' + v_ed] = true
        end
        self
      end

      def promise_on(v_event, *v_events)
        v_events_a = [v_event]
        v_events_a += v_events if v_events
        promise = Promise.new
        v_events_a.each do |v_e|
          v_ed = v_e.downcase
          @events[v_ed] ||= []
          @events[v_ed] << { promise: promise }
          @attributes['on' + v_ed] = true
        end
        promise
      end
    end
  end
end
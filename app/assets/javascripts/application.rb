require 'rails-ujs'
require 'cable'
require 'opal'

def benchmark(message)
  start = `performance.now()`
  result = yield
  finish = `performance.now()`
  puts "#{message} in #{(finish - start).round(3)} ms"

  result
end

require 'enjoy'

class OlaComponent
  include Enjoy::Component::Mixin

  param :more_text, default: 'hello', type: String, allow_nil: true

  # state important: 'wichtig'

  render do
    DIV { 'text to click' }
      .on(:click) do
        `alert('hello')`
      end
    DIV {
      a = 'test '
      DIV { a }
      b = params.more_text
      P { 'lorem ipsum dolor 2 param:' + b }
      DIV {
        DIV { 'text here to click for promise' }.on(:click) do
                                                  `alert('I, Promise')`
                                                 end
        P {
          # i = state.important
          "lorem ipsum dolor 2 state: #{i}"
        }
        DIV {
          DIV { 'text here' }
          P { 'lorem ipsum dolor 2' }
          DIV {
            DIV { 'text here' }
            P { 'lorem ipsum dolor 2' }
            DIV {
              DIV { 'text here' }
              P { 'lorem ipsum dolor 2' }
              DIV {
                DIV { 'text here' }
                P { 'lorem ipsum dolor 2' }
                DIV {
                  DIV { 'text here' }
                  P { 'lorem ipsum dolor 2' }
                  DIV {
                    DIV { 'text here' }
                    P { 'lorem ipsum dolor 2' }
                    DIV {
                      DIV { 'text here' }
                      P { 'lorem ipsum dolor 2' }
                      DIV {
                        DIV { 'text here' }
                        P { 'lorem ipsum dolor 2' }
                        DIV {
                          DIV { 'text here' }
                          P { 'lorem ipsum dolor 2' }
                          DIV {
                            DIV { 'text here' }
                            P { 'lorem ipsum dolor 2' }
                            DIV {
                              DIV { 'text here' }
                              P { 'lorem ipsum dolor 2' + a }
    }}}}}}}}}}}}}
  end
end

class TestComponent
  include Enjoy::Component::Mixin

  render(DIV) do
    DIV(class: 'ohmy')
    H1 { 'Überschrift ' }
    SPAN { 10 }
    OlaComponent(more_text: 'given more text, via params')
    P { 'lorem ipsum dolor' }
    DIV(class: 'hyperduper') do
      DIV { 'text here' }
      P { 'lorem ipsum dolor 2' }
      OlaComponent()
    end
  end
end

class MasterComponent < Enjoy::Component
  render do
    10000.times do
      DIV { 'Actually, the DOM is fast.' }
    end
  end
end

Enjoy.start(TestComponent)
Enjoy.start(MasterComponent)

`setTimeout(function() { console.log(document.getElementsByTagName("*").length) }, 1000)`


# `setTimeout(function() {
# var finish;
# var start = performance.now();
#
# var numDivs = 10000;
#  var fragment = document.createDocumentFragment();
# while(numDivs--){
#   var newDiv = document.createElement('div');
#   newDiv.innerHTML = 'Actually, the DOM is fast.';
#   fragment.appendChild(newDiv);
# }
# document.body.appendChild(fragment);
#
# finish = performance.now();
# console.log( finish - start );
# ; }, 0)`
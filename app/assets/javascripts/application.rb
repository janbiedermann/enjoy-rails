require 'rails-ujs'
require 'cable'

require 'opal'

def benchmark message
  if `!!(console.time && console.timeEnd)`
    `console.time(message)`
    result = yield
    `console.timeEnd(message)`
  else
    start = `performance.now()`
    result = yield
    finish = `performance.now()`
    puts "#{message} in #{(finish - start).round(3)}ms"
  end

  result
end

require 'enjoy'

class OlaComponent
  include Enjoy::Component::Mixin

  render do
    DIV { 'text to click' }
      .on(:click) do
        `alert('hello')`
      end
    DIV {
      DIV { 'text here' }
      P { 'lorem ipsum dolor 2' }
      DIV {
        DIV { 'text here to click for promise' }.promise_on(:click)
                                                .do {
                                                  `alert('I, Promise')`
                                                }
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
                            P { 'lorem ipsum dolor 2' }
                            DIV {
                              DIV { 'text here' }
                              P { 'lorem ipsum dolor 2' }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end
end

class TestComponent
  include Enjoy::Component::Mixin

  render(DIV) do
    DIV(class: 'ohmy')
    H1 { 'Überschrift ' }
    SPAN { 10 }
    OlaComponent()
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
    10.times do
      TestComponent()
    end
  end
end

benchmark('app') { Enjoy.start(MasterComponent) }

`setTimeout(function() { console.log(document.getElementsByTagName("*").length) }, 1000)`


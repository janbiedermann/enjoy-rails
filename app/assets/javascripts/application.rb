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
    DIV { 'text' }
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
    1000.times do
      TestComponent()
    end
  end
end

benchmark('app') { Enjoy.start(MasterComponent) }
i = 0
`i = document.getElementsByTagName("*").length`
puts "rendered #{i} nodes"

benchmark('app') { Enjoy.start(MasterComponent) }
benchmark('app') { Enjoy.start(MasterComponent) }
benchmark('app') { Enjoy.start(MasterComponent) }
benchmark('app') { Enjoy.start(MasterComponent) }
`i = document.getElementsByTagName("*").length`
puts "rendered #{i} nodes"

# benchmark('total') do
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# benchmark('app') { Enjoy.start(TestComponent) }
# end

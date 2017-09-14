require 'rails-ujs'
require 'turbolinks'
require 'cable'

require 'opal'
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

Enjoy.start(TestComponent)
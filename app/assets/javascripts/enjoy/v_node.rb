class VNode
  # virtual dom node
  attr_accessor :attributes, :children, :component, :key, :node_name, :parent_v_node

  def initialize(node_name, parent_v_node, children, attributes, &block)
    @attributes = attributes || {}
    @children = children || []
    @key = @attributes[:key] if @attributes[:key]
    @node_name = node_name
    @parent_v_node = parent_v_node
    @parent_v_node.children << self if @parent_v_node
    children_from_block(&block) if block
    puts "v_node: #{self} - #{@node_name}: #{@children}"
  end

  def base_v_node
    self
  end

  def children_from_block(&block)
    res = instance_exec &block
    return if res.is_a? Enjoy::VNode
    @children << res
  end

  def get_properties
    props = {}.merge(@attributes)
    props[:children] = @children
    props
  end

  def method_missing(name, *args, &block)
    component = find_component(name)
    return component.new(self, nil).render if component
    VNode.new(name, self, [], *args, &block)
  end

  private

  def find_component(name)
    component = lookup_const(name)
    if component && !component.method_defined?(:render)
      raise "#{name} does not appear to be a component."
    end
    component
  end

  def lookup_const(name)
    return nil unless name =~ /^[A-Z]/
    scopes = self.class.name.to_s.split('::').inject([Module]) do |nesting, next_const|
      nesting + [nesting.last.const_get(next_const)]
    end.reverse
    scope = scopes.detect { |s| s.const_defined?(name) }
    scope.const_get(name) if scope
  end
end
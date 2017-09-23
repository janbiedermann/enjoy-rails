require 'enjoy/parts/v_node'
require 'enjoy/component'

module Enjoy
  # test for svg `(dom_node.parentNode.ownerSVGElement!==null)`
  @@diff_level = 0

  def self.diff_level
    @@diff_level
  end

  def self.diff_level_incr
    @@diff_level += 1
  end

  def self.diff_level_decr
    @@diff_level -= 1
  end

  @@items_to_render = []

  # If `true`, property changes via set_properties trigger synchronous component updates.
  @@options = { sync_component_updates: true }
  def self.options
    @@options
  end

  @@mounts = [] # /** Queue of components that have been mounted and are awaiting componentDidMount */
  def self.mounts
    @@mounts
  end

  IS_NON_DIMENSIONAL = /acit|ex(?:s|g|n|p|$)|rph|ows|mnc|ntw|ine[ch]|zoo|^ord/i

  # /** Apply differences in a given vnode (and it's deep children) to a real DOM Node.
  #   *	@param {Element} [dom=null]		A DOM node to mutate into the shape of the `vnode`
  #   *	@param {VNode} vnode			A VNode (with descendants forming a tree) representing the desired DOM structure
  #   *	@returns {Element} dom			The created/mutated element
  def self.diff(dom_node, vnode, opts, parent_dom_node, component_root)
    # diffLevel having been 0 here indicates initial entry into the diff (not a subdiff)
    @@svg_mode = false
    @@hydrating = false
    diff_level_incr
    # when first starting the diff, check if we're diffing an SVG or within an SVG
    @@svg_mode = parent_dom_node && `parent_dom_node.parentNode && parent_dom_node.parentNode.ownerSVGElement!==undefined`
    # hydration is indicated by the existing element to be diffed not having a prop cache
    @@hydrating = dom_node ? `'__prop_cache__' in dom_node` : false
    ret_node = idiff(dom_node, vnode, opts, component_root)
    # append the element if its a new parent
    `parent_dom_node.appendChild(ret_node)` if parent_dom_node && (`ret_node.parentNode!==parent_dom_node`)
    # diffLevel being reduced to 0 means we're exiting the diff
    level = diff_level_decr
    unless level == 0
      @@hydrating = false
      # invoke queued componentDidMount lifecycle methods
      flush_mounts unless component_root
    end
    ret_node
  end

  # Apply differences in attributes from a VNode to the given DOM Element.
  # *	@param {Element} dom		Element with attributes to diff `attrs` against
  # *	@param {Object} attrs		The desired end-state key-value attribute pairs
  # *	@param {Object} old			Current/previous attributes (from previous VNode or element's prop cache)
  def self.diff_attributes(dom_node, v_node, old)
    attrs = v_node.attributes
    old.each do |name, val|
      next unless !(attrs && attrs[name]) && val
      old_name = val
      old[name] = nil
      set_accessor(dom_node, v_node, name, old_name, nil, @svg_mode)
    end
    attrs.each do |name, val|
      next unless name != 'children' && name != 'innerHTML' && !old.keys.include?(name) ||
        attrs[name] != (name == 'value' || name == ('checked' ? `dom_node[name]` : old[name]))
      old_name = old[name]
      old[name] = val
      set_accessor(dom_node, v_node, name, old_name, old[name], @svg_mode)
    end
  end

  def self.diff_node_children(dom_node, vchildren, opts, hydrating)
    original_children = `dom_node.childNodes`
    oc_len = `(original_children && original_children.length)` ? `original_children.length` : 0
    children = []
    keyed = {}
    keyed_len = 0
    min = 0
    children_len = 0
    vlen = vchildren ? vchildren.size : 0

    # Build up a map of keyed children and an Array of unkeyed children:
    (0...oc_len).each do |i|
      child = `original_children.item(i)`
      props = `child['__prop_cache__']`
      o_node = `child['DomNode']`
      props_key = props ? `props.key` : nil
      chosen_key = o_node && o_node.component ? o_node.component.key : props_key
      key = vlen && props ? chosen_key : nil
      tv = hydrating ? `child.nodeValue.trim()` : true
      if key
        keyed_len += 1
        keyed[key] = child
      elsif props || (`child.splitText!==undefined` ? tv : hydrating)
        children[children_len += 1] = child
      end
    end

    (0...vlen).each do |i|
      vchild = vchildren[i]
      child = nil

      key = vchild.is_a?(::Enjoy::Parts::VNode) ? vchild.key : nil
      if key && keyed_len && keyed[key]
        child = keyed[key]
        keyed[key] = nil
        keyed_len -= 1
      elsif !child && min < children_len
        (min..children_len).each do |j|
          c = children[j]
          next unless children[j] && is_named_like(c,vchild.node_name)
          child = c
          children[j] = nil
          children_len -= 1 if j == children_len
          min += 1 if j == min
          break
        end
      end
      child = idiff(child,vchild, opts)

      f = `original_children[i]`
      if child && `child !== dom_node` && `child !== f`
        if `f===undefined || f===null`
          `dom_node.appendChild(child)`
        elsif child == `f.nextSibling`
          remove_from_dom(f)
        else
          `dom_node.insertBefore(child, f)`
        end
      end
    end

    # remove unused eyed children
    if keyed_len
      keyed.each do |i|
        recollect_node_tree(keyed[i]) if keyed[i]
      end
    end

    # remove orphaned unkeyed children
    while min <= children_len
      child = children[children_len -= 1]
      recollect_node_tree(child) if child
    end
  end

  def self.enqueue_render(component)
    if !component.dirty? && @@items_to_render.push(component).size == 1
      rerender
    end
  end

  def self.find(node_descr)
    key = node_descr.keys.first.to_s
    val = node_descr[key]
    node = case key
           when 'id' then `document.getElementById(val)`
           when 'tag' then `document.getElementsByTagName(val).item(0)`
           when 'class' then `document.getElementsByClassName(val).item(0)`
           when 'css' then `document.querySelectorAll(val).item(0)`
           else
             raise 'unknown selector'
           end
    node
  end

  def self.flush_mounts
    c = @@mounts.pop
    while c
      c.component_did_mount
      c = @@mounts.pop
    end
  end

  # Internals of `diff()`, separated to allow bypassing diffLevel / mount flushing.
  def self.idiff(dom_node, vnode, opts, component_root = nil)
    out = dom_node
    prev_svg_mode = @svg_mode
    # empty values (null, undefined, booleans) render as empty Text nodes
    vnode = '' if !vnode || (vnode && vnode.is_a?(Boolean))
    # Fast case: Strings & Numbers create/update Text nodes.
    if vnode.is_a?(String) || vnode.is_a?(Integer)
      # update if its already a text node
      if `dom_node.splitText!==undefined` && `dom_node.parentNode` && (!dom_node.component || component_root)
        # istanbul ignore if
        # Browser quirk that can't be covered: https://github.com/developit/preact/commit/fd4f21f5c45dfd75151bd27b4c217d8003aa5eb9
        `dom_node.nodeValue = vnode` if `dom_node.nodeValue` != vnode
      else
        # it wasn't a Text node: replace it with one and recycle the old Element
        out = `document.createTextNode(vnode)`
        `if (dom_node.parentNode) dom_node.parentNode.replaceChild(out, dom_node)`
        recollect_node_tree(dom_node, true)
      end
      `out['__prop_cache__'] = true`
    elsif vnode.respond_to?(:is_vnode?)
      # If the VNode represents a Component, perform a component diff:

      vnode_name = vnode.node_name

      # Tracks entering and exiting SVG namespace when descending through the tree.
      svg_mode = vnode_name == 'svg' ? true : (vnode_name == 'foreign_object' ? false : svg_mode)

      if !dom_node || (dom_node && !is_named_like(dom_node, vnode_name))
        out = svg_mode ? `document.createElementNS('http://www.w3.org/2000/svg', vnode_name)`: `document.createElement(vnode_name)`
        # move children into the replacement node
        if dom_node
          while `dom_node.firstChild`
            `out.appendChild(dom_node.firstChild)`
          end
          # if the previous Element was mounted into the DOM, replace it inline
          `if (dom_node.dom_node.parentNode) dom_node.dom_node.parentNode.replaceChild(out, dom_node.dom_node)`
          # recycle the old element (skips non-Element node types)
          recollect_node_tree(dom_node, true)
        end
      end

      fc = `out.firstChild`
      props = `dom_node['__prop_cache__']`
      vchildren = vnode.children

      unless props
        `out['__prop_cache__'] = {}`
        props = {}.merge(`Opal.hash(out.attributes)`)
      end

      # Optimization: fast-path for elements containing a single TextNode:
      if !@hydrating && vchildren && vchildren.size == 1 && vchildren[0].is_a?(String) && fc && `fc.splitText!==undefined` && !`fc.nextSibling`
        `fc.nodeValue = vchildren[0]` if `fc.nodeValue` != vchildren[0]
      elsif vchildren && vchildren.size || fc # otherwise, if there are existing or new children, diff them:
        diff_node_children(out, vchildren, opts, @hydrating || props[:dangerously_set_inner_html])
      end
      diff_attributes(out, vnode, props)
    end
    @svg_mode = prev_svg_mode

    out
  end

  def self.is_named_like(dom_node, vname)
    `dom_node.nodeName` == vname || `dom_node.nodeName`.downcase == vname.downcase
  end

  def self.ready?(&block)
    `setTimeout(function() { #{ block.call }; }, 0)`
    self
  end

  # ** Recursively recycle (or just unmount) a node and its descendants.
  #	*	@param {Node} node						DOM node to start unmount/removal from
  # *	@param {Boolean} [unmountOnly=false]	If `true`, only triggers unmount lifecycle, skips removal
  def self.recollect_node_tree(dom_node, unmount_only = false)
    opal_dom_node = `dom_node['DomNode']`
    if opal_dom_node && opal_dom_node.component
      # if node is owned by a Component, unmount that component (ends up recursing back here)
      opal_dom_node.component.unmount
    else
      remove_from_dom(dom_node) unless unmount_only
      remove_children(dom_node)
    end
  end

  # Recollect/unmount all children.
  # *	- we use .lastChild here because it causes less reflow than .firstChild
  # *	- it's also cheaper than accessing the .childNodes Live NodeList
  def self.remove_children(dom_node)
    node = `dom_node.lastChild`
    while node
      next_node = `node.previousSibling`
      recollect_node_tree(node, true)
      node = next_node
    end
  end

  def self.remove_from_dom(dom_node)
    `var parent_node; parent_node = dom_node.parentNode;
		 if (parent_node) parent_node.removeChild(dom_node);
     if (dom_node['DomNode']) dom_node['DomNode'].dom_node = null`
  end

  def self.rerender
    list = @@items_to_render
    @@items_to_render = []
    list.each { |i|	i.internal_render if i.dirty? }
  end

  # /** Set a named attribute on the given Node, with special behavior for some names and event handlers.
  #   *	If `value` is `null`, the attribute/handler will be removed.
  # 	*	@param {Element} node	An element to mutate
  # *	@param {string} name	The name/key to set, such as an event or attribute name
  # *	@param {any} old	The last value that was set for this name/node pair
  # *	@param {any} value	An attribute value, such as a function to be used as an event handler
  # *	@param {Boolean} isSvg	Are we currently diffing inside an svg?
  def self.set_accessor(dom_node, v_node, name, old, value, svg_mode)
    name = 'class' if name == 'className'

    # ignore name == 'key'
    if name == 'class' && !svg_mode
      `dom_node.className = value || ''`
    elsif name == 'style'
      `dom_node.style.cssText = value || ''` if !value || value.is_a?(String) || old.is_a?(String)
      if old.is_a?(Array)
        old.each { |o| `dom_node.style[o] = ''` unless value.include? o }
      end
      value.each do |v|
        val = (v.is_a?(Integer) && (!IS_NON_DIMENSIONAL.test(v)) ? v + 'px' : v)
        `dom_node.style[v] = val`
      end
    elsif name == 'dangerouslySetInnerHTML'
      `dom_node.innerHTML = value || ''`
    elsif name.is_a?(String) && name[0..1] == 'on'
      name_woc = name.sub(/_capture$/, '')
      use_capture = name != name_woc
      name = name_woc.downcase[2..-1]
      if value
        `dom_node.addEventListener(name, function(e) { v_node.$event_handler(e) }, use_capture)` unless old
      else
        `dom_node.removeEventListener(name, function(e) { v_node.$event_handler(e) }, use_capture)`
      end
    elsif name != 'list' && name != 'type' && !svg_mode && `name in dom_node`
      set_property(dom_node, name, value ? value : '')
      `dom_node.removeAttribute(name)` unless value
    else
      ns = svg_mode && name != (name = name.sub(/^xlink\:?/, ''))
      if !value
        if ns
          `dom_node.removeAttributeNS('http://www.w3.org/1999/xlink', name.toLowerCase())`
        else
          `dom_node.removeAttribute(name)`
        end
      else
        if ns
          `dom_node.setAttributeNS('http://www.w3.org/1999/xlink', name.toLowerCase(), value)`
        else
          `dom_node.setAttribute(name, value)`
        end
      end
    end
  end

  # Attempt to set a DOM property to the given value.
  def self.set_property(dom_node, name, value)
    `dom_node[name] = value`
  rescue
    # just ignore, IE & FF throw for certain property-value combinations.
  end

  def self.start(component_class, parent = nil)
    ready? do
      benchmark('app') {
        parent = Enjoy.find(tag: 'body') unless parent
        c = component_class.new('div', nil, parent)
        c.opts[:sync_render] = true
        c.render
      }
    end
  end
end

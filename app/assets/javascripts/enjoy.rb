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
  def self.diff(dom_node, vnode, parent_dom_node, component_root)
    dom_node = `undefined` if dom_node == nil
    # diffLevel having been 0 here indicates initial entry into the diff (not a subdiff)
    `Opal.Enjoy['svg_mode'] = false`
    `Opal.Enjoy['hydrating'] = false`
    diff_level_incr
    # when first starting the diff, check if we're diffing an SVG or within an SVG
    `Opal.Enjoy['svg_mode'] = (parent_dom_node !== undefined && parent_dom_node.parentNode && parent_dom_node.parentNode.ownerSVGElement !== undefined)`
    # hydration is indicated by the existing element to be diffed not having a prop cache
    `Opal.Enjoy['hydrating'] = (dom_node !== undefined ? ('__prop_cache__' in dom_node) : false)`
    ret_node = idiff(dom_node, vnode, component_root)
    # append the element if its a new parent
    %x{
      if (parent_dom_node !== undefined && (ret_node.parentNode!==parent_dom_node)) {
        parent_dom_node.appendChild(ret_node);
      }
    }
    # diffLevel being reduced to 0 means we're exiting the diff
    level = diff_level_decr
    unless level == 0
      `Opal.Enjoy['hydrating'] = false`
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
    %x{
      var attrs = v_node.$attributes();
      var attrs_keys = attrs.$keys();
      if (attrs_keys.length > 0) {
        for (var i = 0; i <  attrs_keys.length; i++) {
          name = attrs_keys[i];
          if (!(name !== 'children' && name !== 'innerHTML' && old[name] === undefined ||
            attrs.$fetch(name) !== (name === attrs.$fetch(name) || name === (checked ? dom_node[name] : old[name])))) {
            continue;
          }
          old_name = old[name];
          old[name] = attrs.$fetch(name);
          Opal.Enjoy.$set_accessor(dom_node, v_node, name, old_name, old[name], Opal.Enjoy['svg_mode']);
        }
      }
      if (old.length > 0) {   
        for (var oattr in old) {
          if ( !(!((attrs.$size() > 0) && attrs[name] !== undefined) && old[oattr] !== undefined)) {
            continue;
          }
          old_name = old[oattr];
          old[name] = nil;
          Opal.Enjoy.$set_accessor(dom_node, v_node, name, old_name, nil, Opal.Enjoy['svg_mode']);
        }
      }
    }
  end

  def self.diff_node_children(dom_node, vchildren, hydrating)
    %x{
      var original_children = dom_node.childNodes;
      var oc_len = original_children.length;
      var children = [];
      var keyed_len = 0;
      var min = 0;
      var children_len = 0;
      var vlen = (vchildren !== undefined) ? vchildren.$size() : 0;
      var keyed = {};
    
      // Build up a map of keyed children and an Array of unkeyed children:
      if (oc_len > 0) {
        for (var i = 0; i < oc_len; i++) {
          var child = original_children[i];
          var props = child['__prop_cache__'];
          var o_node = child['DomNode'];
          var props_key = props ? props.key : undefined;
          var chosen_key = o_node && o_node.component ? o_node.component.key : props_key;
          var key = (vlen && props) ? chosen_key : undefined;
          tv = hydrating ? child.nodeValue.trim() : true
          if (key !== undefined) {
            keyed_len++;
            keyed[key] = child
          } else if (props !== undefined || ((child.splitText !== undefined) ? tv : hydrating)) {
            children[children_len++] = child
          }
        }
      }
    
      if (vlen > 0) {
        // cache method reference for performance
        var idiff = Opal.Enjoy.$idiff;

        // if we have an empty dom_node originally, then we create the complete tree below it
        // in this case its much faster if we render in to a fragment first, and then attach that fragment to the dom
        var fragment;
        var vlen_frag = 1;
        var vlen_last = vlen - 1;
        var empty_dom_node = (dom_node.nodeValue === null);
        if (empty_dom_node && vlen > vlen_frag) fragment = document.createDocumentFragment(); // create fragment

        for (var i = 0; i < vlen; i++) {
          var vchild = vchildren[i];
          var child = undefined;
          var key = vchild['$respond_to?']('is_vnode?') ? vchild.key : undefined;
          var o_child;

          if (key !== undefined && keyed_len > 0 && keyed[key] !== undefined) {
            child = keyed[key];
            keyed[key] = undefined;
            keyed_len--;
          } else if (child === undefined && min < children_len) {
            for (var j = min; j < children_len; j++) {
              if (!(children[j] !== undefined && (children[j].nodeName === vchild.node_name || children[j].nodeName.toLowerCase() === vchild.node_name.toLowerCase()))) {
                continue;
              }
              child = children[j];
              children[j] = undefined;
              if (j === children_len) children_len--;
              if (j === min) min++;
              break;
            }
          }

          child = idiff(child, vchild);

          o_child = original_children[i]
          if (child !== undefined && child !== dom_node && child !== o_child) {
            if (o_child === undefined || o_child === null) {
              if (empty_dom_node && vlen > vlen_frag) {
                // no dom_node so we render into the fragment
                fragment.appendChild(child);
                // in case we rendered the last child in to the fragment we can finally attach the fragment
                if (i === vlen_last) dom_node.appendChild(fragment);
              } else {
                dom_node.appendChild(child);
              }
            } else if (child === o_child.nextSibling) {
              Opal.Enjoy.$remove_from_dom(o_child);
            } else {
              dom_node.insertBefore(child, );
            }
          }
        }
      }

      // remove unused keyed children
      if (keyed_len > 0) {
        for (var key in keyed) {
          if (keyed.hasOwnProperty(key)) {
            Opal.Enjoy.$recollect_node_tree(keyed[key]);
          }
        }
      }

      // remove orphaned unkeyed children
      while (min <= children_len) {
        var child = children[children_len--];
        if (child !== undefined) {
          Opal.Enjoy.$recollect_node_tree(child);
        }
      }
    }
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
  def self.idiff(dom_node, vnode, component_root = nil)
    %x{
      var out = dom_node;
      var prev_svg_mode = Opal.Enjoy['svg_mode'];
      // empty values (null, undefined, booleans) render as empty Text nodes
      if (vnode === undefined || typeof(vnode) === 'boolean') {
        vnode = '';
      }
      // Fast case: Strings & Numbers create/update Text nodes.
      if (typeof(vnode) === 'string' || typeof(vnode) === 'number') {
        // update if its already a text node
        if (dom_node !== undefined && dom_node.splitText!==undefined && dom_node.parentNode && (!dom_node.component || component_root)) {
          // istanbul ignore if Browser quirk that can't be covered: https://github.com/developit/preact/commit/fd4f21f5c45dfd75151bd27b4c217d8003aa5eb9
          if (dom_node.nodeValue !== vnode) dom_node.nodeValue = vnode;
        } else {
          // it wasn't a Text node: replace it with one and recycle the old Element
          out = document.createTextNode(vnode);
          if (dom_node !== undefined && dom_node.parentNode) dom_node.parentNode.replaceChild(out, dom_node);
          Opal.Enjoy.$recollect_node_tree(dom_node, true);
        }
        out['__prop_cache__'] = true;
      } else if (vnode['$respond_to?']('is_vnode?')) {
        var fc;
        // If the VNode represents a Component, perform a component diff:
        // Tracks entering and exiting SVG namespace when descending through the tree.
        svg_mode = vnode.node_name == 'svg' ? true : (vnode.node_name == 'foreign_object' ? false : prev_svg_mode);
        if (dom_node === undefined || (dom_node !== undefined && (dom_node.nodeName == vnode.node_name || dom_node.nodeName.toLowerCase() == vnode.node_name.toLowerCase()))) {
          if (svg_mode === true) {
            out = document.createElementNS('http://www.w3.org/2000/svg', vnode.$node_name());
          } else {
            out = document.createElement(vnode.$node_name());
          }
          // move children into the replacement node
          if (dom_node !== undefined) {
            while (dom_node.firstChild !== undefined) {
              out.appendChild(dom_node.firstChild);
            }
            // if the previous Element was mounted into the DOM, replace it inline
            if (dom_node.dom_node.parentNode) dom_node.dom_node.parentNode.replaceChild(out, dom_node.dom_node);
            // recycle the old element (skips non-Element node types)
            Opal.Enjoy.$recollect_node_tree(dom_node, true);
          }
        }

        fc = out.firstChild;
        if (fc === null) fc = undefined;
        props = (dom_node === undefined) ? {} : dom_node['__prop_cache__'];
        vchildren = vnode.children;

        if (props === undefined) {
          out['__prop_cache__'] = {};
          if (out.attributes !== undefined && out.attributes.length > 0) {
            props = Object.assign({}, out.attributes);
          } else {
            props = {};
          }
        }

        // Optimization: fast-path for elements containing a single TextNode:
        if (!Opal.Enjoy['hydrating'] && vchildren && vchildren.length == 1 && typeof(vchildren[0]) === 'string' && fc !== undefined && fc.splitText !== undefined && fc.nextSibling === undefined) {
          if (fc.nodeValue !== vchildren[0]) fc.nodeValue = vchildren[0];
        } else if (vchildren !== undefined && vchildren.length > 0 || fc !== undefined) {
          // otherwise, if there are existing or new children, diff them:
          Opal.Enjoy.$diff_node_children(out, vchildren, Opal.Enjoy['hydrating'] || props['dangerously_set_inner_html']);
        }
        Opal.Enjoy.$diff_attributes(out, vnode, props);
      }
      Opal.Enjoy['svg_mode'] = prev_svg_mode;
      return out;
    }
  end

  def self.is_named_like(dom_node, vname)
    %x{
      if (dom_node !== undefined && dom_node.nodeName !== undefined && vname !== undefined) {
        return (dom_node.nodeName == vname || dom_node.nodeName.toLowerCase() == vname.toLowerCase());
      } else {
        return false;
      }
    }
  end

  def self.ready?(&block)
    `setTimeout(function() { #{ block.call }; }, 0)`
    self
  end

  # ** Recursively recycle (or just unmount) a node and its descendants.
  #	*	@param {Node} node						DOM node to start unmount/removal from
  # *	@param {Boolean} [unmountOnly=false]	If `true`, only triggers unmount lifecycle, skips removal
  def self.recollect_node_tree(dom_node, unmount_only = false)
    if `dom_node !== undefined`
      opal_dom_node = `dom_node['DomNode']`
      if opal_dom_node && opal_dom_node.component
        # if node is owned by a Component, unmount that component (ends up recursing back here)
        opal_dom_node.component.unmount
      else
        remove_from_dom(dom_node) unless unmount_only
        remove_children(dom_node)
      end
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
     if (dom_node['DomNode']) dom_node['DomNode'].dom_node = undefined`
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
    %x{
      if (name === 'className') name = 'class';
      // ignore name == 'key'
      if (name === 'class' && !svg_mode) {
        dom_node.className = value || ''
      } else if (name === 'style') {
        if (!value || typeof(value) === 'string' || typeof(old) === 'string') dom_node.style.cssText = value || '';
        if (Array.isArray(old)) {
          for (var i = 0; i < old.legth; i++) {
            if (! (value.indexOf(old[i]) > -1)) {
              dom_node.style[old[i]] = '';
            }
          }
        }
        for (var i = 0; i < value.length; i++) {
          dom_node.style[value[i]] = (Number.isInteger(value[i]) && (!IS_NON_DIMENSIONAL.test(v)) ? value[i] + 'px' : value[i]);
        }
      } else if (name === 'dangerouslySetInnerHTML') {
        dom_node.innerHTML = value || '';
      } else if (typeof(name) === 'string' && name.substring(0,2) === 'on') {
        var name_woc = name.replace(/_capture$/, '');
        use_capture = name != name_woc;
        name = name_woc.toLowerCase().substring(2, name_woc.length);
        if (value !== undefined && value !== null) {
          if (old === undefined || old === null) dom_node.addEventListener(name, function(e) { v_node.$event_handler(e) }, use_capture);
        } else {
          dom_node.removeEventListener(name, function(e) { v_node.$event_handler(e) }, use_capture);
        }
      } else if (name !== 'list' && name !== 'type' && !svg_mode && (name in dom_node)) {
        OpalEnjoy.$set_property(dom_node, name, value ? value : '');
        if (value === undefined || value === null) dom_node.removeAttribute(name);
      } else {
        ns = svg_mode && name !== (name = name.replace(/^xlink\:?/, ''))
        if (value === undefined || value === null) {
          if (ns === true) {
            dom_node.removeAttributeNS('http://www.w3.org/1999/xlink', name.toLowerCase());
          } else {
            dom_node.removeAttribute(name);
          }
        } else {
          if (ns === true) {
            dom_node.setAttributeNS('http://www.w3.org/1999/xlink', name.toLowerCase(), value);
          } else {
            dom_node.setAttribute(name, value);
          }
        }
      }
    }
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

# frozen_string_literal: true

require 'set'

require 'kaitai/struct/visualizer/version'

module Kaitai::Struct::Visualizer
  class Node
    attr_accessor :id, :parent, :type
    attr_reader :value, :level, :pos1, :pos2, :children

    def initialize(tree, value, level, value_method = nil, pos1 = nil, pos2 = nil)
      @tree = tree
      @value = value
      @level = level
      @value_method = value_method

      unless pos1.nil? || pos2.nil?
        @pos1 = pos1
        @pos2 = pos2
      end

      @open = false
      @explored = false

      @children = []
    end

    def add(child)
      @children << child
      child.parent = self
    end

    def open?
      @open
    end

    def openable?
      !(
        @value.is_a?(Float) or
        @value.is_a?(Integer) or
        @value.is_a?(String) or
        @value.is_a?(Symbol) or
        @value == true or
        @value == false
      )
    end

    def hex?
      @value.is_a?(String)
    end

    def toggle
      if @open
        close
      else
        open
      end
    end

    def open
      return unless openable?

      explore
      @open = true if @explored
    end

    def close
      @open = false
    end

    def draw(_ui)
      print '  ' * level
      print(if @value.nil?
              '[?]'
            elsif open?
              '[-]'
            elsif openable?
              '[+]'
            else
              '[.]'
            end)
      print " #{@id}"

      pos = 2 * level + 4 + @id.length

      if open? || !openable?
        if @value.is_a?(Float) || @value.is_a?(Integer)
          print " = #{@value}"
        elsif @value.is_a?(Symbol)
          print " = #{@value}"
        elsif @value.is_a?(String)
          print ' = '
          pos += 3
          @str_mode ||= detect_str_mode
          max_len = @tree.tree_width - pos

          case @str_mode
          when :str
            v = @value.encode('UTF-8')
            s = v[0, max_len]
          when :str_esc
            v = @value.encode('UTF-8')
            s = v.inspect[0, max_len]
          when :hex
            s = first_n_bytes_dump(@value, max_len / 3 + 1)
          else
            raise "Invalid str_mode: #{@str_mode.inspect}"
          end

          s = clamp_string(s, max_len)
          print s
        elsif (@value == true) || (@value == false)
          print " = #{@value}"
        elsif @value.nil?
          print ' = null'
        elsif @value.is_a?(Array)
          printf ' (%d = 0x%x entries)', @value.size, @value.size
        elsif @value.public_methods(false).include?(:to_s)
          s = @value.to_s
          pos += 2
          max_len = @tree.tree_width - pos
          if s.is_a?(String)
            print ": #{clamp_string(s, max_len)}"
          else
            print ": #{clamp_string(s.class.to_s, max_len)}"
          end
        end
      end

      puts
    end

    def clamp_string(s, max_len)
      s ||= ''
      if s.length > max_len
        s = s[0, max_len - 1] || ''
        s += '…'
      end
      s
    end

    def first_n_bytes_dump(s, n)
      i = 0
      r = +''
      s.each_byte do |x|
        r << format('%02x ', x)
        i += 1
        break if i >= n
      end
      r
    end

    # Empirically detects a mode that would be best to show a designated string
    def detect_str_mode
      if @value.encoding == Encoding::ASCII_8BIT
        :hex
      else
        :str_esc
      end
    end

    def io
      return @io if @io

      if @parent.nil?
        @io = @value._io
      else
        obj = @parent
        obj = obj.parent until obj.value.respond_to?(:_io)
        @io = obj.value._io
      end
    end

    def explore
      return if @explored

      if @value.nil?
        @value = @parent.value.send(@value_method)
        clean_id = @id[0] == '@' ? @id[1..-1] : @id
        debug_el = @parent.value._debug[clean_id]
        # raise "Unable to get debugging aid for: #{@parent.value._debug.inspect} using ID '#{clean_id}'" unless debug_el
        if debug_el
          @pos1 = debug_el[:start]
          @pos2 = debug_el[:end]
        end
      end

      @explored = true

      if @value.is_a?(Float) ||
         @value.is_a?(Integer) ||
         @value.is_a?(String) ||
         (@value == true) ||
         (@value == false) ||
         @value.nil? ||
         @value.is_a?(Symbol)
        clean_id = @id[0] == '@' ? @id[1..-1] : @id
        debug_el = @parent.value._debug[clean_id]
        # raise "Unable to get debugging aid for: #{@parent.value._debug.inspect} using ID '#{clean_id}'" unless debug_el
        if debug_el
          @pos1 = debug_el[:start]
          @pos2 = debug_el[:end]
        end
      elsif @value.is_a?(Array)
        # Bail out early for empty array: it doesn't have proper
        # debugging aids structure anyway
        return if @value.empty?

        clean_id = @id[0] == '@' ? @id[1..-1] : @id
        debug_el = @parent.value._debug[clean_id]
        # raise "Unable to get debugging aid for array: #{@parent.value._debug.inspect} using ID '#{clean_id}'" unless debug_el

        aid = (debug_el && debug_el[:arr]) || {}
        # raise "Unable to get debugging aid for array: #{debug_el.inspect}" unless aid

        max_val_digits = @value.size.to_s.size
        fmt = "%#{max_val_digits}d"

        @value.each_with_index do |el, i|
          aid_el = aid[i] || {}
          n = Node.new(@tree, el, level + 1, nil, aid_el[:start], aid_el[:end])
          n.id = format(fmt, i)
          add(n)
        end
      else
        # Gather seq attributes
        @value.class::SEQ_FIELDS.each do |k|
          el = @value.instance_eval("@#{k}", __FILE__, __LINE__)
          aid = @value._debug[k]
          if aid
            aid_s = aid[:start]
            aid_e = aid[:end]
          else
            # raise "Unable to get debugging aid for '#{k}'"
            aid_s = nil
            aid_e = nil
          end
          next if el.nil?

          n = Node.new(@tree, el, level + 1, nil, aid_s, aid_e)
          n.id = k
          n.type = :seq
          add(n)
        end

        attrs = Set.new(@value.class::SEQ_FIELDS)

        # Gather instances
        prop_meths = @value.public_methods(false)
        prop_meths.each do |meth|
          k = meth.to_s
          # NB: we don't need to consider `_unnamed*` attributes here
          # (https://github.com/kaitai-io/kaitai_struct/issues/1064) because
          # only `seq` fields can be unnamed, not `instances`
          next if k.start_with?('_') || attrs.include?(k) || meth == :to_s

          n = Node.new(@tree, nil, level + 1, meth)
          n.id = k
          n.type = :instance
          add(n)
        end
      end
    end

    # Determine total height of an element, including all children if it's open and visible
    def height
      if @open
        r = 1
        @children.each { |n| r += n.height }
        r
      else
        1
      end
    end

    # Find out last (deepest) descendant of current node
    def last_descendant
      n = self
      n = n.children.last while n.open?
      n
    end
  end
end

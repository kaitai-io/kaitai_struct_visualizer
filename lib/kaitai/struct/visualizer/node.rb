# frozen_string_literal: true

require 'set'

require 'kaitai/struct/visualizer/version'

module Kaitai::Struct::Visualizer
  class Node
    attr_accessor :id
    attr_reader :value
    attr_reader :level
    attr_reader :pos1
    attr_reader :pos2
    attr_reader :children
    attr_accessor :parent
    attr_accessor :type

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
      _ui.print '  ' * level
      _ui.print(if @value.nil?
              '[?]'
            elsif open?
              '[-]'
            elsif openable?
              '[+]'
            else
              '[.]'
            end)
      _ui.print " #{@id}"

      pos = 2 * level + 4 + @id.length

      if open? || !openable?
        if @value.is_a?(Float) || @value.is_a?(Integer)
          _ui.print " = #{@value}"
        elsif @value.is_a?(Symbol)
          _ui.print " = #{@value}"
        elsif @value.is_a?(String)
          _ui.print ' = '
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

          s ||= ''
          if s.length > max_len
            s = s[0, max_len - 1] || ''
            s += '…'
          end
          _ui.print s
        elsif (@value == true) || (@value == false)
          _ui.print " = #{@value}"
        elsif @value.nil?
          _ui.print ' = null'
        elsif @value.is_a?(Array)
          _ui.printf ' (%d = 0x%x entries)', @value.size, @value.size
        end
      end

      _ui.puts
    end

    def first_n_bytes_dump(s, n)
      i = 0
      r = ''.dup
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
        raise "Unable to get debugging aid for array: #{@parent.value._debug.inspect} using ID '#{clean_id}'" unless debug_el

        aid = debug_el[:arr]
        raise "Unable to get debugging aid for array: #{debug_el.inspect}" unless aid

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
        common_meths = Set.new
        @value.class.ancestors.each do |cl|
          next if cl == @value.class

          common_meths.merge(cl.instance_methods)
        end
        inst_meths = Set.new(@value.public_methods) - common_meths
        inst_meths.each do |meth|
          k = meth.to_s
          next if k =~ /^_/ || attrs.include?(k)

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

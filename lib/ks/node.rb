# coding: utf-8
require 'set'

class Node
  attr_accessor :id
  attr_reader :value
  attr_reader :level
  attr_reader :children
  attr_accessor :parent

  def initialize(value, level, value_method = nil)
    @value = value
    @level = level
    @value_method = value_method

    @open = false
    @explored = false

    @children = []
  end

  def add(child)
    @children << child
    child.parent = self
  end

  def open?; @open; end

  def openable?
    not (@value.is_a?(Fixnum) or @value.is_a?(String) or @value.is_a?(Symbol))
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

  def draw(ui)
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

    if @value.is_a?(Fixnum)
      print " = #{@value}"
    elsif @value.is_a?(Symbol)
      print " = #{@value}"
    elsif @value.is_a?(String)
      print ' = '
      pos += 3
      @str_mode = detect_str_mode unless @str_mode
      case @str_mode
      when :str
        s = @value
      when :str_esc
        s = @value.inspect
      when :hex
        s = @value.bytes.map { |x| sprintf '%02X', x }.join(' ')
      else
        raise "Invalid str_mode: #{@str_mode.inspect}"
      end
      max_len = ui.cols - pos
      if s.length > max_len
        s = s[0, max_len - 1]
        s += '…'
      end
      print s
    elsif @value.is_a?(Array)
      printf ' (%d = 0x%x entries)', @value.size, @value.size
    end

    puts
  end

  ##
  # Empirically detects a mode that would be best to show a designated string
  def detect_str_mode
    if @value.encoding == Encoding::ASCII_8BIT
      :hex
    else
      :str_esc
    end
  end

  def explore
    return if @explored

    if @value.nil?
      @value = @parent.value.send(@value_method)
    end

    if @value.is_a?(Fixnum) or @value.is_a?(String) or @value.is_a?(Symbol)
      # do nothing else
    elsif @value.is_a?(Array)
      @value.each_with_index { |el, i|
        n = Node.new(el, level + 1)
        n.id = i.to_s
        add(n)
      }
    else
      # Gather seq attributes
      attrs = Set.new
      @value.instance_variables.each { |k|
        k = k.to_s
        next if k =~ /^@_/
        el = @value.instance_eval(k)
        n = Node.new(el, level + 1)
        n.id = k
        add(n)
        attrs << k.gsub(/^@/, '')
      }

      # Gather instances
      common_meths = Set.new
      @value.class.ancestors.each { |cl|
        next if cl == @value.class
        common_meths.merge(cl.instance_methods)
      }
      inst_meths = Set.new(@value.public_methods) - common_meths
      inst_meths.each { |meth|
        k = meth.to_s
        next if k =~ /^_/ or attrs.include?(k)
        n = Node.new(nil, level + 1, meth)
        n.id = k
        add(n)
      }
    end
    @explored = true
  end
end

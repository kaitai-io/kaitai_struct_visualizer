# coding: utf-8
class Node
  attr_accessor :id
  attr_reader :value
  attr_reader :level
  attr_reader :children

  def initialize(value, level)
    @value = value
    @level = level

    @open = false
    @explored = false

    @children = []
  end

  def add(child)
    @children << child
  end

  def open?; @open; end
  
  def openable?
    not (@value.is_a?(Fixnum) or @value.is_a?(String))      
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
    @open = true
  end

  def close
    @open = false
  end

  def draw(ui)
    print '  ' * level
    print(if open?
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
    elsif @value.is_a?(String)
      print ' = '
      @str_mode = detect_str_mode unless @str_mode
      case @str_mode
      when :str
        s = @value
      when :str_esc
        s = @value.inspect
      when :hex
        s = s.bytes.map { |x| sprintf '%02X' }.join(' ')
      else
        raise "Invalid str_mode: #{@str_mode.inspect}"
      end
      max_len = ui.cols - pos
      if s.length > max_len
        s = s[0, max_len - 1]
        s += '…'
      end
      print s
    end

    puts
  end

  ##
  # Empirically detects a mode that would be best to show a designated string
  def detect_str_mode
    :str
  end

  def explore
    return if @explored
    if @value.is_a?(Fixnum) or @value.is_a?(String)
    # do nothing else
    elsif @value.is_a?(Array)
      @value.each_with_index { |el, i|
        n = Node.new(el, level + 1)
        n.id = i.to_s
        add(n)
      }
    else
      @value.instance_variables.each { |k|
        k = k.to_s
        next if k =~ /^@_/
        el = @value.instance_eval(k)
        n = Node.new(el, level + 1)
        n.id = k
        add(n)
      }
    end
    @explored = true
  end
end

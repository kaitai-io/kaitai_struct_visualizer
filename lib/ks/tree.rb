require 'ks/node'

class Tree
  def initialize(ui, st)
    @ui = ui
    @st = st
    @root = Node.new(st, 0)
    @root.id = '[root]'
    @max_ln = @ui.rows - 3

    @cur_line = 0
    @cur_shift = 0
  end

  def run
    c = nil
    loop {
      redraw
      #puts "keypress: #{c.inspect}"
      c = @ui.read_char_mapped
      case c
      when :up_arrow
        @cur_line -= 1
        @cur_line = 0 if @cur_line < 0
      when :down_arrow
        @cur_line += 1
      when :right_arrow
        if @cur_node.openable?
          if @cur_node.open?
            @cur_line += 1
          else
            @cur_node.open
          end
        end
      when :enter
        @cur_node.toggle
      when 'q'
        return
      end

      if @cur_line - @cur_shift < 0
        @cur_shift = @cur_line
      end
      if @cur_line - @cur_shift > @max_ln
        @cur_shift = @cur_line - @max_ln
      end
    }
  end

  def redraw
    @ui.clear
    @ln = 0
    draw_rec(@root)
  end

  def draw_rec(n)
    scr_ln = @ln - @cur_shift
    return if scr_ln > @max_ln
    if @ln == @cur_line
      @ui.bg_color = 7
      @ui.fg_color = 0
      @cur_node = n
    end
    n.draw(@ui) if scr_ln >= 0
    @ui.reset_colors if @ln == @cur_line
    @ln += 1
    if n.open?
      n.children.each { |ch|
        draw_rec(ch)
        break if scr_ln > @max_ln
      }
    end
  end

  def self.explore_object(obj, level)
    root = Node.new(obj, level)
    if obj.is_a?(Fixnum) or obj.is_a?(String)
      # do nothing else
    elsif obj.is_a?(Array)
      root = Node.new(obj, level)
      obj.each_with_index { |el, i|
        n = explore_object(el, level + 1)
        n.id = i
        root.add(n)
      }
    else
      root = Node.new(obj, level)
      obj.instance_variables.each { |k|
        k = k.to_s
        next if k =~ /^@_/
        el = obj.instance_eval(k)
        n = explore_object(el, level + 1)
        n.id = k
        root.add(n)
      }
    end
    root
  end
end

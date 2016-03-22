require 'ks/node'
require 'ks/hex_viewer'
require 'benchmark'

class Tree
  def initialize(ui, st)
    @ui = ui
    @st = st
    @root = Node.new(st, 0)
    @root.id = '[root]'
    @max_scr_ln = @ui.rows - 3

    @hv_shift_x = @ui.cols - HexViewer.line_width - 1

    @st._io.seek(0)
    full_buf = @st._io.read_bytes_full
    @hv = HexViewer.new(ui, full_buf, @hv_shift_x, self)

    @cur_line = 0
    @cur_shift = 0
    @do_exit = false
  end

  def run
    c = nil
    loop {
      t = redraw

      thv = Benchmark.realtime {
        @hv.redraw
        @hv.highlight(@cur_node.pos1, @cur_node.pos2)
      }

      @ui.goto(0, @max_scr_ln + 1)
      printf "all: %d, tree: %d, tree_draw: %d, hexview: %d, ln: %d, ", (t + thv) * 1e6, t * 1e6, @draw_time * 1e6, thv * 1e6, @ln
      puts "highlight = #{@cur_node.pos1}..#{@cur_node.pos2}"
      #puts "keypress: #{c.inspect}"

      begin
        process_keypress
      rescue EOFError => e
        @ui.message_box_exception(e)
      rescue KaitaiStream::UnexpectedDataError => e
        @ui.message_box_exception(e)
      end

      return if @do_exit

      if @cur_line
        @cur_line = 0 if @cur_line < 0

        if @cur_line - @cur_shift < 0
          @cur_shift = @cur_line
        end
        if @cur_line - @cur_shift > @max_scr_ln
          @cur_shift = @cur_line - @max_scr_ln
        end
      end
    }
  end

  def process_keypress
    c = @ui.read_char_mapped
    case c
    when :up_arrow
      @cur_line -= 1
      @cur_node = nil
    when :down_arrow
      @cur_line += 1
      @cur_node = nil
    when :left_arrow
      if @cur_node.open?
        @cur_node.close
      else
        @cur_line = nil
        @cur_node = @cur_node.parent
      end
    when :right_arrow
      if @cur_node.openable?
        if @cur_node.open?
          @cur_line += 1
          @cur_node = nil
        else
          @cur_node.open
        end
      end
    when :home
      @cur_line = @cur_shift = 0
      @cur_node = nil
    when :pg_up
      @cur_line -= 20
      @cur_node = nil
    when :pg_dn
      @cur_line += 20
      @cur_node = nil
    when :enter
      if @cur_node.hex?
        @ui.clear
        hv = HexViewer.new(@ui, @cur_node.value)
        hv.redraw
        hv.run
        @ui.clear
        redraw
      else
        @cur_node.toggle
      end
    when :tab
      unless @cur_node.pos1.nil?
        if (@hv.addr < @cur_node.pos1) or (@hv.addr >= @cur_node.pos2)
          @hv.addr = @cur_node.pos1
        end
      end
      @hv.run
    when 'q'
      @do_exit = true
    end
  end

  def redraw
    @draw_time = 0
    Benchmark.realtime {
      @ui.clear
      @ln = 0
      draw_rec(@root)
    }
  end

  def draw_rec(n)
    scr_ln = @ln - @cur_shift
    return if @cur_node and scr_ln > @max_scr_ln

    if @ln == @cur_line
      # Seeking cur_node by cur_line
      @cur_node = n
      @ui.bg_color = 7
      @ui.fg_color = 0
    elsif @cur_node == n
      # Seeking cur_line by cur_node
      @cur_line = @ln
      @ui.bg_color = 7
      @ui.fg_color = 0
    end

    @draw_time += Benchmark.realtime {
#      n.draw(@ui) if scr_ln >= 0
      n.draw(@ui) if scr_ln >= 0 and scr_ln <= @max_scr_ln
    }

    @ui.reset_colors if @ln == @cur_line
    @ln += 1
    if n.open?
      n.children.each { |ch|
        draw_rec(ch)
        break if scr_ln > @max_scr_ln
      }
    end
  end

  def do_exit
    @do_exit = true
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

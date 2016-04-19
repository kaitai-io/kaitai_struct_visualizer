require 'benchmark'

require 'kaitai/struct/visualizer/version'
require 'kaitai/struct/visualizer/node'
require 'kaitai/struct/visualizer/hex_viewer'

module Kaitai::Struct::Visualizer
class Tree
  def initialize(ui, st)
    @ui = ui
    @st = st
    @root = Node.new(self, st, 0)
    @root.id = '[root]'
    @max_scr_ln = @ui.rows - 3

    @hv_shift_x = @ui.cols - HexViewer.line_width - 1

    @cur_io = nil
    @hv = HexViewer.new(ui, nil, @hv_shift_x, self)
    @hv_hidden = false

    @cur_line = 0
    @cur_shift = 0
    @do_exit = false
  end

  def run
    c = nil
    loop {
      t = redraw

      if @cur_node.nil? and not @cur_line.nil?
        # gone beyond the end of the tree
        @cur_line = @root.height - 1
        clamp_cursor
        redraw
      end

      raise '@cur_line is undetermined' if @cur_line.nil?
      raise '@cur_node is undetermined' if @cur_node.nil?

      thv = Benchmark.realtime {
        unless @hv_hidden
          hv_update_io

          unless @cur_node.pos1.nil?
            if (@hv.addr < @cur_node.pos1) or (@hv.addr >= @cur_node.pos2)
              @hv.addr = @cur_node.pos1
              @hv.ensure_visible
            end
          end

          @hv.redraw
          regs = highlight_regions(4)
          @hv.highlight(regs)
        end
      }

      @ui.goto(0, @max_scr_ln + 1)
      printf "all: %d, tree: %d, tree_draw: %d, hexview: %d, ln: %d, ", (t + thv) * 1e6, t * 1e6, @draw_time * 1e6, thv * 1e6, @ln
      puts "highlight = #{@cur_node.pos1}..#{@cur_node.pos2}"
      #puts "keypress: #{c.inspect}"

      begin
        process_keypress
      rescue EOFError => e
        @ui.message_box_exception(e)
      rescue Kaitai::Struct::Stream::UnexpectedDataError => e
        @ui.message_box_exception(e)
      end

      return if @do_exit

      clamp_cursor
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
        par = @cur_node.parent
        if par
          @cur_line = nil
          @cur_node = par
        end
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
    when :end
      @cur_line = @root.height - 1
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
      @hv.run
    when 'H'
      @hv_hidden = !@hv_hidden
      @ui.clear
      redraw
    when 'q'
      @do_exit = true
    end
  end

  def clamp_cursor
    if @cur_line
      @cur_line = 0 if @cur_line < 0

      if @cur_line - @cur_shift < 0
        @cur_shift = @cur_line
      end
      if @cur_line - @cur_shift > @max_scr_ln
        @cur_shift = @cur_line - @max_scr_ln
      end
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
      @ui.bg_color = :gray
      @ui.fg_color = :black
    elsif @cur_node == n
      # Seeking cur_line by cur_node
      @cur_line = @ln
      @ui.bg_color = :gray
      @ui.fg_color = :black
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

  def hv_update_io
    io = @cur_node.io
    if io != @cur_io
      @cur_io = io
      io.seek(0)
      buf = io.read_bytes_full
      @hv.buf = buf

#      @hv.redraw
    end
  end

  def highlight_regions(max_levels)
    node = @cur_node
    r = []
    max_levels.times { |i|
      return r if node.nil?
      r << [node.pos1, node.pos2]
      node = node.parent
    }
    r
  end

  def tree_width
    if @hv_hidden
      @ui.cols
    else
      @hv_shift_x
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
end

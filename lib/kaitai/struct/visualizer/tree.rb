# frozen_string_literal: true

require 'benchmark'

require 'kaitai/struct/visualizer/version'
require 'kaitai/struct/visualizer/node'
require 'kaitai/struct/visualizer/hex_viewer'
require 'kaitai/struct/visualizer/ks_error_matcher'

module Kaitai::Struct::Visualizer
  class Tree
    def initialize(ui, st)
      @ui = ui
      @st = st
      @root = Node.new(self, st, 0)
      @root.id = '[root]'

      @cur_io = nil
      @hv = HexViewer.new(ui, nil, self)
      @hv_hidden = false

      recalc_sizes

      @cur_line = 0
      @cur_shift = 0
      @do_exit = false

      @ui.on_resize = proc { |redraw_needed|
        recalc_sizes
        redraw      if redraw_needed
        @hv.redraw  if redraw_needed
      }
    end

    def recalc_sizes
      @max_scr_ln = @ui.rows - 3
      @hv.shift_x = @ui.cols - HexViewer.line_width - 1
    end

    def run
      loop do
        t = redraw

        if @cur_node.nil? && !@cur_line.nil?
          # gone beyond the end of the tree
          @cur_line = @root.height - 1
          clamp_cursor
          redraw
        end

        raise '@cur_line is undetermined' if @cur_line.nil?
        raise '@cur_node is undetermined' if @cur_node.nil?

        thv = Benchmark.realtime do
          unless @hv_hidden
            hv_update_io

            if !@cur_node.pos1.nil? && ((@hv.addr < @cur_node.pos1) || (@hv.addr >= @cur_node.pos2))
              @hv.addr = @cur_node.pos1
              @hv.ensure_visible
            end

            @hv.redraw
            regs = highlight_regions(4)
            @hv.highlight(regs)
          end
        end

        @ui.goto(0, @max_scr_ln + 1)
        printf 'all: %d, tree: %d, tree_draw: %d, hexview: %d, ln: %d, ', (t + thv) * 1e6, t * 1e6, @draw_time * 1e6, thv * 1e6, @ln
        puts "highlight = #{@cur_node.pos1}..#{@cur_node.pos2}"
        # puts "keypress: #{c.inspect}"

        begin
          process_keypress
        rescue Kaitai::Struct::Visualizer::KSErrorMatcher => e
          @ui.message_box_exception(e)
        end

        return if @do_exit

        clamp_cursor
      end
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
      return unless @cur_line

      @cur_line = 0 if @cur_line.negative?

      @cur_shift = @cur_line if (@cur_line - @cur_shift).negative?
      @cur_shift = @cur_line - @max_scr_ln if (@cur_line - @cur_shift) > @max_scr_ln
    end

    def redraw
      @draw_time = 0
      Benchmark.realtime do
        @ui.clear
        @ln = 0
        draw_rec(@root)
      end
    end

    def draw_rec(n)
      scr_ln = @ln - @cur_shift
      return if @cur_node && (scr_ln > @max_scr_ln)

      if @ln == @cur_line
        # Seeking cur_node by cur_line
        @cur_node = n
        @ui.bg_color = :white
        @ui.fg_color = :black
      elsif @cur_node == n
        # Seeking cur_line by cur_node
        @cur_line = @ln
        @ui.bg_color = :white
        @ui.fg_color = :black
      end

      @draw_time += Benchmark.realtime do
        # n.draw(@ui) if scr_ln >= 0
        n.draw(@ui) if (scr_ln >= 0) && (scr_ln <= @max_scr_ln)
      end

      @ui.reset_colors if @ln == @cur_line
      @ln += 1

      return unless n.open?

      n.children.each do |ch|
        draw_rec(ch)
        break if scr_ln > @max_scr_ln
      end
    end

    def do_exit
      @do_exit = true
    end

    def hv_update_io
      io = @cur_node.io
      return unless io != @cur_io

      @cur_io = io
      io.seek(0)
      buf = io.read_bytes_full
      @hv.buf = buf

      # @hv.redraw
    end

    def highlight_regions(max_levels)
      node = @cur_node
      r = []
      max_levels.times do |_i|
        return r if node.nil?

        r << [node.pos1, node.pos2]
        node = node.parent
      end
      r
    end

    def tree_width
      if @hv_hidden
        @ui.cols
      else
        @hv.shift_x
      end
    end
  end
end

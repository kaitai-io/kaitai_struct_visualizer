# frozen_string_literal: true

require 'kaitai/struct/visualizer/version'

module Kaitai::Struct::Visualizer
  class HexViewer
    attr_accessor :shift_x

    def initialize(ui, buf, tree = nil)
      @ui = ui
      @buf = buf
      @shift_x = 0
      @tree = tree

      @embedded = !tree.nil?
      @max_scr_ln = @ui.rows - 3

      @addr = 0
      @scroll_y = 0
      reset_cur
      raise if @cur_x.nil?
    end

    attr_writer :buf

    attr_reader :addr

    def addr=(a)
      @addr = a
      reset_cur
    end

    def reset_cur
      @cur_y = addr_to_row(@addr)
      @cur_x = addr_to_col(@addr)
    end

    def highlight(regions)
      highlight_hide
      @hl_regions = regions
      highlight_show
    end

    def ensure_visible
      scr_y = row_to_scr(@cur_y)
      if scr_y.negative?
        @scroll_y = @cur_y
        redraw
        highlight_show
      elsif scr_y > @max_scr_ln
        @scroll_y = @cur_y - @max_scr_ln
        redraw
        highlight_show
      end
    end

    def run
      c = nil
      loop do
        @ui.goto(0, @max_scr_ln + 1)
        printf '%08x (%d, %d)', @addr, @cur_x, @cur_y

        @ui.goto(col_to_col_char(@cur_x), row_to_scr(@cur_y))
        c = @ui.read_char_mapped
        case c
        when :tab
          return if @embedded
        when :left_arrow
          if @addr.positive?
            @addr -= 1
            @cur_x -= 1
            if @cur_x.negative?
              @cur_y -= 1
              @cur_x = PER_LINE - 1
            end
          end
        when :right_arrow
          if @addr < @buf.size
            @addr += 1
            @cur_x += 1
            if @cur_x >= PER_LINE
              @cur_y += 1
              @cur_x = 0
            end
          end
        when :up_arrow
          @addr -= PER_LINE
          @cur_y -= 1
          clamp_cursor
        when :down_arrow
          @addr += PER_LINE
          @cur_y += 1
          clamp_cursor
        when :pg_dn
          @addr += PER_LINE * PAGE_ROWS
          @cur_y += PAGE_ROWS
          clamp_cursor
        when :pg_up
          @addr -= PER_LINE * PAGE_ROWS
          @cur_y -= PAGE_ROWS
          clamp_cursor
        when :home
          if @cur_x.zero?
            @addr = 0
            @cur_y = 0
          else
            @addr -= @cur_x
            @cur_x = 0
          end
          clamp_cursor
        when :end
          if @cur_x == PER_LINE - 1
            @addr = @buf.size - 1
            reset_cur
          else
            @addr = @addr - @cur_x + PER_LINE - 1
            @cur_x = PER_LINE - 1
          end
          clamp_cursor
        when 'w'
          fn = @ui.input_str('Write buffer to file', 'Filename')
          File.open(fn, 'w') do |out|
            out.write(@buf)
          end
          @ui.clear
          redraw
        when 'q'
          @tree&.do_exit
          return
        end

        ensure_visible
      end
    end

    def clamp_cursor
      if @addr.negative?
        @addr = 0
        @cur_x = 0
        @cur_y = 0
      elsif @addr >= @buf.size
        @addr = @buf.size - 1
        reset_cur
      end
    end

    PER_LINE = 16
    PER_GROUP = 4
    PAGE_ROWS = 20
    FMT = "%08x: %-#{PER_LINE * 3}s| %-#{PER_LINE}s\n"

    def self.line_width
      # 8 + 2 + 3 * PER_LINE + 2 + PER_LINE
      12 + 4 * PER_LINE
    end

    def col_to_col_hex(c)
      # 8 + 2 + 3 * c
      @shift_x + 10 + 3 * c
    end

    def col_to_col_char(c)
      # 8 + 2 + 3 * PER_LINE + 2
      @shift_x + 12 + 3 * PER_LINE + c
    end

    def row_to_scr(r)
      r - @scroll_y
    end

    def redraw
      i = row_col_to_addr(@scroll_y, 0)
      row = 0

      while row <= @max_scr_ln
        line = @buf[i, PER_LINE]
        return unless line

        @ui.goto(@shift_x, row)

        hex = line.bytes.map { |x| format('%02x', x) }.join(' ')
        char = line.bytes.map { |x| byte_to_display_char(x) }.join

        printf FMT, i, hex, char
        i += PER_LINE
        row += 1
      end
    end

    def each_highlight_region
      return if @hl_regions.nil?

      n = @hl_regions.size
      (n - 1).downto(0).each do |i|
        p1 = @hl_regions[i][0]
        p2 = @hl_regions[i][1]
        yield i, p1, p2 unless p1.nil?
      end
    end

    def highlight_hide
      each_highlight_region do |_i, p1, p2|
        highlight_draw(p1, p2)
      end
    end

    def highlight_show
      each_highlight_region do |i, p1, p2|
        @ui.bg_color = @ui.highlight_colors[i]
        @ui.fg_color = :black
        highlight_draw(p1, p2)
      end
      @ui.reset_colors
    end

    def highlight_draw(p1, p2)
      r = row_to_scr(addr_to_row(p1))
      return if r > @max_scr_ln

      if r.negative?
        c = 0
        r = 0
        i = row_col_to_addr(@scroll_y, 0)
        return if i >= p2
      else
        c = addr_to_col(p1)
        i = p1
      end

      highlight_draw_hex(r, c, i, p2)
      highlight_draw_char(r, c, i, p2)
    end

    def highlight_draw_hex(r, c, i, p2)
      @ui.goto(col_to_col_hex(c), r)
      while i < p2
        v = byte_at(i)
        return if v.nil?

        printf('%02x ', v)
        c += 1
        if c >= PER_LINE
          c = 0
          r += 1
          return if r > @max_scr_ln

          @ui.goto(col_to_col_hex(c), r)
        end
        i += 1
      end
    end

    def highlight_draw_char(r, c, i, p2)
      @ui.goto(col_to_col_char(c), r)

      while i < p2
        v = byte_at(i)
        return if v.nil?

        print byte_to_display_char(v)
        c += 1
        if c >= PER_LINE
          c = 0
          r += 1
          return if r > @max_scr_ln

          @ui.goto(col_to_col_char(c), r)
        end
        i += 1
      end
    end

    def byte_at(i)
      v = @buf[i]
      if v.nil?
        nil
      else
        v.ord
      end
    end

    def byte_to_display_char(x)
      if (x < 0x20) || (x >= 0x7f)
        '.'
      else
        x.chr
      end
    end

    def addr_to_row(addr)
      addr / PER_LINE
    end

    def addr_to_col(addr)
      addr % PER_LINE
    end

    def row_col_to_addr(row, col)
      row * PER_LINE + col
    end
  end
end

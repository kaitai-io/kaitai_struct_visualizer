class HexViewer
  def initialize(ui, buf, shift_x = 0, tree = nil)
    @ui = ui
    @buf = buf
    @shift_x = shift_x
    @tree = tree

    @embedded = not(tree.nil?)
    @max_scr_ln = @ui.rows - 3

    @addr = 0
    @scroll_y = 0
    reset_cur
    raise if @cur_x.nil?
  end

  def addr; @addr; end
  def addr=(a)
    @addr = a
    reset_cur
  end

  def reset_cur
    @cur_y = addr_to_row(@addr)
    @cur_x = addr_to_col(@addr)
  end

  def highlight(p1, p2)
    highlight_hide
    @hl_pos1 = p1
    @hl_pos2 = p2
    highlight_show
  end

  def ensure_visible
    scr_y = row_to_scr(@cur_y)
    if scr_y < 0
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
    loop {
      @ui.goto(0, @max_scr_ln + 1)
      printf "%06x (%d, %d)", @addr, @cur_x, @cur_y

      @ui.goto(col_to_col_char(@cur_x), row_to_scr(@cur_y))
      c = @ui.read_char_mapped
      case c
      when :tab
        return if @embedded
      when :left_arrow
        if @addr > 0
          @addr -= 1
          @cur_x -= 1
          if @cur_x < 0
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
        if @addr < 0
          @addr = 0
          @cur_x = 0
          @cur_y = 0
        else
          @cur_y -= 1
        end
      when :down_arrow
        @addr += PER_LINE
        if @addr >= @buf.size
          @addr = @buf.size - 1
          reset_cur
        else
          @cur_y += 1
        end
      when 'q'
        @tree.do_exit if @tree
        return
      end

      ensure_visible
    }
  end

  PER_LINE = 16
  PER_GROUP = 4
  FMT = "%06x: %-#{PER_LINE * 3}s| %s\n"

  def self.line_width
    #6 + 2 + 3 * PER_LINE + 2 + PER_LINE
    10 + 4 * PER_LINE
  end

  def col_to_col_hex(c)
    #6 + 2 + 3 * c
    @shift_x + 8 + 3 * c
  end

  def col_to_col_char(c)
    #6 + 2 + 3 * PER_LINE + 2
    @shift_x + 10 + 3 * PER_LINE + c
  end

  def row_to_scr(r)
    r - @scroll_y
  end

  def redraw
    i = row_col_to_addr(@scroll_y, 0)
    row = 0

    while row <= @max_scr_ln do
      line = @buf[i, PER_LINE]
      return unless line

      @ui.goto(@shift_x, row)

      hex = line.bytes.map { |x| sprintf('%02x', x) }.join(' ')
      char = line.bytes.map { |x| byte_to_display_char(x) }.join

      printf FMT, i, hex, char
      i += PER_LINE
      row += 1
    end
  end

  def highlight_hide
    highlight_draw unless @hl_pos1.nil?
  end

  def highlight_show
    unless @hl_pos1.nil?
      @ui.bg_color = 7
      @ui.fg_color = 0
      highlight_draw
      @ui.reset_colors
    end
  end

  def highlight_draw
    r = row_to_scr(addr_to_row(@hl_pos1))
    return if r > @max_scr_ln
    if r < 0
      c = 0
      r = 0
      i = row_col_to_addr(@scroll_y, 0)
      return if i >= @hl_pos2
    else
      c = addr_to_col(@hl_pos1)
      i = @hl_pos1
    end

    highlight_draw_hex(r, c, i)
    highlight_draw_char(r, c, i)
  end

  def highlight_draw_hex(r, c, i)
    @ui.goto(col_to_col_hex(c), r)
    while i < @hl_pos2
      printf('%02x ', @buf[i].ord)
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

  def highlight_draw_char(r, c, i)
    @ui.goto(col_to_col_char(c), r)

    while i < @hl_pos2
      print byte_to_display_char(@buf[i].ord)
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

  def byte_to_display_char(x)
    if x < 0x20 or x >= 0x7f
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

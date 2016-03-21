class HexViewer
  def initialize(ui, buf, shift_x = 0, tree = nil)
    @ui = ui
    @buf = buf
    @shift_x = shift_x
    @tree = tree

    @embedded = not(tree.nil?)
    @max_scr_ln = @ui.rows - 3

    @addr = 0
    reset_cur
    raise if @cur_x.nil?
  end

  def addr; @addr; end
  def addr=(a)
    @addr = a
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

  def run
    c = nil
    loop {
      @ui.goto(col_to_col_char(@cur_x), @cur_y)
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
        @tree.do_exit
        return
      end
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

  def redraw
    i = 0
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
    unless @hl_pos1.nil?
      highlight_draw_hex
      highlight_draw_char
    end
  end

  def highlight_show
    unless @hl_pos1.nil?
      @ui.bg_color = 7
      @ui.fg_color = 0
      highlight_draw_hex
      highlight_draw_char
      @ui.reset_colors
    end
  end

  def highlight_draw_hex
    r = addr_to_row(@hl_pos1)
    c = addr_to_col(@hl_pos1)
    i = @hl_pos1

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

  def highlight_draw_char
    r = addr_to_row(@hl_pos1)
    c = addr_to_col(@hl_pos1)
    i = @hl_pos1

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
    if x < 0x20 or x > 0x7f
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
end

class HexViewer
  def initialize(ui, buf, shift_x = 0)
    @ui = ui
    @buf = buf
    @shift_x = shift_x

    @max_scr_ln = @ui.rows - 3
  end

  def run
    c = nil
    loop {
      @ui.clear
      redraw
      c = @ui.read_char_mapped
      case c
      when 'q'
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

  def redraw
    i = 0
    row = 0

    while row <= @max_scr_ln do
      line = @buf[i, PER_LINE]
      return unless line

      @ui.goto(@shift_x, row)

      hex = line.bytes.map { |x| sprintf('%02x', x) }.join(' ')
      char = line.bytes.map { |x|
        if x < 0x20
          '.'
        else
          x.chr
        end
      }.join

      printf FMT, i, hex, char
      i += PER_LINE
      row += 1
    end
  end
end

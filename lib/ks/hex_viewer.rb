class HexViewer
  def initialize(ui, buf)
    @ui = ui
    @buf = buf
    @max_scr_ln = @ui.rows - 3
  end

  def run
    c = nil
    loop {
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
  FMT = "%-#{PER_LINE * 3}s| %s\n"

  def redraw
    @ui.clear

    i = 0
    row = 0

    while row <= @max_scr_ln do
      line = @buf[i, PER_LINE]
      return unless line

      hex = line.bytes.map { |x| sprintf('%02x', x) }.join(' ')
      char = line.bytes.map { |x|
        if x < 0x20
          '.'
        else
          x.chr
        end
      }.join

      printf FMT, hex, char
      i += PER_LINE
      row += 1
    end
  end
end

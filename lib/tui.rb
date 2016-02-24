require 'io/console'

class TUI
  attr_reader :cols
  attr_reader :rows

  def initialize
    @cols = `tput cols`.to_i
    @rows = `tput lines`.to_i

    @seq_clear = `tput clear`
    @seq_sgr0 = `tput sgr0`
  end

  def clear
    print @seq_clear
  end

  def goto(x, y)
    print `tput cup #{x} #{y}`
  end

  def fg_color=(col)
    print `tput setaf #{col}`
  end

  def bg_color=(col)
    print `tput setab #{col}`
  end

  def reset_colors
    print @seq_sgr0
  end

  # Reads keypresses from the user including 2 and 3 escape character sequences.
  def read_char
    $stdin.echo = false
    $stdin.raw!

    input = $stdin.getc.chr
    if input == "\e" then
      input << $stdin.read_nonblock(3) rescue nil
      input << $stdin.read_nonblock(2) rescue nil
    end
  ensure
    $stdin.echo = true
    $stdin.cooked!

    return input
  end

  def read_char_mapped
    c = read_char
    c2 = KEY_MAP[c]
    c2 ? c2 : c
  end

  KEY_MAP = {
    "\r" => :enter,
    "\e[A" => :up_arrow,
    "\e[B" => :down_arrow,
    "\e[C" => :right_arrow,
    "\e[D" => :left_arrow,
    "\e[5~" => :pg_up,
    "\e[6~" => :pg_dn,
    "\e[H" => :home,
    "\e[F" => :end,
  }
end

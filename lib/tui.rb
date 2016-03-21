# coding: utf-8
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

  ##
  # Put the cursor up to screen position (x, y). First line is 0,
  # first column is 0.
  def goto(x, y)
    print `tput cup #{y} #{x}`
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

  def message_box_exception(e)
    message_box("Error while parsing", e.message)
  end

  SINGLE_CHARSET = '┌┐└┘─│'
  HEAVY_CHARSET  = '┏┓┗┛━┃'
  DOUBLE_CHARSET = '╔╗╚╝═║'

  CHAR_TL = 0
  CHAR_TR = 1
  CHAR_BL = 2
  CHAR_BR = 3
  CHAR_H  = 4
  CHAR_V  = 5

  def message_box(header, msg)
    top_y = @rows / 2 - 5
    draw_rectangle(10, top_y, @cols - 20, 10)
    goto(@cols / 2 - (header.length / 2) - 1, top_y)
    print ' ', header, ' '
    goto(11, top_y + 1)
    puts msg
    draw_button(@cols / 2 - 10, top_y + 8, 10, 'OK')
    loop {
      c = read_char_mapped
      return if c == :enter
    }
  end

  def draw_rectangle(x, y, w, h, charset = DOUBLE_CHARSET)
    goto(x, y)
    print charset[CHAR_TL]
    print charset[CHAR_H] * (w - 2)
    print charset[CHAR_TR]

    ((y + 1)..(y + h - 1)).each { |i|
      goto(x, i)
      print charset[CHAR_V]
      print ' ' * (w - 2)
      print charset[CHAR_V]
    }

    goto(x, y + h)
    print charset[CHAR_BL]
    print charset[CHAR_H] * (w - 2)
    print charset[CHAR_BR]
  end

  def draw_button(x, y, w, caption)
    goto(x, y)
    puts "[ #{caption} ]"
  end
end

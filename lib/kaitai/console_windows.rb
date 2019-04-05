# coding: utf-8
require 'Win32API'
require 'readline'

module Kaitai

class ConsoleWindows
  attr_reader :cols
  attr_reader :rows

  GET_STD_HANDLE = Win32API.new('kernel32', 'GetStdHandle', 'L', 'L')
  GET_CONSOLE_SCREEN_BUFFER_INFO = Win32API.new('kernel32', 'GetConsoleScreenBufferInfo', 'LP', 'L')

  FILL_CONSOLE_OUTPUT_ATTRIBUTE = Win32API.new('kernel32', 'FillConsoleOutputAttribute', 'LILLP', 'I')
  FILL_CONSOLE_OUTPUT_CHARACTER = Win32API.new('kernel32', 'FillConsoleOutputCharacter', 'LILLP', 'I')
  SET_CONSOLE_CURSOR_POSITION = Win32API.new('kernel32', 'SetConsoleCursorPosition', 'LI', 'I')
  SET_CONSOLE_TEXT_ATTRIBUTE = Win32API.new('kernel32', 'SetConsoleTextAttribute', 'LL', 'I')

  WRITE_CONSOLE = Win32API.new("kernel32", "WriteConsole", ['l', 'p', 'l', 'p', 'p'], 'l')

  GETCH = Win32API.new("msvcrt", "_getch", [], 'I')

  def initialize
    @stdin_handle = GET_STD_HANDLE.call(-10)
    @stdout_handle = GET_STD_HANDLE.call(-11)
    @fg_color = 7
    @bg_color = 0

    # typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
    #   COORD      dwSize;
    #   COORD      dwCursorPosition;
    #   WORD       wAttributes;
    #   SMALL_RECT srWindow;
    #   COORD      dwMaximumWindowSize;
    # } CONSOLE_SCREEN_BUFFER_INFO;

    # 4 + 4 + 2 + 4 * 2 + 4 = 22

    get_term_size
  end

  def get_term_size
    csbi = 'X' * 22

    GET_CONSOLE_SCREEN_BUFFER_INFO.call(@stdout_handle, csbi)
    @buf_cols, @buf_rows,
      cur_x, cur_y, cur_attr,
      win_left, win_top, win_right, win_bottom,
      max_win_x, max_win_y = csbi.unpack('vvvvvvvvvvv')

    # Getting size of actual visible portion of Windows console
    # http://stackoverflow.com/a/12642749/487064
    @cols = win_right - win_left + 1
    @rows = win_bottom - win_top + 1
  end

  def on_resize=(handler)
    @on_resize = handler
  end

  def puts(s)
    Kernel::puts s
#    num_written = 'XXXX'
#    reserved = 'XXXX'
#    WRITE_CONSOLE.call(@stdout_handle, s, s.length, num_written, reserved)
  end

  def clear
    con_size = @buf_cols * @buf_rows
    num_written = 'XXXX'
    FILL_CONSOLE_OUTPUT_CHARACTER.call(
      @stdout_handle,
      0x20, # ' '
      con_size,
      0, # [0, 0] coords
      num_written
    )
    FILL_CONSOLE_OUTPUT_ATTRIBUTE.call(
      @stdout_handle,
      current_color_code,
      con_size,
      0, # [0, 0] coords
      num_written
    )
    goto(0, 0)
  end

  ##
  # Put the cursor up to screen position (x, y). First line is 0,
  # first column is 0.
  def goto(x, y)
    coord = [x, y].pack('vv').unpack('V')[0]
    SET_CONSOLE_CURSOR_POSITION.call(@stdout_handle, coord)
  end

  COLORS = {
    :black => 0,
    :blue => 1,
    :green => 2,
    :aqua => 3,
    :red => 4,
    :purple => 5,
    :yellow => 6,
    :white => 7,
    :gray => 8,
    :light_blue => 9,
    :light_green => 0xa,
    :light_aqua => 0xb,
    :light_red => 0xc,
    :light_purple => 0xd,
    :light_yellow => 0xe,
    :bright_white => 0xf,
  }

  def fg_color=(col)
    code = COLORS[col]
    raise "Invalid color: #{col}" unless code
    @fg_color = code
    update_colors
  end

  def bg_color=(col)
    code = COLORS[col]
    raise "Invalid color: #{col}" unless code
    @bg_color = code
    update_colors
  end

  def reset_colors
    @fg_color = 7
    @bg_color = 0
    update_colors
  end

  ZERO_ESCAPE = 0.chr
  E0_ESCAPE = 0xe0.chr

  # Reads keypresses from the user including 2 and 3 escape character sequences.
  def read_char
    input = GETCH.call.chr
    if input == E0_ESCAPE || input == ZERO_ESCAPE
      input << GETCH.call.chr
    end

    get_term_size
    @on_resize.call if @on_resize

    return input
  end

  def read_char_mapped
    c = read_char
    c2 = KEY_MAP[c]
    c2 ? c2 : c
  end

  KEY_MAP = {
    "\b" => :backspace,
    "\t" => :tab,
    "\r" => :enter,

    # Regular AT keyboard arrows
    E0_ESCAPE + "H" => :up_arrow,
    E0_ESCAPE + "P" => :down_arrow,
    E0_ESCAPE + "K" => :left_arrow,
    E0_ESCAPE + "M" => :right_arrow,
    E0_ESCAPE + "I" => :pg_up,
    E0_ESCAPE + "Q" => :pg_dn,
    E0_ESCAPE + "G" => :home,
    E0_ESCAPE + "O" => :end,

    # Keypad
    ZERO_ESCAPE + "H" => :up_arrow,
    ZERO_ESCAPE + "P" => :down_arrow,
    ZERO_ESCAPE + "K" => :left_arrow,
    ZERO_ESCAPE + "M" => :right_arrow,
    ZERO_ESCAPE + "I" => :pg_up,
    ZERO_ESCAPE + "Q" => :pg_dn,
    ZERO_ESCAPE + "G" => :home,
    ZERO_ESCAPE + "O" => :end,
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

  def input_str(header, msg)
    top_y = @rows / 2 - 5
    draw_rectangle(10, top_y, @cols - 20, 10)
    goto(@cols / 2 - (header.length / 2) - 1, top_y)
    print ' ', header, ' '

    goto(11, top_y + 1)
    Readline.readline('', false)
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

  # Regexp borrowed from
  # http://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
  @@is_windows = (RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/) ? true : false

  # Detects if current platform is Windows-based.
  def self.is_windows?
    @@is_windows
  end

  private
  def current_color_code
    (@bg_color << 4) | @fg_color
  end

  def update_colors
    SET_CONSOLE_TEXT_ATTRIBUTE.call(@stdout_handle, current_color_code)
  end
end

end

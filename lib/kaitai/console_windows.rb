# frozen_string_literal: true

require 'fiddle'
require 'readline'

module Kaitai
  class ConsoleWindows
    attr_reader :cols
    attr_reader :rows

    kernel32 = Fiddle.dlopen('kernel32')

    dword = Fiddle::TYPE_LONG
    word = Fiddle::TYPE_SHORT
    ptr = Fiddle::TYPE_VOIDP
    handle = Fiddle::TYPE_VOIDP

    GET_STD_HANDLE = Fiddle::Function.new(kernel32['GetStdHandle'], [dword], handle)
    GET_CONSOLE_SCREEN_BUFFER_INFO = Fiddle::Function.new(kernel32['GetConsoleScreenBufferInfo'], [handle, ptr], dword)

    FILL_CONSOLE_OUTPUT_ATTRIBUTE = Fiddle::Function.new(kernel32['FillConsoleOutputAttribute'], [handle, word, dword, dword, ptr], dword)
    FILL_CONSOLE_OUTPUT_CHARACTER = Fiddle::Function.new(kernel32['FillConsoleOutputCharacter'], [handle, word, dword, dword, ptr], dword)
    SET_CONSOLE_CURSOR_POSITION = Fiddle::Function.new(kernel32['SetConsoleCursorPosition'], [handle, dword], dword)
    SET_CONSOLE_TEXT_ATTRIBUTE = Fiddle::Function.new(kernel32['SetConsoleTextAttribute'], [handle, dword], dword)

    WRITE_CONSOLE = Fiddle::Function.new(kernel32['WriteConsole'], [handle, ptr, dword, ptr, ptr], dword)

    GETCH = Fiddle::Function.new(Fiddle.dlopen('msvcrt')['_getch'], [], word)

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

      load_term_size
    end

    def load_term_size
      csbi = 'X' * 22

      GET_CONSOLE_SCREEN_BUFFER_INFO.call(@stdout_handle, csbi)
      @buf_cols, @buf_rows,
        _cur_x, _cur_y, _cur_attr,
        win_left, win_top, win_right, win_bottom,
        _max_win_x, _max_win_y = csbi.unpack('vvvvvvvvvvv')

      # Getting size of actual visible portion of Windows console
      # http://stackoverflow.com/a/12642749/487064
      @cols = win_right - win_left + 1
      @rows = win_bottom - win_top + 1
    end

    attr_writer :on_resize

    def refresh
    end

    def print(*args)
      Kernel.print(*args)
    end

    def puts(*args)
      Kernel.puts(*args)
      # num_written = 'XXXX'
      # reserved = 'XXXX'
      # WRITE_CONSOLE.call(@stdout_handle, s, s.length, num_written, reserved)
    end

    def readline
      Readline.readline('', false)
    end

    def clear
      con_size = @buf_cols * @buf_rows
      num_written = 'XXXX'.dup
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

    # Put the cursor up to screen position (x, y). First line is 0, first column is 0.
    def goto(x, y)
      coord = [x, y].pack('vv').unpack1('V')
      SET_CONSOLE_CURSOR_POSITION.call(@stdout_handle, coord)
    end

    COLORS = {
      black: 0,
      blue: 1,
      green: 2,
      aqua: 3,
      red: 4,
      purple: 5,
      yellow: 6,
      white: 7,
      gray: 8,
      light_blue: 9,
      light_green: 0xa,
      light_aqua: 0xb,
      light_red: 0xc,
      light_purple: 0xd,
      light_yellow: 0xe,
      bright_white: 0xf
    }.freeze

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
      input << GETCH.call.chr if input == E0_ESCAPE || input == ZERO_ESCAPE

      # https://github.com/kaitai-io/kaitai_struct_visualizer/issues/14
      load_term_size
      @on_resize&.call(false)

      input
    end

    def read_char_mapped
      c = read_char
      c2 = KEY_MAP[c]
      c2 || c
    end

    KEY_MAP = {
      "\b" => :backspace,
      "\t" => :tab,
      "\r" => :enter,

      # Regular AT keyboard arrows
      E0_ESCAPE + 'H' => :up_arrow,
      E0_ESCAPE + 'P' => :down_arrow,
      E0_ESCAPE + 'K' => :left_arrow,
      E0_ESCAPE + 'M' => :right_arrow,
      E0_ESCAPE + 'I' => :pg_up,
      E0_ESCAPE + 'Q' => :pg_dn,
      E0_ESCAPE + 'G' => :home,
      E0_ESCAPE + 'O' => :end,

      # Keypad
      ZERO_ESCAPE + 'H' => :up_arrow,
      ZERO_ESCAPE + 'P' => :down_arrow,
      ZERO_ESCAPE + 'K' => :left_arrow,
      ZERO_ESCAPE + 'M' => :right_arrow,
      ZERO_ESCAPE + 'I' => :pg_up,
      ZERO_ESCAPE + 'Q' => :pg_dn,
      ZERO_ESCAPE + 'G' => :home,
      ZERO_ESCAPE + 'O' => :end
    }.freeze

    def message_box_exception(e)
      message_box('Error while parsing', e.message)
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
      loop do
        c = read_char_mapped
        return if c == :enter
      end
    end

    def input_str(header, _msg)
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

      ((y + 1)..(y + h - 1)).each do |i|
        goto(x, i)
        print charset[CHAR_V]
        print ' ' * (w - 2)
        print charset[CHAR_V]
      end

      goto(x, y + h)
      print charset[CHAR_BL]
      print charset[CHAR_H] * (w - 2)
      print charset[CHAR_BR]
    end

    def draw_button(x, y, _w, caption)
      goto(x, y)
      puts "[ #{caption} ]"
    end

    # Regexp borrowed from
    # http://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
    @@is_windows = (RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/) ? true : false

    # Detects if current platform is Windows-based.
    def self.windows?
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

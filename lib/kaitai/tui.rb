# frozen_string_literal: true

require 'forwardable'

module Kaitai
  class TUI
    extend Forwardable
    def_delegators :@console, :rows, :cols, :goto, :clear, :fg_color=, :bg_color=, :reset_colors, :read_char_mapped, :refresh, :print, :puts

    attr_reader :highlight_colors

    def initialize
      if TUI.windows?
        require 'kaitai/console_windows'
        @console = ConsoleWindows.new
        @highlight_colors = %i[white aqua blue green white]
      else
        begin
          require 'kaitai/console_curses'
          @console = ConsoleCurses.new
        rescue LoadError
          require 'kaitai/console_ansi'
          @console = ConsoleANSI.new
        end
        @highlight_colors = %i[gray14 gray11 gray8 gray5 gray2]
      end
    end

    def on_resize=(handler)
      @console.on_resize = handler
    end

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
      top_y = @console.rows / 2 - 5
      draw_rectangle(10, top_y, @console.cols - 20, 10)
      @console.goto(@console.cols / 2 - (header.length / 2) - 1, top_y)
      print ' ', header, ' '
      @console.goto(11, top_y + 1)
      puts msg
      draw_button(@console.cols / 2 - 10, top_y + 8, 10, 'OK')
      loop do
        c = @console.read_char_mapped
        return if c == :enter
      end
    end

    def input_str(header, _msg)
      top_y = @console.rows / 2 - 5
      draw_rectangle(10, top_y, @console.cols - 20, 10)
      goto(@console.cols / 2 - (header.length / 2) - 1, top_y)
      print ' ', header, ' '

      goto(11, top_y + 1)
      @console.readline
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

    def printf(*args)
      @console.print sprintf(*args)
    end

    # Regexp borrowed from
    # http://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
    @@is_windows = (RUBY_PLATFORM =~ /cygwin|mswin|mingw|bccwin|wince|emx/) ? true : false

    # Detects if current platform is Windows-based.
    def self.windows?
      @@is_windows
    end
  end
end

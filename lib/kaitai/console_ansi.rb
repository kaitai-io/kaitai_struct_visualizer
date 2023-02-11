# frozen_string_literal: true

require 'io/console'
require 'readline'

module Kaitai
  class ConsoleANSI
    attr_reader :cols
    attr_reader :rows

    def initialize
      load_term_size

      @seq_clear = `tput clear`
      @seq_sgr0 = `tput sgr0`

      @seq_fgcolor = []
      @seq_bgcolor = []

      @on_resize = nil

      Signal.trap('SIGWINCH', proc {
        load_term_size
        @on_resize&.call(true)
      })
    end

    attr_writer :on_resize

    def load_term_size
      @rows, @cols = IO.console.winsize
    end

    def clear
      print @seq_clear
    end

    def refresh
    end

    def print(*args)
      Kernel.print(*args)
    end

    def puts(*args)
      Kernel.puts(*args)
    end

    def readline
      Readline.readline('', false)
    end

    # Put the cursor up to screen position (x, y). First line is 0, first column is 0.
    def goto(x, y)
      # print `tput cup #{y} #{x}`
      printf "\e[%d;%dH", y + 1, x + 1
    end

    COLORS = {
      black: 0,
      gray: 7,
      gray0: 232,
      gray1: 233,
      gray2: 234,
      gray3: 235,
      gray4: 236,
      gray5: 237,
      gray6: 238,
      gray7: 239,
      gray8: 240,
      gray9: 241,
      gray10: 242,
      gray11: 243,
      gray12: 244,
      gray13: 245,
      gray14: 246,
      gray15: 247,
      gray16: 248,
      gray17: 249,
      gray18: 250,
      gray19: 251,
      gray20: 252,
      gray21: 253,
      gray22: 254,
      gray23: 255
    }.freeze

    def fg_color=(col)
      # print @seq_fgcolor[col] ||= `tput setaf #{col}`
      code = COLORS[col]
      raise "Invalid color: #{col}" unless code

      print "\e[38;5;#{code}m"
    end

    def bg_color=(col)
      # print @seq_bgcolor[col] ||= `tput setab #{col}`
      code = COLORS[col]
      raise "Invalid color: #{col}" unless code

      print "\e[48;5;#{code}m"
    end

    def reset_colors
      print @seq_sgr0
    end

    # Reads keypresses from the user including 2 and 3 escape character sequences.
    def read_char
      $stdin.echo = false
      $stdin.raw!

      input = $stdin.getc.chr
      if input == "\e"
        begin
          # may return less than 3 bytes because it can only read as many bytes as are
          # currently available
          up_to_3bytes = $stdin.read_nonblock(3)
          input << up_to_3bytes
        rescue IO::WaitReadable
          # not an ANSI sequence - the user probably just pressed the Esc key
        end
      end

      $stdin.echo = true
      $stdin.cooked!

      input
    end

    def read_char_mapped
      c = read_char
      c2 = KEY_MAP[c]
      c2 || c
    end

    KEY_MAP = {
      "\t" => :tab,
      "\r" => :enter,
      "\e[A" => :up_arrow,
      "\e[B" => :down_arrow,
      "\e[C" => :right_arrow,
      "\e[D" => :left_arrow,
      "\e[5~" => :pg_up,
      "\e[6~" => :pg_dn,
      "\e[H" => :home,
      "\e[F" => :end
    }.freeze
  end
end

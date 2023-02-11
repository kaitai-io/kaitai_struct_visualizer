require 'curses'

module Kaitai
  class ConsoleCurses
    def initialize
      Curses.init_screen
      Curses.start_color
      Curses.use_default_colors
      Curses.stdscr.keypad = true
      ObjectSpace.define_finalizer(self, proc { Curses.close_screen })

      @on_resize = nil
      @color_pairs = {}
      @fg_color = COLORS[:default]
      @bg_color = COLORS[:default]
      update_color
    end

    attr_writer :on_resize

    def rows
      Curses.lines
    end

    def cols
      Curses.cols
    end

    private def update_color
      color = @color_pairs[[@fg_color, @bg_color]]
      if color.nil? then
        color = @color_pairs.size
        @color_pairs[[@fg_color, @bg_color]] = color
        Curses.init_pair(color, @fg_color, @bg_color)
      end
      Curses.attrset(Curses.color_pair(color))
    end

    def fg_color=(col)
      code = COLORS[col]
      raise "Invalid color: #{col}" unless code
      @fg_color = code
      update_color
    end

    def bg_color=(col)
      code = COLORS[col]
      raise "Invalid color: #{col}" unless code
      @bg_color = code
      update_color
    end

    def reset_colors
      @fg_color = COLORS[:default]
      @bg_color = COLORS[:default]
      update_color
    end

    def read_char
      loop do
        char = Curses.getch
        if char == Curses::Key::RESIZE then
          @on_resize&.call(true)
        else
          return char
        end
      end
    end

    def read_char_mapped
      c = read_char
      KEY_MAP[c] || c
    end

    def goto(x, y)
      Curses.setpos(y, x)
    end

    def clear
      Curses.clear
    end

    def refresh
      Curses.refresh
    end

    def readline
      Curses.getstr
    end

    def print(*args)
      args.each do |arg|
        Curses.addstr(arg)
      end
    end

    def puts(*args)
      Curses.addstr("\n") if args.empty?
      args.each do |arg|
        Curses.addstr(arg)
        Curses.addstr("\n")
      end
    end

    COLORS = {
      default: -1,
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
      gray23: 255,
    }.freeze

    KEY_MAP = {
      9 => :tab,
      10 => :enter,
      Curses::Key::UP => :up_arrow,
      Curses::Key::DOWN => :down_arrow,
      Curses::Key::LEFT => :left_arrow,
      Curses::Key::RIGHT => :right_arrow,
      Curses::Key::PPAGE => :pg_up,
      Curses::Key::NPAGE => :pg_dn,
      Curses::Key::HOME => :home,
      Curses::Key::END => :end,
    }.freeze
  end
end

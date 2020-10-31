# frozen_string_literal: true

require 'kaitai/struct/visualizer/version'
require 'kaitai/tui'
require 'kaitai/struct/visualizer/parser'
require 'kaitai/struct/visualizer/tree'

# TODO: should be inside compiled files
require 'zlib'
require 'stringio'

module Kaitai::Struct::Visualizer
  class Visualizer < Parser
    def run
      load_exc = load

      @ui = Kaitai::TUI.new
      @tree = Tree.new(@ui, @data)

      @tree.redraw
      @ui.message_box_exception(load_exc) if load_exc

      @tree.run
    end
  end
end

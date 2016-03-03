require 'tmpdir'

require 'tui'
require 'ks/tree'

# TODO: should be inside compiled files
require 'zlib'
require 'stringio'

class Visualizer
  def initialize(format_fn, bin_fn)
    @format_fn = format_fn
    @bin_fn = bin_fn
    compile

    @ui = TUI.new
    @tree = Tree.new(@ui, @data)
  end

  def run
    @tree.run
  end
end

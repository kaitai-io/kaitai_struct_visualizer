require 'tmpdir'

require 'tui'
require 'ks/tree'

# TODO: should be inside compiled files
require 'zlib'
require 'stringio'

class Visualizer
  def initialize(bin_fn, formats_fn)
    @bin_fn = bin_fn
    @formats_fn = formats_fn
    @primary_format = @formats_fn.shift

    main_class_name = compile_format(@primary_format)

    @formats_fn.each { |fn|
      compile_format(fn)
    }

    main_class = Kernel::const_get(main_class_name)
    @data = main_class.from_file(@bin_fn)

    @ui = TUI.new
    @tree = Tree.new(@ui, @data)
  end

  def run
    @tree.run
  end
end

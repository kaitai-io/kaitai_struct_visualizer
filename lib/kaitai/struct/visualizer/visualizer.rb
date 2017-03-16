require 'tmpdir'

require 'kaitai/struct/visualizer/version'
require 'kaitai/tui'
require 'kaitai/struct/visualizer/tree'

# TODO: should be inside compiled files
require 'zlib'
require 'stringio'

module Kaitai::Struct::Visualizer
class Visualizer
  def initialize(bin_fn, formats_fn)
    @bin_fn = bin_fn
    @formats_fn = formats_fn

    main_class_name = compile_formats(formats_fn)

    main_class = Kernel::const_get(main_class_name)
    @data = main_class.from_file(@bin_fn)

    load_exc = nil
    begin
      @data._read
    rescue EOFError => e
      load_exc = e
    rescue Kaitai::Struct::Stream::UnexpectedDataError => e
      load_exc = e
    end

    @ui = Kaitai::TUI.new
    @tree = Tree.new(@ui, @data)

    @tree.redraw
    @ui.message_box_exception(load_exc) if load_exc
  end

  def run
    @tree.run
  end
end
end

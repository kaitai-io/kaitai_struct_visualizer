require 'kaitai/struct/visualizer/version'
require 'kaitai/tui'
require 'kaitai/struct/visualizer/tree'

# TODO: should be inside compiled files
require 'zlib'
require 'stringio'

module Kaitai::Struct::Visualizer

##
# Base class for everything that deals with compiling .ksy and parsing
# stuff as object tree.
class Parser
  attr_reader :data

  def initialize(compiler, bin_fn, formats_fn, opts)
    @compiler = compiler
    @bin_fn = bin_fn
    @formats_fn = formats_fn
    @opts = opts
  end

  def load
    main_class_name = @compiler.compile_formats_if(@formats_fn)

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

    return load_exc
  end
end
end

require 'tmpdir'

require 'tui'
require 'ks_ruby_compiler'
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

  def compile
    Dir.mktmpdir { |code_dir|
      compiled_path = "#{code_dir}/compiled.rb"
      @compiler = CompileToRuby.new(@format_fn, compiled_path)
      @compiler.compile

      require compiled_path

      main_class_name = @compiler.type2class(@compiler.desc['meta']['id'])
      #puts "Main class: #{main_class_name}"
      main_class = Kernel::const_get(main_class_name)
      @data = main_class.from_file(@bin_fn)
    }
  end
end

require 'ks_ruby_compiler'

class RubyCompilerVisualizer extends Visualizer
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

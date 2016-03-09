require 'ks/visualizer'

class ExternalCompilerVisualizer < Visualizer
  def compile
    Dir.mktmpdir { |code_dir|
      system("ksc -- -t ruby '#{@format_fn}' -d '#{code_dir}'")
      exit $?.exitstatus if $?.exitstatus != 0

      compiled_path = Dir.glob("#{code_dir}/*.rb")[0]

      require compiled_path

      main_class_name = File.readlines(compiled_path).grep(/^class /)[0].strip.gsub(/^class /, '').gsub(/ <.*$/, '')
      main_class = Kernel::const_get(main_class_name)
      @data = main_class.from_file(@bin_fn)
    }
  end
end

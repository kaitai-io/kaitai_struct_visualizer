require 'ks/visualizer'

class ExternalCompilerVisualizer < Visualizer
  def compile_format(fn)
    main_class_name = nil
    Dir.mktmpdir { |code_dir|
      system("ksc -- --debug -t ruby '#{fn}' -d '#{code_dir}'")
      exit $?.exitstatus if $?.exitstatus != 0

      compiled_path = Dir.glob("#{code_dir}/*.rb")[0]

      require compiled_path

      main_class_name = File.readlines(compiled_path).grep(/^class /)[0].strip.gsub(/^class /, '').gsub(/ <.*$/, '')
    }

    return main_class_name
  end
end

require 'kaitai/struct/visualizer/version'
require 'kaitai/struct/visualizer/visualizer'
require 'kaitai/tui'

module Kaitai::Struct::Visualizer

class ExternalCompilerVisualizer < Visualizer
  def compile_format(fn)
    main_class_name = nil
    Dir.mktmpdir { |code_dir|
      args = ['--debug', '-t', 'ruby', fn, '-d', code_dir]

      # UNIX-based systems run ksc via a shell wrapper that requires
      # extra '--' in invocation to disambiguate our '-d' from java runner
      # '-d' (which allows to pass defines to JVM). Windows-based systems
      # do not need and do not support this extra '--', so we don't add it
      # on Windows.
      args.unshift('--') unless Kaitai::TUI::is_windows?

      system('kaitai-struct-compiler', *args)
      if $?.exitstatus != 0
        st = $?.exitstatus
        $stderr.puts("ksv: unable to find and execute kaitai-struct-compiler in your PATH") if st == 127
        exit st
      end

      puts "Compilation OK"

      compiled_path = Dir.glob("#{code_dir}/*.rb")[0]

      require compiled_path

      puts "Class loaded OK"

      main_class_name = File.readlines(compiled_path).grep(/^class /)[0].strip.gsub(/^class /, '').gsub(/ <.*$/, '')
    }

    return main_class_name
  end
end

end

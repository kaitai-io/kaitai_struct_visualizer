require 'kaitai/struct/visualizer/version'
require 'kaitai/struct/visualizer/visualizer'
require 'kaitai/tui'

require 'open3'
require 'json'

module Kaitai::Struct::Visualizer

class ExternalCompilerVisualizer < Visualizer
  def compile_formats(fns)
    main_class_name = nil
    Dir.mktmpdir { |code_dir|
      args = ['--ksc-json-output', '--debug', '-t', 'ruby', *fns, '-d', code_dir]

      p args

      # UNIX-based systems run ksc via a shell wrapper that requires
      # extra '--' in invocation to disambiguate our '-d' from java runner
      # '-d' (which allows to pass defines to JVM). Windows-based systems
      # do not need and do not support this extra '--', so we don't add it
      # on Windows.
      args.unshift('--') unless Kaitai::TUI::is_windows?

      status = nil
      log_str = nil
      Open3.popen3('kaitai-struct-compiler', *args) { |stdin, stdout, stderr, wait_thr|
        status = wait_thr.value
        log_str = stdout.read
      }

      if status != 0
        $stderr.puts("ksv: unable to find and execute kaitai-struct-compiler in your PATH") if status == 127
        exit st
      end

      log = JSON.load(log_str)

      # FIXME: add log results check
      puts "Compilation OK"

      fns.each_with_index { |fn, idx|
        puts "... processing #{fn}"
        log_classes = log[fn]['output']['ruby']
        log_classes.each_pair { |k, v|
          compiled_name = v['files'][0]['fileName']
          compiled_path = "#{code_dir}/#{compiled_name}"

          puts "...... loading #{compiled_name}"
          require compiled_path

          # Is it main class?
          if idx == 0
            # FIXME: use after topLevelName works
            #main_class_name = v['topLevelName']
            main_class_name = k.split(/_/).map { |x| x.capitalize }.join
          end
        }
      }

      puts "Classes loaded OK"
    }

    return main_class_name
  end
end

end

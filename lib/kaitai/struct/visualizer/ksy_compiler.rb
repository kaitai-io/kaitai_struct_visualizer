require 'kaitai/struct/visualizer/version'
require 'kaitai/tui'

require 'open3'
require 'json'
require 'tmpdir'

module Kaitai::Struct::Visualizer

class KSYCompiler
  def initialize(opts, out = $stderr)
    @opts = opts
    @out = out
  end

  def compile_formats_if(fns)
    if (fns.length > 1) || fns[0].end_with?('.ksy')
      return compile_formats(fns)
    end

    fname = File.basename(fns[0], '.rb')
    dname = File.dirname( fns[0])
    gpath = File.expand_path('*.rb', dname)

    Dir.glob(gpath) { |fname|
      @out.puts "Loading: #{fname}"
      require File.expand_path(fname, dname)
    }

    # The name of the main class is that of the given file by convention.
    return fname.split('_').map(&:capitalize).join()
  end

  def compile_formats(fns)
    errs = false
    main_class_name = nil
    Dir.mktmpdir { |code_dir|
      args = ['--ksc-json-output', '--debug', '-t', 'ruby', *fns, '-d', code_dir]

      # Extra arguments
      extra = []
      extra += ['--import-path', @opts[:import_path]] if @opts[:import_path]
      extra += ['--opaque-types', @opts[:opaque_types]] if @opts[:opaque_types]

      args = extra + args

      # UNIX-based systems run ksc via a shell wrapper that requires
      # extra '--' in invocation to disambiguate our '-d' from java runner
      # '-d' (which allows to pass defines to JVM). Windows-based systems
      # do not need and do not support this extra '--', so we don't add it
      # on Windows.
      args.unshift('--') unless Kaitai::TUI::is_windows?

      status = nil
      log_str = nil
      err_str = nil
      Open3.popen3('kaitai-struct-compiler', *args) { |stdin, stdout, stderr, wait_thr|
        status = wait_thr.value
        log_str = stdout.read
        err_str = stderr.read
      }

      if not status.success?
        if status.exitstatus == 127
          @out.puts "ksv: unable to find and execute kaitai-struct-compiler in your PATH"
        elsif err_str =~ /Error: Unknown option --ksc-json-output/
          @out.puts "ksv: your kaitai-struct-compiler is too old:"
          system('kaitai-struct-compiler', '--version')
          @out.puts "\nPlease use at least v0.7."
        else
          @out.puts "ksc crashed (exit status = #{status}):\n"
          @out.puts "== STDOUT\n"
          @out.puts log_str
          @out.puts
          @out.puts "== STDERR\n"
          @out.puts err_str
          @out.puts
        end
        exit status.exitstatus
      end

      log = JSON.load(log_str)

      # FIXME: add log results check
      @out.puts "Compilation OK"

      fns.each_with_index { |fn, idx|
        @out.puts "... processing #{fn} #{idx}"

        log_fn = log[fn]
        if log_fn['errors']
          report_err(log_fn['errors'])
          errs = true
        else
          log_classes = log_fn['output']['ruby']
          log_classes.each_pair { |k, v|
            if v['errors']
              report_err(v['errors'])
              errs = true
            else
              compiled_name = v['files'][0]['fileName']
              compiled_path = "#{code_dir}/#{compiled_name}"

              @out.puts "...... loading #{compiled_name}"
              require compiled_path
            end
          }

          # Is it main ClassSpecs?
          if idx == 0
            main = log_classes[log_fn['firstSpecName']]
            main_class_name = main['topLevelName']
          end
        end
      }
    }

    if errs
      @out.puts "Fatal errors encountered, cannot continue"
      exit 1
    else
      @out.puts "Classes loaded OK, main class = #{main_class_name}"
    end

    return main_class_name
  end

  def report_err(err)
    @out.puts "Error: #{err.inspect}"
  end
end

end

require 'kaitai/struct/visualizer/version'
require 'kaitai/tui'

require 'open3'
require 'json'
require 'tmpdir'

require 'psych'

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
      args = ['--ksc-json-output', '--debug', '-t', 'ruby', '-d', code_dir, *fns]

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

      log_str, err_str, status = Open3.capture3('kaitai-struct-compiler', *args)
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

  def report_err(errs)
    @out.puts((errs.length > 1 ? 'Errors' : 'Error') + ":\n\n")
    errs.each { |err|
      @out << err['file']

      row = nil
      col = nil

      begin
        node = resolve_yaml_path(err['file'], err['path'])

        # Psych line numbers are 0-based, but we want 1-based
        row = node.start_line + 1

        # We're fine with 0-based columns
        col = node.start_column
      rescue
        row = '!'
        col = '!'
      end

      if row
        @out << ':' << row
        @out << ':' << col if col
      end

      @out << ':/' << err['path'].join('/') if err['path']
      @out << ': ' << err['message'] << "\n"
    }
  end

  ##
  # Parses YAML file using Ruby's mid-level Psych API and resolve YAML
  # path reported by ksc to row & column.
  def resolve_yaml_path(file, path)
    doc = Psych.parse(File.read(file))
    yaml = doc.children[0]
    path.each { |path_part|
      yaml = psych_find(yaml, path_part)
    }
    yaml
  end

  def psych_find(yaml, path_part)
    if yaml.is_a?(Psych::Nodes::Mapping)
      # mapping are key-values, which are represented as [k1, v1, k2, v2, ...]
      yaml.children.each_slice(2) { |map_key, map_value|
        return map_value if map_key.value == path_part
      }
      return nil
    elsif yaml.is_a?(Psych::Nodes::Sequence)
      # sequences are just integer-indexed arrays - [a0, a1, a2, ...]
      idx = Integer(path_part)
      return yaml.children[idx]
    else
      raise "Unknown Psych component encountered: #{yaml.class}"
    end
  end
end

end

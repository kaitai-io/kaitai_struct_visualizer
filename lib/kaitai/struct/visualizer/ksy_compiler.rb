# frozen_string_literal: true

require 'kaitai/struct/visualizer/version'
require 'kaitai/tui'

require 'open3'
require 'json'
require 'tmpdir'

require 'psych'

module Kaitai::Struct::Visualizer
  class KSYCompiler
    # Initializes a new instance of the KSYCompiler class that is used to
    # compile Kaitai Struct formats into Ruby classes by invoking the
    # command line kaitai-struct-compiler.
    #
    # @param [Hash] opts Options
    # @option opts [String] :outdir Output directory for compiled code; if
    #   not specified, a temporary directory will be used that will be
    #   deleted after the compilation is done
    # @option opts [String] :import_path Additional import paths
    # @option opts [String] :opaque_types "true" or "false" to enable or
    #   disable opaque types
    #
    # @param [String] prog_name Program name to be used as a prefix in
    #   error messages
    # @param [IO] out IO stream to write error/warning messages to
    def initialize(opts, prog_name = 'ksv', out = $stderr)
      @opts = opts
      @prog_name = prog_name
      @out = out

      @outdir = opts[:outdir]
    end

    def compile_formats_if(fns)
      return compile_formats(fns) if (fns.length > 1) || fns[0].end_with?('.ksy')

      fname = File.basename(fns[0], '.rb')
      dname = File.dirname(fns[0])
      gpath = File.expand_path('*.rb', dname)

      Dir.glob(gpath) do |fn|
        require File.expand_path(fn, dname)
      end

      # The name of the main class is that of the given file by convention.
      fname.split('_').map(&:capitalize).join
    end

    # Compiles Kaitai Struct formats into Ruby classes by invoking the
    # command line kaitai-struct-compiler, and loads the generated Ruby
    # files into current Ruby interpreter by running `require` on them.
    #
    # If the :outdir option was specified, the compiled code will be
    # stored in that directory. Otherwise, a temporary directory will be
    # used that will be deleted after the compilation and loading is done.
    #
    # @param [Array<String>] fns List of Kaitai Struct format files to
    #   compile
    # @return [String] Main class name, or nil if were errors
    def compile_formats(fns)
      if @outdir.nil?
        main_class_name = nil
        Dir.mktmpdir { |code_dir| main_class_name = compile_and_load(fns, code_dir) }
      else
        main_class_name = compile_and_load(fns, @outdir)
      end

      if main_class_name.nil?
        @out.puts 'Fatal errors encountered, cannot continue'
        exit 1
      end

      main_class_name
    end

    # Compiles Kaitai Struct formats into Ruby classes by invoking the
    # command line kaitai-struct-compiler, and loads the generated Ruby
    # files into current Ruby interpreter by running `require` on them.
    #
    # @param [Array<String>] fns List of Kaitai Struct format files to
    #   compile
    # @param [String] code_dir Directory to store the compiled code in
    # @return [String] Main class name, or nil if were errors
    def compile_and_load(fns, code_dir)
      log = compile_formats_to_output(fns, code_dir)
      load_ruby_files(fns, code_dir, log)
    end

    # Compiles Kaitai Struct formats into Ruby classes by invoking the
    # command line kaitai-struct-compiler.
    #
    # @param [Array<String>] fns List of Kaitai Struct format files to
    #   compile
    # @param [String] code_dir Directory to store the compiled code in
    # @return [Hash] Structured output of kaitai-struct-compiler
    def compile_formats_to_output(fns, code_dir)
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
      args.unshift('--') unless Kaitai::TUI.windows?

      begin
        log_str, err_str, status = Open3.capture3('kaitai-struct-compiler', *args)
      rescue Errno::ENOENT
        @out.puts "#{@prog_name}: unable to find and execute kaitai-struct-compiler in your PATH"
        exit 1
      end
      unless status.success?
        if err_str =~ /Error: Unknown option --ksc-json-output/
          @out.puts "#{@prog_name}: your kaitai-struct-compiler is too old:"
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

      JSON.parse(log_str)
    end

    # Loads Ruby files generated by kaitai-struct-compiler into current Ruby interpreter
    # by running `require` on them.
    #
    # @param [Array<String>] fns List of Kaitai Struct format files that were compiled
    # @param [String] code_dir Directory where the compiled Ruby files are stored
    # @param [Hash] log Structured output of kaitai-struct-compiler
    # @return [String] Main class name, or nil if were errors
    def load_ruby_files(fns, code_dir, log)
      errs = false
      main_class_name = nil

      fns.each_with_index do |fn, idx|
        log_fn = log[fn]
        if log_fn['errors']
          report_err(log_fn['errors'])
          errs = true
        else
          log_classes = log_fn['output']['ruby']
          log_classes.each_pair do |_k, v|
            if v['errors']
              report_err(v['errors'])
              errs = true
            else
              compiled_name = v['files'][0]['fileName']
              compiled_path = File.join(code_dir, compiled_name)

              require compiled_path
            end
          end

          # Is it main ClassSpecs?
          if idx.zero?
            main = log_classes[log_fn['firstSpecName']]
            main_class_name = main['topLevelName']
          end
        end
      end

      errs ? nil : main_class_name
    end

    def report_err(errs)
      @out.puts((errs.length > 1 ? 'Errors' : 'Error') + ":\n\n")
      errs.each do |err|
        @out << err['file']

        row = err['line']
        col = err['col']

        if row.nil? && err['path']
          begin
            node = resolve_yaml_path(err['file'], err['path'])

            # Psych line numbers are 0-based, but we want 1-based
            row = node.start_line + 1

            # Psych column numbers are 0-based, but we want 1-based
            col = node.start_column + 1
          rescue StandardError
            row = '!'
            col = '!'
          end
        end

        if row
          @out << ':' << row
          @out << ':' << col if col
        end

        @out << ':/' << err['path'].join('/') if err['path']
        @out << ': ' << err['message'] << "\n"
      end
    end

    # Parses YAML file using Ruby's mid-level Psych API and resolve YAML
    # path reported by ksc to row & column.
    def resolve_yaml_path(file, path)
      doc = Psych.parse(File.read(file))
      yaml = doc.children[0]
      path.each do |path_part|
        yaml = psych_find(yaml, path_part)
      end
      yaml
    end

    def psych_find(yaml, path_part)
      if yaml.is_a?(Psych::Nodes::Mapping)
        # mapping are key-values, which are represented as [k1, v1, k2, v2, ...]
        yaml.children.each_slice(2) do |map_key, map_value|
          return map_value if map_key.value == path_part
        end
        nil
      elsif yaml.is_a?(Psych::Nodes::Sequence)
        # sequences are just integer-indexed arrays - [a0, a1, a2, ...]
        idx = Integer(path_part)
        yaml.children[idx]
      else
        raise "Unknown Psych component encountered: #{yaml.class}"
      end
    end
  end
end

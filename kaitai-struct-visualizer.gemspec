# frozen_string_literal: true

require File.expand_path('lib/kaitai/struct/visualizer/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'kaitai-struct-visualizer'
  s.version = Kaitai::Struct::Visualizer::VERSION

  s.authors = ['Mikhail Yakshin']
  s.email = 'greycat@kaitai.io'

  s.homepage = 'https://kaitai.io/'
  s.summary = 'Advanced hex viewer and binary structure exploration tool (visualizer) using Kaitai Struct ksy files'
  s.license = 'GPL-3.0-or-later'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/kaitai-io/kaitai_struct_visualizer/issues',
    'homepage_uri' => s.homepage,
    'source_code_uri' => 'https://github.com/kaitai-io/kaitai_struct_visualizer',
    # See https://guides.rubygems.org/mfa-requirement-opt-in/
    'rubygems_mfa_required' => 'true'
  }
  s.description = <<~DESC
    Kaitai Struct is a declarative language used for describe various binary data structures, laid out in files or in memory: i.e. binary file formats, network stream packet formats, etc.

    The main idea is that a particular format is described in Kaitai Struct language (.ksy file) and then can be compiled with ksc into source files in one of the supported programming languages. These modules will include a generated code for a parser that can read described data structure from a file / stream and give access to it in a nice, easy-to-comprehend API.

    This package is a visualizer tool for .ksy files. Given a particular binary file and .ksy file(s) that describe its format, it can visualize internal data structures in a tree form and a multi-level highlight hex viewer.
  DESC

  s.required_ruby_version = '>= 2.4.0'
  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.require_paths = ['lib']

  s.files = Dir['lib/**/*.rb'] + Dir['bin/*'] + ['LICENSE', 'README.md']
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }

  s.add_dependency 'activesupport', '>= 5.0.0', '< 9.0.0'
  s.add_dependency 'builder', '~> 3.3'
  s.add_dependency 'benchmark', '>= 0.1.0', '< 0.5.0'
  s.add_dependency 'kaitai-struct', '~> 0.7'

  s.requirements << 'kaitai-struct-compiler (https://kaitai.io/#download), the version must match the kaitai-struct gem (check using `ksv --version`)'
end

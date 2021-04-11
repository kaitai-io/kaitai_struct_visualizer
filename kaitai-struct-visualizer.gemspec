# frozen_string_literal: true

require File.expand_path('lib/kaitai/struct/visualizer/version', __dir__)
require 'date'

Gem::Specification.new do |s|
  s.name = 'kaitai-struct-visualizer'
  s.version = Kaitai::Struct::Visualizer::VERSION
  s.date = Date.today.to_s

  s.authors = ['Mikhail Yakshin']
  s.email = 'greycat@kaitai.io'

  s.homepage = 'http://kaitai.io'
  s.summary = 'Advanced hex viewer and binary structure exploration tool (visualizer) using Kaitai Struct ksy files'
  s.license = 'GPL-3.0-or-later'
  s.description = <<~DESC
    Kaitai Struct is a declarative language used for describe various binary data structures, laid out in files or in memory: i.e. binary file formats, network stream packet formats, etc.

    The main idea is that a particular format is described in Kaitai Struct language (.ksy file) and then can be compiled with ksc into source files in one of the supported programming languages. These modules will include a generated code for a parser that can read described data structure from a file / stream and give access to it in a nice, easy-to-comprehend API.

    This package is a visualizer tool for .ksy files. Given a particular binary file and .ksy file(s) that describe its format, it can visualize internal data structures in a tree form and a multi-level highlight hex viewer.
  DESC

  s.required_rubygems_version = Gem::Requirement.new('>= 0') if s.respond_to? :required_rubygems_version=
  s.require_paths = ['lib']

  s.files = Dir['lib/**/*.rb'] + Dir['bin/*'] + Dir['spec/*']
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  s.add_development_dependency 'bundler', '~> 1.3'
  s.add_development_dependency 'rake', '~> 12.3.3'
  # s.add_development_dependency 'rspec', '~> 3'

  s.add_dependency 'kaitai-struct', '~> 0.4'
end

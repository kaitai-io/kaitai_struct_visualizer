# Kaitai Struct: visualizer

This is a console visualizer for the [Kaitai Struct](https://kaitai.io/) project.

![screenshot](https://raw.githubusercontent.com/kaitai-io/kaitai_struct_visualizer/87f42c8c1eee97b825a2ff7d00c1370f5a87d050/screenshot.png)

Kaitai Struct is a declarative language used for describe various
binary data structures, laid out in files or in memory: i.e. binary
file formats, network stream packet formats, etc.

The main idea is that a particular format is described in Kaitai
Struct language (`.ksy` file) and then can be compiled with
`ksc` into source files in one of the supported programming
languages. These modules will contain generated code for a parser
that can read the described data structure from a file / stream and provide
access to it using a nice, easy-to-understand API.

See the [Kaitai Struct homepage](https://kaitai.io/) for details on `.ksy` files and general usage patterns.

## Downloading and installing

### Requirements _(this Docker image has everything bundled inside)_

- [ksc](https://kaitai.io/#download) — `kaitai-struct-compiler`
- [Java](https://whichjdk.com/) (the latest LTS version 21 recommended, at least Java 8 required),
  [JDK or JRE](https://whichjdk.com/#what-is-the-difference-between-jdk-and-jre) at your option
- [Ruby](https://www.ruby-lang.org/) (the latest Ruby 3.x recommended, at least Ruby 2.4 required)

### From the RubyGems repository

Kaitai Struct visualizer is written in [Ruby](https://www.ruby-lang.org/) and is
available [on RubyGems](https://rubygems.org/gems/kaitai-struct-visualizer). Thus,
you'll need Ruby installed on your box and then you can just run:

```shell
gem install kaitai-struct-visualizer
```

---

You can use `ksv --version` to check what versions of `ksv` and its dependencies are installed, for example:

```console
$ ksv --version
kaitai-struct-visualizer 0.11
kaitai-struct-compiler 0.11
kaitai-struct 0.11 (Kaitai Struct runtime library for Ruby)
```

The versions of `kaitai-struct-compiler` and `kaitai-struct` should match. If not, see https://kaitai.io/#download for instructions how to install the latest version of `kaitai-struct-compiler` and/or use `gem update kaitai-struct` to update the [kaitai-struct](https://rubygems.org/gems/kaitai-struct) gem if needed.

### Source code

If you're interested in developing the visualizer itself, you can check
out the source code from the [kaitai_struct_visualizer](https://github.com/kaitai-io/kaitai_struct_visualizer) GitHub repository:

```shell
git clone https://github.com/kaitai-io/kaitai_struct_visualizer.git
```

Then run `bundle install` to install dependencies. After that, you can run [`bin/ksv`](bin/ksv) or [`bin/ksdump`](bin/ksdump) right away (without having to install the `kaitai-struct-visualizer` gem first), which makes development easier.

## Usage

There are two executables provided by this package:

* `ksv` — interactive console visualizer with GUI
* `ksdump` — command-line tool for dumping parsed data in JSON, XML or YAML format to standard output (_stdout_)

The basic usage is similar for both programs:

```shell
ksv <file_to_parse.bin> <format.ksy>|<format.rb>
```

For `ksdump`, it may be useful to change the output format with the `-f` option (the default is `yaml`) and redirect the output to a file so that your terminal is not flooded with thousands of lines (for larger input files):

```shell
ksdump -f json <file_to_parse.bin> <format.ksy> > output.json
```

### Running with Docker

This project is also available via the [kaitai/ksv](https://hub.docker.com/r/kaitai/ksv) image on Docker Hub. The default entrypoint is `ksv` (the interactive visualizer):

```shell
docker run --rm -it -v "$(pwd):/share" kaitai/ksv <file_to_parse.bin> <format.ksy>
```

You can specify `ksdump` as the entrypoint like this (and note that we don't need the `-it` flags anymore because `ksdump` is not interactive — omitting them in fact allows you to distinguish the `ksdump`'s output to _stdout_ and _stderr_, see [this comment](https://github.com/kaitai-io/kaitai_struct_visualizer/issues/56#issuecomment-1666629764)):

```shell
docker run --rm -v "$(pwd):/share" --entrypoint ksdump kaitai/ksv -f json <file_to_parse.bin> <format.ksy> > output.json
```

---

Building the Docker image locally:
```shell
docker build . --tag docker.io/kaitai/ksv
```

## Licensing

Kaitai Struct visualizer is copyright (C) 2015-2025 Kaitai Project.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

---

Note that it applies only to visualizer itself, not `.ksy` input files
that one supplies in normal process of compilation, nor to compiler's
output files — that constitutes normal usage process and you obviously
keep copyright to both.

# frozen_string_literal: true

require 'kaitai/struct/visualizer/parser'
require 'kaitai/struct/visualizer/ksy_compiler'

module Kaitai::Struct::Visualizer
  describe Parser do
    before(:context) do
      @old_pwd = Dir.pwd
      Dir.chdir('spec')
    end
    after(:context) { Dir.chdir(@old_pwd) }

    context '#load' do
      it 'loads simple format successfully' do
        opts = {}
        compiler = KSYCompiler.new(opts)
        parser = Parser.new(compiler, 'input/7bytes.bin', ['formats/simple.ksy'], opts)

        exc = parser.load
        expect(exc).to be_nil

        expect(parser.data.class::SEQ_FIELDS).to eq(%w[foo bar])
        expect(parser.data.foo).to eq(49)
        expect(parser.data._debug['foo']).to eq({ start: 0, end: 1 })
        expect(parser.data.bar).to eq('234567')
        expect(parser.data._debug['bar']).to eq({ start: 1, end: 7 })
      end

      it 'handles EOF error in seq' do
        opts = {}
        compiler = KSYCompiler.new(opts)
        parser = Parser.new(compiler, 'input/7bytes.bin', ['formats/partial_seq.ksy'], opts)

        exc = parser.load

        expect(exc).to be_a(EOFError)

        expect(parser.data.class::SEQ_FIELDS).to eq(%w[foo bar])
        expect(parser.data.foo).to eq('12345')
        expect(parser.data._debug['foo']).to eq({ start: 0, end: 5 })
        expect(parser.data.bar).to be_nil
        expect(parser.data._debug['bar']).to eq({ start: 5 })
      end

      it 'handles EOF error in array' do
        opts = {}
        compiler = KSYCompiler.new(opts)
        parser = Parser.new(compiler, 'input/7bytes.bin', ['formats/partial_array_struct.ksy'], opts)

        exc = parser.load

        # we want 5 entries of 2 bytes each = 10 bytes, only 7 bytes available
        expect(exc).to be_a(EOFError)

        expect(parser.data.class::SEQ_FIELDS).to eq(%w[entries])

        # 4 entries: 3 full, last one partial
        expect(parser.data.entries.size).to eq(4)

        # 3 full entries
        expect(parser.data.entries[0].a).to eq(49)
        expect(parser.data.entries[0].b).to eq(50)
        expect(parser.data.entries[1].a).to eq(51)
        expect(parser.data.entries[1].b).to eq(52)
        expect(parser.data.entries[2].a).to eq(53)
        expect(parser.data.entries[2].b).to eq(54)

        # last entry is partial
        expect(parser.data.entries[3].a).to eq(55)
        expect(parser.data.entries[3].b).to be_nil
      end

      it 'handles validation error in seq' do
        opts = {}
        compiler = KSYCompiler.new(opts)
        parser = Parser.new(compiler, 'input/7bytes.bin', ['formats/valid_fail.ksy'], opts)

        exc = parser.load

        expect(exc).to be_a(Kaitai::Struct::ValidationNotEqualError)

        expect(parser.data.class::SEQ_FIELDS).to eq(%w[a b c])
        expect(parser.data.a).to eq('12')
        expect(parser.data._debug['a']).to eq({ start: 0, end: 2 })
        expect(parser.data.b).to eq('34')
        expect(parser.data._debug['b']).to eq({ start: 2, end: 4 })
        expect(parser.data.c).to be_nil
        expect(parser.data._debug['c']).to be_nil
      end

      it 'handles nil usage in size in seq' do
        opts = {}
        compiler = KSYCompiler.new(opts)
        parser = Parser.new(compiler, 'input/rely_on_nil.bin', ['formats/rely_on_nil.ksy'], opts)

        exc = parser.load

        # read_bytes(len) when len is nil blows up with ArgumentError: comparison of Integer with nil failed
        expect(exc).to be_a(ArgumentError)

        expect(parser.data.class::SEQ_FIELDS).to eq(%w[has_len has_body len body])
        expect(parser.data.has_len).to eq(0)
        expect(parser.data._debug['has_len']).to eq({ start: 0, end: 1 })
        expect(parser.data.has_body).to eq(1)
        expect(parser.data._debug['has_body']).to eq({ start: 1, end: 2 })
        expect(parser.data.len).to be_nil
        expect(parser.data._debug['len']).to be_nil
        expect(parser.data.body).to be_nil
        expect(parser.data._debug['body']).to eq({ start: 2 })
      end

      it 'handles nil access error in seq' do
        opts = {}
        compiler = KSYCompiler.new(opts)
        parser = Parser.new(compiler, 'input/rely_on_nil.bin', ['formats/rely_on_nil2.ksy'], opts)

        exc = parser.load

        # len.value blows up because len is nil
        expect(exc).to be_a(NoMethodError)

        expect(parser.data.class::SEQ_FIELDS).to eq(%w[has_len has_body len body])
        expect(parser.data.has_len).to eq(0)
        expect(parser.data._debug['has_len']).to eq({ start: 0, end: 1 })
        expect(parser.data.has_body).to eq(1)
        expect(parser.data._debug['has_body']).to eq({ start: 1, end: 2 })
        expect(parser.data.len).to be_nil
        expect(parser.data._debug['len']).to be_nil
        expect(parser.data.body).to be_nil
        expect(parser.data._debug['body']).to eq({ start: 2 })
      end
    end
  end
end

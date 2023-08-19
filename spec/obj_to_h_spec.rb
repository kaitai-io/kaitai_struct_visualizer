# frozen_string_literal: true

require 'kaitai/struct/visualizer/obj_to_h'
require 'kaitai/struct/struct'

module Kaitai::Struct::Visualizer
  # rubocop:disable Lint/UnderscorePrefixedVariableName
  class SimpleKSObject < Kaitai::Struct::Struct
    attr_reader :foo

    def initialize(_io, _parent = nil, _root = self)
      super(_io, _parent, _root)
      @foo = 42
    end
  end

  class FullKSObject < Kaitai::Struct::Struct
    attr_reader :int_val, :str_val, :bool_val, :float_val, :bytes, :int_array, :str_array, :bool_array, :float_array

    def initialize(_io, _parent = nil, _root = self)
      super(_io, _parent, _root)
      @int_val = 42
      @str_val = 'foo'
      @bool_val = true
      @float_val = 3.14
      @bytes = [0x01, 0x02, 0x80, 0xAB].pack('C*')
      @int_array = [1, 2, 3]
      @str_array = %w[foo bar]
      @bool_array = [true, false]
      @float_array = [1.0, 2.0]
    end
  end

  class CompositeKSObject < Kaitai::Struct::Struct
    attr_reader :single, :arr

    def initialize(_io, _parent = nil, _root = self)
      super(_io, _parent, _root)
      @single = SimpleKSObject.new(@_io)
      @arr = Array.new(2) { SimpleKSObject.new(@_io) }
    end

    def instance_field
      return @instance_field unless @instance_field.nil?

      @instance_field = 42
      @instance_field
    end
  end
  # rubocop:enable Lint/UnderscorePrefixedVariableName

  describe :obj_to_h do
    it 'dumps a simple KS object' do
      obj = SimpleKSObject.new(nil)
      expect(Kaitai::Struct::Visualizer.obj_to_h(obj)).to eq({ 'foo' => 42 })
    end

    it 'dumps a full KS object' do
      obj = FullKSObject.new(nil)
      expect(Kaitai::Struct::Visualizer.obj_to_h(obj)).to eq(
        {
          'int_val' => 42,
          'str_val' => 'foo',
          'bool_val' => true,
          'float_val' => 3.14,
          'bytes' => '01 02 80 AB',
          'int_array' => [1, 2, 3],
          'str_array' => %w[foo bar],
          'bool_array' => [true, false],
          'float_array' => [1.0, 2.0]
        }
      )
    end

    it 'dumps a composite KS object' do
      obj = CompositeKSObject.new(nil)
      expect(Kaitai::Struct::Visualizer.obj_to_h(obj)).to eq(
        {
          'instance_field' => 42,
          'single' => { 'foo' => 42 },
          'arr' => [
            { 'foo' => 42 },
            { 'foo' => 42 }
          ]
        }
      )
    end
  end
end

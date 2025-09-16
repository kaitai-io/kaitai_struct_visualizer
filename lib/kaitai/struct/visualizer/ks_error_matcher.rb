# frozen_string_literal: true

require 'kaitai/struct/struct'

module Kaitai::Struct::Visualizer
  class KSErrorMatcher
    def self.===(exc)
      return true if exc.is_a?(EOFError)
      return true if exc.is_a?(ArgumentError)
      return true if exc.is_a?(NoMethodError)
      return true if exc.is_a?(TypeError)

      # Raised by the runtime library's seek() implementation for negative offsets, see
      # https://github.com/kaitai-io/kaitai_struct_ruby_runtime/blob/0fa62e64949f68cb001b58b7b45e15580d154ac9/lib/kaitai/struct/struct.rb#L637
      return true if exc.is_a?(Errno::EINVAL)

      # KaitaiStructError is a common ancestor of all Validation*Error and
      # UndecidedEndiannessError classes since 0.9. However, it doesn't exist in
      # the runtime library before 0.9, so we first make sure it's defined
      # before we access it (accessing an undefined item would result in a
      # NameError).
      return true if
        defined?(Kaitai::Struct::KaitaiStructError) &&
        exc.is_a?(Kaitai::Struct::KaitaiStructError)
      # Since 0.9, UndecidedEndiannessError is a subclass of KaitaiStructError
      # (which was already handled above), but in 0.8 it was derived directly
      # from Exception (in which case it hasn't been handled yet). Also,
      # switchable default endianness is a new feature in 0.8, so the
      # UndecidedEndiannessError class doesn't exist in older runtimes at all.
      return true if
        defined?(Kaitai::Struct::Stream::UndecidedEndiannessError) &&
        exc.is_a?(Kaitai::Struct::Stream::UndecidedEndiannessError)
      # UnexpectedDataError is no longer thrown by KSC-generated code since 0.9 -
      # it has been superseded by ValidationNotEqualError. It still exists
      # even in the 0.10 runtime library, but it will be removed one day, so
      # we'll also check if it's defined.
      return true if
        defined?(Kaitai::Struct::Stream::UnexpectedDataError) &&
        exc.is_a?(Kaitai::Struct::Stream::UnexpectedDataError)

      false
    end
  end
end

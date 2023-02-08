# frozen_string_literal: true

require 'kaitai/struct/struct'

module Kaitai::Struct::Visualizer
  class KSErrorMatcher
    def self.===(exc)
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

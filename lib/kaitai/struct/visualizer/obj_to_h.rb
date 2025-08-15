# frozen_string_literal: true

module Kaitai::Struct::Visualizer
  # Recursively convert object received from Kaitai Struct to a hash.
  # Used by ksdump to prepare data for JSON/XML/YAML output.
  def self.obj_to_h(obj)
    if (obj == true) || (obj == false) || obj.is_a?(Numeric) || obj.nil?
      obj
    elsif obj.is_a?(Symbol)
      obj.to_s
    elsif obj.is_a?(String)
      if obj.encoding == Encoding::ASCII_8BIT
        r = +''
        obj.each_byte { |x| r << format('%02X ', x) }
        r.chop!
        r
      else
        obj.encode('UTF-8')
      end
    elsif obj.is_a?(Array)
      obj.map { |x| obj_to_h(x) }
    else
      return "OPAQUE (#{obj.class})" unless obj.is_a?(Kaitai::Struct::Struct)

      root = {}

      prop_meths = obj.public_methods(false)
      prop_meths.sort.each do |meth|
        k = meth.to_s
        next if (k.start_with?('_') && !k.start_with?('_unnamed')) || meth == :to_s

        el = obj.send(meth)
        v = obj_to_h(el)
        root[k] = v unless v.nil?
      end

      root
    end
  end
end

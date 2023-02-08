# attr_bad_key.ksy: /seq/1/blah:
# 	error: unknown key found, expected: consume, contents, doc, doc-ref, eos-error, id, if, include, pad-right, parent, process, repeat, size, size-eos, terminator, type, valid
#
meta:
  id: attr_bad_key
  endian: le
seq:
  - id: foo
    type: u2
  - id: bar
    type: kazam
    blah: 1.234

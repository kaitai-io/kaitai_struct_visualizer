# Input file only has 7 bytes, but we aim to load 5x 2-byte objects as array.
# Expected to have 3 objects + 1 partial object.

meta:
  id: partial_array_struct
seq:
  - id: entries
    repeat: expr
    repeat-expr: 5
    type: entry
types:
  entry:
    seq:
      - id: a
        type: u1
      - id: b
        type: u1

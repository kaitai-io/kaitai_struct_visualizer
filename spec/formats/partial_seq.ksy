# We aim to load 5 bytes + 5 bytes, but input file only has 7 bytes.
# Expected to have "foo" of 5 bytes and no "bar".

meta:
  id: partial_seq
seq:
  - id: foo
    size: 5
  - id: bar
    size: 5

# We have file with "1234567", and we will read "12", "34", "567".
# However, we expect middle part to be "FF".
# Expected to read "a", "b" (erroneously) and no "c".

meta:
  id: valid_fail
seq:
  - id: a
    size: 2
  - id: b
    contents: "FF"
  - id: c
    size: 3

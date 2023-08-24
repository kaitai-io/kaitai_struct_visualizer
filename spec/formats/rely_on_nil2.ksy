# Two flags first, then length, then body.
# It would work for [1, 1, 3, "abc"].
# It would work for [0, 0].
# It is expected to blow up due to nil class access on [0, 1, 3, "abc"]

meta:
  id: rely_on_nil2
seq:
  - id: has_len
    type: u1
  - id: has_body
    type: u1
  - id: len
    type: int_container
    if: has_len == 1
  - id: body
    size: len.value
    if: has_body == 1
types:
  int_container:
    seq:
      - id: value
        type: u1

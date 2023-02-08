# attr_bad_if2.ksy: /types/foo_type/instances/foo/if:
# 	error: invalid type: expected boolean, got CalcIntType
#
meta:
  id: attr_bad_if2
seq:
  - id: foo
    type: strz
    encoding: ASCII
  - id: bar
    type: foo_type
types:
  foo_type:
    instances:
      foo:
        pos: 5
        type: u1
        if: _parent.foo.to_i - 4

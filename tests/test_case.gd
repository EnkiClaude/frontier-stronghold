class_name TestCase
extends RefCounted
## Minimal base class for headless unit tests (see tests/run_tests.gd).
## Test methods are any methods whose name starts with "test_".

var failures := PackedStringArray()
var current_test := ""


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_fail("expected true. " + msg)


func assert_false(cond: bool, msg: String = "") -> void:
	if cond:
		_fail("expected false. " + msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if not _equal(actual, expected):
		_fail("expected <%s> but got <%s>. %s" % [expected, actual, msg])


func assert_ne(actual: Variant, other: Variant, msg: String = "") -> void:
	if _equal(actual, other):
		_fail("expected value different from <%s>. %s" % [other, msg])


func _equal(a: Variant, b: Variant) -> bool:
	var ta := typeof(a)
	var tb := typeof(b)
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if ta in numeric and tb in numeric:
		return is_equal_approx(float(a), float(b))
	if ta != tb:
		return false
	return a == b


func _fail(msg: String) -> void:
	failures.append("%s: %s" % [current_test, msg])

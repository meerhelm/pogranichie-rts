class_name Num
## Whole numbers out of untyped data (mission rules and setup, saved dictionaries): the one place
## a Variant is turned into an int, as int() does, so typed code takes it without a warning.


static func of(v: Variant) -> int:
	@warning_ignore("unsafe_call_argument")
	return int(v)

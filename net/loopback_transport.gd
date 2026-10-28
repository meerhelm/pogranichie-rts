class_name LoopbackTransport
extends NetTransport
## Two ends of a connection in one process, for tests: what one end sends, the other receives
## at its poll(). `lag_polls` holds packets back for that many polls of the receiving end, to
## play a slow line.

var lag_polls := 0
var other: LoopbackTransport
var _inbox: Array[Array] = []
var _open := true
var _announced := false


## Two connected ends.
static func pair() -> Array[LoopbackTransport]:
	var a := LoopbackTransport.new()
	var b := LoopbackTransport.new()
	a.other = b
	b.other = a
	return [a, b]


func send(data: PackedByteArray) -> void:
	if _open and other != null and other._open:
		other._inbox.append([data, other.lag_polls])


func poll() -> void:
	if not _announced and _open:
		_announced = true
		connected.emit()
	var due: Array[PackedByteArray] = []
	while not _inbox.is_empty() and _polls_left(_inbox[0]) <= 0:
		var first: Array = _inbox.pop_front()
		var bytes: PackedByteArray = first[0]
		due.append(bytes)
	for item: Array in _inbox:
		item[1] = _polls_left(item) - 1
	for data in due:
		received.emit(data)
	if not _open:
		return
	if other == null or not other._open:
		_open = false
		disconnected.emit()


func is_connected_to_peer() -> bool:
	return _open and other != null and other._open


func close() -> void:
	_open = false


## Polls an inbox item [data, polls] waits before it is delivered.
static func _polls_left(item: Array) -> int:
	var polls: int = item[1]
	return polls

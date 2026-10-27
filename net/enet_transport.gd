class_name EnetTransport
extends NetTransport
## Direct connection over UDP with Godot's ENet: the host listens on a port, the guest connects
## to its address. Works on a local network and over the internet when the host's port is open
## (forwarded on the router); Steam's relay (later) is for players behind routers.

const DEFAULT_PORT := 24610
## ENet channel; one is enough, everything is reliable and ordered.
const CHANNEL := 0
## Milliseconds without an answer before ENet gives the other side up.
const TIMEOUT_MSEC := 15_000

var _peer: ENetMultiplayerPeer
var _host := false
var _connected := false
var _port := 0
## Set by ENet's signals during _peer.poll() and acted on after it: closing the peer from inside
## its own poll crashes the engine.
var _joined_id := 0
var _lost := false


## Listens for one player on the port. Returns OK or the error.
func host(port: int = DEFAULT_PORT) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, 1)
	if err != OK:
		_peer = null
		return err
	_host = true
	_port = port
	_hook()
	return OK


## Connects to a host. The result comes later as `connected` or `disconnected`.
func join(address: String, port: int = DEFAULT_PORT) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	_host = false
	_port = port
	_hook()
	return OK


func _hook() -> void:
	_peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	_peer.transfer_channel = CHANNEL
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)


func send(data: PackedByteArray) -> void:
	if _peer == null or not _connected:
		return
	_peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	_peer.put_packet(data)


func poll() -> void:
	if _peer == null:
		return
	_peer.poll()
	if _joined_id != 0 and not _connected:
		_on_joined(_joined_id)
	while _peer != null and _peer.get_available_packet_count() > 0:
		received.emit(_peer.get_packet())
	if _peer == null:
		return
	# A guest whose host never answers ends here, with no peer_disconnected.
	var gone := _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED
	if _lost or (not _host and gone):
		_drop()


func is_connected_to_peer() -> bool:
	return _connected


func close() -> void:
	if _peer == null:
		return
	var p := _peer
	_peer = null
	_connected = false
	_joined_id = 0
	_lost = false
	# What was sent last (the goodbye) goes out before the connection closes.
	if p.host != null:
		p.host.flush()
	p.close()


func describe() -> String:
	var mine := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			mine.append(a)
	if mine.is_empty():
		return "port %d" % _port  # notr
	var out := PackedStringArray()
	for a in mine:
		out.append("%s:%d" % [a, _port] if _port != DEFAULT_PORT else a)
	return ", ".join(out)


func _on_peer_connected(id: int) -> void:
	if _joined_id == 0:
		_joined_id = id


func _on_joined(id: int) -> void:
	_connected = true
	var enet := _peer.get_peer(id)
	if enet != null:
		enet.set_timeout(TIMEOUT_MSEC / 3, TIMEOUT_MSEC / 2, TIMEOUT_MSEC)
	if _host:
		# One opponent is all a 1v1 game takes.
		_peer.refuse_new_connections = true
	connected.emit()


func _on_peer_disconnected(_id: int) -> void:
	_lost = true


func _drop() -> void:
	var was := _peer != null
	close()
	if was:
		disconnected.emit()

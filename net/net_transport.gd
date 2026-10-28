class_name NetTransport
extends RefCounted
## How two players' games reach each other: one reliable, ordered stream of packets between
## exactly two peers. Lockstep and NetSession talk only to this, so the direct connection
## (EnetTransport) can later be joined by Steam's lobbies and relay without touching them.
## Nothing happens on its own: the owner calls poll() every frame, and the signals come from it.

## The other side is there (for the host: a player joined; for the guest: the host answered).
@warning_ignore("unused_signal")
signal connected
## The other side is gone, or the connection could not be made.
@warning_ignore("unused_signal")
signal disconnected
@warning_ignore("unused_signal")
signal received(data: PackedByteArray)


## Sends one packet to the other side, reliably and in order. Does nothing when not connected.
func send(_data: PackedByteArray) -> void:
	pass


## Delivers what has arrived (received, connected, disconnected).
func poll() -> void:
	pass


func is_connected_to_peer() -> bool:
	return false


func close() -> void:
	pass


## A short description of where this side can be reached, for the host's waiting screen.
func describe() -> String:
	return ""

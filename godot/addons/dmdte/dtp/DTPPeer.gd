class_name DTPPeer2 extends Node

var uuid: String
var outlet: DTPOutlet
var handle: RefCounted

signal message(message: DTPMessage)

func _ready() -> void:
	pass

func dispatch(message: DTPMessage):
	outlet.dispatch(self, message)

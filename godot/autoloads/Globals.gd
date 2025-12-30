extends Node

var bullet_container:Node


var PLAYER_COLORS:Dictionary[String, Color] = {
	"P1" : Color("006ad4ff"),
	"P2" : Color("de0004ff"),
	"P3" : Color("00cc1fff"),
	"P4" : Color("ffcc00ff"),
}



func getPlayerColors() -> Dictionary[String, Color]:
	return PLAYER_COLORS

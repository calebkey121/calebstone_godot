class_name CardData
extends Resource
enum STATE { IDLE, READY, ATTACK, TARGET }
var name: String
var attack: int
var health: int
var cost: int
var text: String
var art_texture: String
var type: String

func _init(data: Dictionary):
	self.name = data.get("name", "")
	self.attack = data.get("attack", 0)
	self.health = data.get("health", 0)
	self.cost = data.get("cost", 0)
	self.text = data.get("text", "")
	self.type = "card"

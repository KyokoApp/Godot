extends VBoxContainer
## Cosmetic skin switch only: no player respawn, cooldown reset, or duplicated pet.

const Character = preload("res://src/game/mannequin.gd")
const Card = preload("res://src/game/ui/character_card.gd")
const KANNA_PORTRAIT = preload("res://assets/characters/kanna/portrait.png")
const MIKU_PORTRAIT = preload("res://assets/characters/miku/portrait.png")
const MANNEQUIN_PORTRAIT = preload("res://src/game/ui/mannequin_portrait.svg")

var character: Character
var _cards: Array[Card] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_add_card(Character.MIKU, "Miku", MIKU_PORTRAIT)
	_add_card(Character.KANNA, "Kanna", KANNA_PORTRAIT)
	_add_card(Character.MANNEQUIN, "Mannequin", MANNEQUIN_PORTRAIT)
	character.skin_changed.connect(_refresh)
	_refresh(character.skin_id)


func _add_card(id: String, label: String, portrait: Texture2D) -> void:
	var card := Card.new()
	card.name = id
	card.character_name = label
	card.portrait = portrait
	card.custom_minimum_size = Vector2(208, 68)
	card.pressed.connect(func() -> void: character.set_skin(id))
	add_child(card)
	_cards.append(card)


func _refresh(id: String) -> void:
	for card in _cards:
		card.selected = str(card.name) == id
		card.queue_redraw()

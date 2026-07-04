extends Node2D
class_name Anchor

signal weight_type_changed(weight_mode: WeightMode, gravity_value: float)
signal bound_character_changed(bound_character)

enum WeightMode {
	LIGHT,
	HEAVY,
}

@export var gravity_value: float = -1.0
@export var light_gravity_value: float = -1.0
@export var heavy_gravity_value: float = 1.0
@export var rope_attach_offset_light: Vector2 = Vector2(0, 11)
@export var rope_attach_offset_heavy: Vector2 = Vector2(0, -11)

var bound_character

@onready var sprite: Sprite2D = $Sprite2D
@onready var rope_attach_point: Marker2D = $RopeAttachPoint


func _ready() -> void:
	_refresh_visual_state()
	weight_type_changed.emit(GetWeightMode(), gravity_value)


func GravityValueToWeightMode(value: float) -> WeightMode:
	if value > 0.0:
		return WeightMode.HEAVY
	return WeightMode.LIGHT


func GetWeightMode() -> WeightMode:
	return GravityValueToWeightMode(gravity_value)


func ChangeWeightType(next_mode: WeightMode) -> void:
	gravity_value = _weight_mode_to_gravity_value(next_mode)
	_refresh_visual_state()
	weight_type_changed.emit(GetWeightMode(), gravity_value)


func CycleWeightType() -> void:
	match GetWeightMode():
		WeightMode.LIGHT:
			ChangeWeightType(WeightMode.HEAVY)
		WeightMode.HEAVY:
			ChangeWeightType(WeightMode.LIGHT)


func BindCharacter(character) -> void:
	if bound_character == character:
		return
	bound_character = character
	bound_character_changed.emit(bound_character)


func UnBindCharacter(character = null) -> void:
	if character != null and bound_character != character:
		return
	bound_character = null
	bound_character_changed.emit(bound_character)


func GetRopeAttachGlobalPosition() -> Vector2:
	return rope_attach_point.global_position


func _weight_mode_to_gravity_value(weight_mode: WeightMode) -> float:
	match weight_mode:
		WeightMode.LIGHT:
			return light_gravity_value
		WeightMode.HEAVY:
			return heavy_gravity_value
	return light_gravity_value


func _refresh_visual_state() -> void:
	var weight_mode := GetWeightMode()

	match weight_mode:
		WeightMode.LIGHT:
			sprite.frame = 0
			sprite.flip_v = false
			sprite.modulate = Color(0.64, 0.82, 1.0, 1.0)
			rope_attach_point.position = rope_attach_offset_light
		WeightMode.HEAVY:
			sprite.frame = 1
			sprite.flip_v = true
			sprite.modulate = Color(1.0, 0.72, 0.65, 1.0)
			rope_attach_point.position = rope_attach_offset_heavy

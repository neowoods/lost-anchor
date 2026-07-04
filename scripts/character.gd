extends CharacterBody2D
class_name Character

signal anchor_link_state_changed(is_linked: bool, anchor_node)
signal gravity_profile_changed(weight_mode: int, gravity_acceleration: float, gravity_direction: float)

enum WeightMode {
	LIGHT,
	HEAVY,
}

const NEUTRAL_WEIGHT_MODE := -1

@export var anchor_path: NodePath
@export var rope_line_path: NodePath
@export var move_speed: float = 260.0
@export var ground_acceleration: float = 1400.0
@export var ground_friction: float = 1800.0
@export var air_acceleration: float = 900.0
@export var jump_speed: float = 420.0
@export var fast_fall_multiplier: float = 1.35
@export var link_distance: float = 80.0
@export var light_anchor_gravity_scale: float = 0.55
@export var heavy_anchor_gravity_scale: float = 1.85
@export var idle_frames := Vector2i(0, 1)
@export var run_frames := Vector2i(2, 6)
@export var jump_frames := Vector2i(7, 8)
@export var idle_fps: float = 3.5
@export var run_fps: float = 10.0
@export var jump_fps: float = 5.0

var anchor
var default_gravity_acceleration: float
var default_gravity_direction: float = 1.0
var current_gravity_acceleration: float
var current_gravity_direction: float = 1.0
var is_anchor_linked := false
var facing_direction := 1
var animation_time := 0.0
var current_animation := ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var rope_origin: Marker2D = $RopeOrigin

var rope_line: Line2D


func _ready() -> void:
	default_gravity_acceleration = ProjectSettings.get_setting("physics/2d/default_gravity")
	current_gravity_acceleration = default_gravity_acceleration
	current_gravity_direction = default_gravity_direction
	_resolve_anchor_reference()
	_resolve_rope_line_reference()
	_refresh_up_direction()
	_sync_rope_visibility()
	_emit_gravity_profile_changed(_get_active_weight_mode())


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("link_anchor"):
		if is_anchor_linked:
			UnLinkAnchor()
		else:
			LinkAnchor(anchor)

	if Input.is_action_just_pressed("change_anchor_weight_type"):
		ChangeAnchorWeightType()

	if not is_on_floor():
		var gravity_multiplier := fast_fall_multiplier if Input.is_action_pressed("move_down") and velocity.y * current_gravity_direction > 0.0 else 1.0
		velocity.y += current_gravity_acceleration * current_gravity_direction * gravity_multiplier * delta

	if is_on_floor() and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("move_up")):
		Jump()

	var input_direction := Input.get_axis("move_left", "move_right")
	var target_speed := input_direction * move_speed
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	if absf(input_direction) > 0.0:
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		facing_direction = 1 if input_direction > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)

	_refresh_up_direction()
	move_and_slide()
	_update_rope_visual()
	_update_animation(delta, input_direction)


func Jump() -> void:
	velocity.y = -jump_speed * _get_reference_gravity_direction()


func LinkAnchor(target_anchor = anchor) -> void:
	if target_anchor == null:
		return
	if global_position.distance_to(target_anchor.global_position) > link_distance:
		return

	anchor = target_anchor
	is_anchor_linked = true
	anchor.BindCharacter(self)
	_apply_anchor_weight_mode(anchor.GetWeightMode())
	_sync_rope_visibility()
	anchor_link_state_changed.emit(true, anchor)


func UnLinkAnchor() -> void:
	if anchor != null:
		anchor.UnBindCharacter(self)

	is_anchor_linked = false
	current_gravity_acceleration = default_gravity_acceleration
	current_gravity_direction = default_gravity_direction
	_refresh_up_direction()
	_sync_rope_visibility()
	_emit_gravity_profile_changed(_get_active_weight_mode())
	anchor_link_state_changed.emit(false, anchor)


func ChangeAnchorWeightType() -> void:
	if anchor == null:
		return
	anchor.CycleWeightType()


func _resolve_anchor_reference() -> void:
	if anchor_path.is_empty():
		return

	anchor = get_node_or_null(anchor_path)
	if anchor != null and not anchor.weight_type_changed.is_connected(_on_anchor_weight_type_changed):
		anchor.weight_type_changed.connect(_on_anchor_weight_type_changed)


func _resolve_rope_line_reference() -> void:
	if rope_line_path.is_empty():
		return
	rope_line = get_node_or_null(rope_line_path) as Line2D


func _on_anchor_weight_type_changed(weight_mode: int, _gravity_value: float) -> void:
	if not is_anchor_linked:
		return
	_apply_anchor_weight_mode(weight_mode)


func _apply_anchor_weight_mode(weight_mode: int) -> void:
	match weight_mode:
		WeightMode.LIGHT:
			current_gravity_acceleration = default_gravity_acceleration * light_anchor_gravity_scale
			current_gravity_direction = default_gravity_direction
		WeightMode.HEAVY:
			current_gravity_acceleration = default_gravity_acceleration * heavy_anchor_gravity_scale
			current_gravity_direction = default_gravity_direction
		_:
			current_gravity_acceleration = default_gravity_acceleration
			current_gravity_direction = default_gravity_direction

	_refresh_up_direction()
	_emit_gravity_profile_changed(weight_mode)


func _refresh_up_direction() -> void:
	up_direction = Vector2.UP * _get_reference_gravity_direction()


func _get_reference_gravity_direction() -> float:
	if is_zero_approx(current_gravity_acceleration):
		return default_gravity_direction
	return current_gravity_direction


func _get_active_weight_mode() -> int:
	if is_anchor_linked and anchor != null:
		return anchor.GetWeightMode()
	return NEUTRAL_WEIGHT_MODE


func _emit_gravity_profile_changed(weight_mode: int) -> void:
	gravity_profile_changed.emit(weight_mode, current_gravity_acceleration, current_gravity_direction)


func _sync_rope_visibility() -> void:
	if rope_line == null:
		return
	rope_line.visible = is_anchor_linked and anchor != null
	if rope_line.visible:
		_update_rope_visual()


func _update_rope_visual() -> void:
	if rope_line == null or not rope_line.visible or anchor == null:
		return
	var parent_node := rope_line.get_parent() as Node2D
	if parent_node == null:
		return

	rope_line.set_point_position(0, parent_node.to_local(rope_origin.global_position))
	rope_line.set_point_position(1, parent_node.to_local(anchor.GetRopeAttachGlobalPosition()))


func _update_animation(delta: float, input_direction: float) -> void:
	sprite.flip_h = facing_direction < 0

	if not is_on_floor():
		_set_animation("jump")
		animation_time += delta
		sprite.frame = _loop_frames(jump_frames, jump_fps)
		return

	if absf(input_direction) > 0.0 and absf(velocity.x) > 5.0:
		_set_animation("run")
		animation_time += delta
		sprite.frame = _loop_frames(run_frames, run_fps)
		return

	_set_animation("idle")
	animation_time += delta
	sprite.frame = _loop_frames(idle_frames, idle_fps)


func _set_animation(next_animation: String) -> void:
	if current_animation == next_animation:
		return
	current_animation = next_animation
	animation_time = 0.0


func _loop_frames(frame_range: Vector2i, fps: float) -> int:
	var frame_count := frame_range.y - frame_range.x + 1
	if frame_count <= 1 or fps <= 0.0:
		return frame_range.x
	return frame_range.x + int(animation_time * fps) % frame_count

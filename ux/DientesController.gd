extends Node3D
class_name DientesController
##
## Control de visualización y rotación de modelos 3D de dientes.
## Estructura esperada:
## Dientes (este script)
## └─ dientes
##    └─ RigidBody3D
##       ├─ Incisivo (MeshInstance3D)
##       ├─ Canino   (MeshInstance3D)
##       ├─ Premolar (MeshInstance3D)
##       ├─ Molar    (MeshInstance3D)
##       └─ CollisionShape3D
##

# ---------------------- Export / Ajustes ----------------------
@export_node_path var rb_path: NodePath = "dientes/RigidBody3D"
@export var rotate_speed := 0.01               # arrastre mouse/puntero
@export var grab_rotate_speed := 2.0           # giro por GRAB (rad/seg aprox)
@export var enable_layers := [21, 23]          # capas XR para puntero
@export var freeze_physics := true
@export var start_hidden := true

# ---------------------- Referencias ---------------------------
@onready var rb: RigidBody3D = get_node(rb_path)
@onready var mesh_canino: MeshInstance3D   = _get_mesh("Canino")
@onready var mesh_incisivo: MeshInstance3D = _get_mesh("Incisivo")
@onready var mesh_premolar: MeshInstance3D = _get_mesh("Premolar")
@onready var mesh_molar: MeshInstance3D    = _get_mesh("Molar")
@onready var collider: CollisionObject3D   = _get_collider()

# Drag (mouse/puntero)
var _dragging := false
var _last_mouse_pos := Vector2.ZERO

# GRAB (XRTools u otro): rota según la velocidad de movimiento del controlador
var _grab_controller: Node3D = null
var _last_grab_pos: Vector3
var _grab_active := false

func _ready() -> void:
	if freeze_physics and rb:
		rb.freeze = true
		rb.can_sleep = true

	if collider:
		collider.input_pickable = true
		_connect_input_event()

	if rb:
		for l in enable_layers:
			rb.set_collision_layer_value(l, true)
			rb.set_collision_mask_value(l, true)

	if start_hidden:
		_hide_all_meshes()

func _process(delta: float) -> void:
	if _grab_active and _grab_controller and rb:
		# Rotación simple basada en desplazamiento del controlador
		var p := _grab_controller.global_transform.origin
		var delta_vec := p - _last_grab_pos
		_last_grab_pos = p

		# Interpreta el movimiento lateral/vertical como yaw/pitch
		rb.rotate_y(-delta_vec.x * grab_rotate_speed)
		rb.rotate_x( delta_vec.y * grab_rotate_speed)

# ---------------------- Utilitarios internos ------------------
func _get_mesh(name_str: String) -> MeshInstance3D:
	if rb and rb.has_node(name_str):
		return rb.get_node(name_str) as MeshInstance3D
	if rb:
		return rb.find_child(name_str, true, false) as MeshInstance3D
	return null

func _get_collider() -> CollisionObject3D:
	if rb:
		var col := rb.get_node_or_null("CollisionShape3D")
		if col: return col as CollisionObject3D
		return rb as CollisionObject3D
	return null

func _connect_input_event() -> void:
	if collider and not collider.is_connected("input_event", Callable(self, "_on_collider_input_event")):
		collider.input_event.connect(_on_collider_input_event)

func _hide_all_meshes() -> void:
	if mesh_canino:   mesh_canino.visible = false
	if mesh_incisivo: mesh_incisivo.visible = false
	if mesh_premolar: mesh_premolar.visible = false
	if mesh_molar:    mesh_molar.visible = false

func _show_only(node: MeshInstance3D) -> void:
	_hide_all_meshes()
	if node:
		node.visible = true

# ---------------------- API pública ---------------------------
func show_tooth_mesh(kind: String) -> void:
	var k := kind.to_lower()
	match k:
		"canino":   _show_only(mesh_canino)
		"incisivo": _show_only(mesh_incisivo)
		"premolar": _show_only(mesh_premolar)
		"molar":    _show_only(mesh_molar)
		_: push_warning("Tipo de diente desconocido: %s" % kind)

func show_tooth_index(idx: int) -> void:
	match idx:
		0: _show_only(mesh_incisivo)
		1: _show_only(mesh_canino)
		2: _show_only(mesh_premolar)
		3: _show_only(mesh_molar)
		_: push_warning("Índice de diente desconocido: %s" % str(idx))

func rotate_with_axis(axis: Vector2) -> void:
	if rb == null: return
	rb.rotate_y(-axis.x * rotate_speed * 8.0)
	rb.rotate_x(-axis.y * rotate_speed * 8.0)

func reset_orientation() -> void:
	if rb == null: return
	rb.rotation = Vector3.ZERO

func set_rotate_speed(s: float) -> void:
	rotate_speed = max(s, 0.0)

func set_pointer_layers_enabled(enabled: bool) -> void:
	if rb == null: return
	for l in enable_layers:
		rb.set_collision_layer_value(l, enabled)
		rb.set_collision_mask_value(l, enabled)

# ------ Integración GRAB (XRTools u otro) ------
## Llama a esto al recibir "grabbed(controller)" desde tu Interactable
func start_grab(controller: Node3D) -> void:
	_grab_controller = controller
	_last_grab_pos = controller.global_transform.origin
	_grab_active = true

## Llama a esto al recibir "released" desde tu Interactable
func stop_grab() -> void:
	_grab_active = false
	_grab_controller = null

# ---------------------- Input (mouse/puntero) -----------------
func _on_collider_input_event(_cam, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		_last_mouse_pos = (event as InputEventMouseButton).position
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _last_mouse_pos
		_last_mouse_pos = motion.position
		if rb:
			rb.rotate_y(-delta.x * rotate_speed)  # yaw
			rb.rotate_x(-delta.y * rotate_speed)  # pitch

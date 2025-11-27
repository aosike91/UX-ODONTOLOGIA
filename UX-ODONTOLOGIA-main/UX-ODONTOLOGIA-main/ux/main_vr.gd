# main_vr.gd — Script principal VR
extends Node3D

# ------------------- Referencias -------------------
@onready var xr_origin: XROrigin3D = $XROrigin3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var menu_controller: Node3D = $Menu  # Ajusta la ruta si es diferente

# ------------------- Posiciones de cámara -------------------
const POS_MENU := Vector3(6.707, 3.1, 2.486)
const ROT_MENU := Vector3(0, 78.2, 0)  # En grados

const POS_SIMULACION := Vector3(1.329, 4.953, 4.338)
const ROT_SIMULACION := Vector3(0, 78.2, 0)  # En grados

# ------------------- Variables de transición -------------------
var _transitioning: bool = false
var _tween_camera: Tween = null
var _tween_fade: Tween = null
var _tween_feedback: Tween = null

const FADE_DURATION := 0.5
const FEEDBACK_DURATION := 0.4

# ------------------- Ciclo de vida -------------------
func _ready() -> void:
	# Posición inicial
	_set_xr_origin_transform(POS_MENU, ROT_MENU)
	
	# Conectar señales del MenuController
	if menu_controller:
		if menu_controller.has_signal("simulacion_iniciada"):
			menu_controller. simulacion_iniciada.connect(_on_simulacion_iniciada)
		if menu_controller.has_signal("simulacion_terminada"):
			menu_controller.simulacion_terminada.connect(_on_simulacion_terminada)
		if menu_controller.has_signal("diagnostico_correcto"):
			menu_controller.diagnostico_correcto.connect(_on_diagnostico_correcto)
		if menu_controller.has_signal("diagnostico_incorrecto"):
			menu_controller.diagnostico_incorrecto.connect(_on_diagnostico_incorrecto)

# ------------------- Transición de cámara con fade -------------------
func _on_simulacion_iniciada() -> void:
	if _transitioning:
		return
	await _transition_to_position(POS_SIMULACION, ROT_SIMULACION)

func _on_simulacion_terminada() -> void:
	if _transitioning:
		return
	await _transition_to_position(POS_MENU, ROT_MENU)

func _transition_to_position(target_pos: Vector3, target_rot_deg: Vector3) -> void:
	_transitioning = true
	
	# Fase 1: Fade a negro (exposure 1 -> 0)
	await _fade_to_black()
	
	# Fase 2: Mover cámara instantáneamente mientras está oscuro
	_set_xr_origin_transform(target_pos, target_rot_deg)
	
	# Pequeña pausa en negro
	await get_tree().create_timer(0.2).timeout
	
	# Fase 3: Fade desde negro (exposure 0 -> 1)
	await _fade_from_black()
	
	_transitioning = false

func _set_xr_origin_transform(pos: Vector3, rot_deg: Vector3) -> void:
	if xr_origin:
		xr_origin. position = pos
		xr_origin.rotation_degrees = rot_deg

# ------------------- Fade (oscurecer/aclarar) -------------------
func _fade_to_black() -> void:
	if _tween_fade:
		_tween_fade. kill()
	
	_tween_fade = create_tween()
	_tween_fade.tween_method(_set_exposure, 1.0, 0.0, FADE_DURATION)
	await _tween_fade. finished

func _fade_from_black() -> void:
	if _tween_fade:
		_tween_fade.kill()
	
	_tween_fade = create_tween()
	_tween_fade.tween_method(_set_exposure, 0.0, 1.0, FADE_DURATION)
	await _tween_fade.finished

func _set_exposure(value: float) -> void:
	if world_environment and world_environment.environment:
		world_environment.environment.tonemap_exposure = value

# ------------------- Feedback de color (verde/rojo) -------------------
func _on_diagnostico_correcto() -> void:
	await _flash_color(Color(0.0, 1.0, 0.0))  # Verde

func _on_diagnostico_incorrecto() -> void:
	await _flash_color(Color(1.0, 0.0, 0.0))  # Rojo

func _flash_color(color: Color) -> void:
	if _tween_feedback:
		_tween_feedback.kill()
	
	if not world_environment or not world_environment. environment:
		return
	
	var env := world_environment. environment
	
	# Guardar color original del ambient light
	var original_color: Color = env.ambient_light_color
	var original_energy: float = env.ambient_light_energy
	
	_tween_feedback = create_tween()
	
	# Fase 1: Transición al color de feedback
	_tween_feedback. tween_method(
		func(c: Color): env.ambient_light_color = c,
		original_color,
		color,
		FEEDBACK_DURATION * 0.5
	)
	_tween_feedback. parallel().tween_method(
		func(e: float): env.ambient_light_energy = e,
		original_energy,
		2.0,  # Aumentar energía para que sea más visible
		FEEDBACK_DURATION * 0.5
	)
	
	# Fase 2: Volver al color original
	_tween_feedback. tween_method(
		func(c: Color): env.ambient_light_color = c,
		color,
		original_color,
		FEEDBACK_DURATION * 0.5
	)
	_tween_feedback. parallel().tween_method(
		func(e: float): env.ambient_light_energy = e,
		2.0,
		original_energy,
		FEEDBACK_DURATION * 0.5
	)
	
	await _tween_feedback.finished

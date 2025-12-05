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
const FEEDBACK_DURATION := 0.6  # Duración total del feedback de color
const FEEDBACK_FADE_OUT := 0.3  # Duración más rápida para volver a fog apagado

# ------------------- Configuración inicial del fog -------------------
var _fog_original_color: Color = Color.WHITE
var _fog_original_energy: float = 0.0  # Fog apagado por defecto

# ------------------- Ciclo de vida -------------------
func _ready() -> void:
	# Posición inicial
	_set_xr_origin_transform(POS_MENU, ROT_MENU)
	
	# Configurar fog inicial (apagado)
	_setup_initial_fog()
	
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

func _setup_initial_fog() -> void:
	if not world_environment or not world_environment.environment:
		push_warning("[MainVR] WorldEnvironment o Environment no encontrado")
		return
	
	var env := world_environment.environment
	
	# Asegurarse de que el fog esté habilitado en el Environment
	# (esto se hace en el editor, pero lo verificamos aquí)
	if env.fog_enabled:
		# Guardar configuración original
		_fog_original_color = env.fog_light_color
		_fog_original_energy = env.fog_light_energy
		
		# Establecer fog apagado (light_energy = 0)
		env.fog_light_energy = 0.0
		print("✅ Fog configurado: Light Energy = 0 (apagado)")
	else:
		push_warning("[MainVR] El fog no está habilitado en el Environment.  Actívalo en el Inspector.")

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

# =================================================================
#           FEEDBACK DE COLOR CON FOG (VERDE/ROJO)
# =================================================================
func _on_diagnostico_correcto() -> void:
	print("[Feedback] ✅ Diagnóstico correcto - Fog VERDE")
	await _flash_fog_color(Color(0.0, 1.0, 0.0))  # Verde

func _on_diagnostico_incorrecto() -> void:
	print("[Feedback] ❌ Diagnóstico incorrecto - Fog ROJO")
	await _flash_fog_color(Color(1.0, 0.0, 0.0))  # Rojo

func _flash_fog_color(color: Color) -> void:
	# Cancelar cualquier tween de feedback anterior
	if _tween_feedback:
		_tween_feedback.kill()
	
	if not world_environment or not world_environment. environment:
		push_warning("[MainVR] No se puede aplicar feedback: Environment no disponible")
		return
	
	var env := world_environment. environment
	
	if not env.fog_enabled:
		push_warning("[MainVR] El fog debe estar habilitado para el feedback visual")
		return
	
	_tween_feedback = create_tween()
	
	# ========== FASE 1: Activar fog con color (0 -> 1) ==========
	# Duración: Primera mitad del feedback
	_tween_feedback. tween_method(
		func(c: Color): env.fog_light_color = c,
		_fog_original_color,  # Color original (blanco o el que tengas)
		color,  # Color de feedback (verde o rojo)
		FEEDBACK_DURATION * 0.3  # 30% del tiempo
	)
	_tween_feedback.parallel().tween_method(
		func(e: float): env.fog_light_energy = e,
		0.0,  # Desde apagado
		1.0,  # A intensidad máxima
		FEEDBACK_DURATION * 0.3
	)
	
	# ========== FASE 2: Mantener el color un momento ==========
	_tween_feedback.tween_interval(FEEDBACK_DURATION * 0.2)  # 20% del tiempo
	
	# ========== FASE 3: Apagar fog rápidamente (1 -> 0) ==========
	# Duración: Más rápida para que desaparezca al cambiar de paciente
	_tween_feedback.tween_method(
		func(e: float): env.fog_light_energy = e,
		1.0,  # Desde intensidad máxima
		0.0,  # A apagado
		FEEDBACK_FADE_OUT  # Transición rápida
	)
	_tween_feedback.parallel().tween_method(
		func(c: Color): env. fog_light_color = c,
		color,  # Desde color de feedback
		_fog_original_color,  # A color original
		FEEDBACK_FADE_OUT
	)
	
	await _tween_feedback.finished
	
	# Asegurar que el fog quede completamente apagado
	env.fog_light_energy = 0.0
	print("[Feedback] Fog apagado - Light Energy = 0")

# MenuController.gd — Adjuntar al nodo raíz: Menu
extends Node3D

# ------------------- SEÑALES -------------------
signal simulacion_iniciada
signal simulacion_terminada
signal diagnostico_correcto
signal diagnostico_incorrecto

# ------------------- Referencias (paneles/botones) -------------------
@onready var cuadros_menu: Node            = $CuadrosMenu
@onready var cuadros_enfermedades: Node    = $CuadrosEnfermedades
@onready var enfermedades: Node            = $Enfermedades

@onready var back_button: Node             = $RegresarGlobal

@onready var btn_menu_op1: Node            = $"CuadrosMenu/Opcion1"  # Simulación de Casos
@onready var btn_menu_op2: Node            = $"CuadrosMenu/Opcion2"  # Dientes
@onready var btn_menu_op3: Node            = $"CuadrosMenu/Opcion3"

@onready var btn_cuadros_op1: Node         = $"CuadrosEnfermedades/Opcion1"
@onready var btn_cuadros_op2: Node         = $"CuadrosEnfermedades/Opcion2"
@onready var btn_cuadros_op3: Node         = $"CuadrosEnfermedades/Opcion3"

# ------------------- Simulación de Casos -------------------
@onready var simulacion_casos: Node        = $SimulacionCasos
@onready var btn_sim_op1: Node             = $"SimulacionCasos/Opcion1"  # Caries
@onready var btn_sim_op2: Node             = $"SimulacionCasos/Opcion2"  # Bruxismo
@onready var btn_sim_op3: Node             = $"SimulacionCasos/Opcion3"  # Gingivitis

@onready var pacientes: Node3D             = $"SimulacionCasos/Pacientes"
@onready var paciente_sano: Node3D         = $"SimulacionCasos/Pacientes/PacienteSano"
@onready var paciente_bruxismo: Node3D     = $"SimulacionCasos/Pacientes/PacienteBruxismo"
@onready var paciente_caries: Node3D       = $"SimulacionCasos/Pacientes/PacienteCaries"
@onready var paciente_gingivitis: Node3D   = $"SimulacionCasos/Pacientes/PacienteGingivitis"

@onready var btn_paciente_sano: Node       = $"SimulacionCasos/PacienteSano"
@onready var btn_regresar_atras: Node      = $"SimulacionCasos/RegresarAtras"

# Variables para la simulación
var _pacientes_disponibles: Array[Node3D] = []
var _paciente_actual: Node3D = null
var _simulacion_activa: bool = false

# ------------------- Opción 2: rama animada + label -------------------
var diente_parte: Node3D = null
var dientes_anim: AnimationPlayer = null
var label_3d: Label3D = null
var label_preview: Label3D = null  # ✨ NUEVO
var _tooth_bodies: Array[CollisionObject3D] = []

# ------------------- MODELOS 3D (familias) -------------------
var modelos_root: Node3D = null
var mesh_incisivo: MeshInstance3D = null
var mesh_canino: MeshInstance3D = null
var mesh_premolar: MeshInstance3D = null
var mesh_molar: MeshInstance3D = null
var _rotate_target: Node3D = null
@export var rotate_speed_deg: float = 45.0

# ------------------- Estado / Historial -------------------
enum StateType { PANEL, ENFER, TEETH, SIMULACION, DIAGNOSTICO }
var history: Array[Dictionary] = []
var current_state: Dictionary = {}

# ------------------- Ciclo de vida -------------------
func _ready() -> void:
	_render_state({"type": StateType.PANEL, "node": cuadros_menu})
	_update_back_visibility()

	# Menú principal
	_connect_button(btn_menu_op1, func(): _navigate_to({"type": StateType.SIMULACION}))
	_connect_button(btn_menu_op2, func(): _navigate_to({"type": StateType.TEETH}))
	_connect_button(btn_menu_op3, func(): _navigate_to({"type": StateType.PANEL, "node": cuadros_enfermedades}))

	# Cuadros enfermedades
	_connect_button(btn_cuadros_op1, func(): _navigate_to({"type": StateType. ENFER, "idx": 1}))
	_connect_button(btn_cuadros_op2, func(): _navigate_to({"type": StateType. ENFER, "idx": 2}))
	_connect_button(btn_cuadros_op3, func(): _navigate_to({"type": StateType. ENFER, "idx": 3}))

	_connect_button(back_button, _go_back)

	# Simulación de casos - botones de diagnóstico
	_connect_button(btn_sim_op1, func(): _verificar_diagnostico("caries"))
	_connect_button(btn_sim_op2, func(): _verificar_diagnostico("bruxismo"))
	_connect_button(btn_sim_op3, func(): _verificar_diagnostico("gingivitis"))
	_connect_button(btn_paciente_sano, func(): _verificar_diagnostico("sano"))
	_connect_button(btn_regresar_atras, _salir_simulacion)

	_init_teeth_refs()
	_init_models_refs()
	_setup_teeth_branch()
	_hide_all_family_meshes()
	_rotate_target = null

	# Ocultar simulación completa al inicio
	if simulacion_casos:
		_set_branch_enabled(simulacion_casos, false)

func _process(delta: float) -> void:
	if _rotate_target != null:
		_rotate_target.rotate_z(deg_to_rad(rotate_speed_deg) * delta)

# ------------------- Navegación con pila -------------------
func _navigate_to(new_state: Dictionary) -> void:
	if current_state.size() > 0:
		history.push_back(current_state.duplicate(true))
	_render_state(new_state)
	_update_back_visibility()

func _go_back() -> void:
	if history.is_empty():
		return
	var prev: Dictionary = history.pop_back()
	_render_state(prev)
	_update_back_visibility()

# ------------------- Renderizado de estados -------------------
func _render_state(state: Dictionary) -> void:
	_set_branch_enabled(cuadros_menu, false)
	_set_branch_enabled(cuadros_enfermedades, false)
	_set_branch_enabled(simulacion_casos, false)

	enfermedades. process_mode = Node.PROCESS_MODE_DISABLED
	if enfermedades is Node3D:
		(enfermedades as Node3D).visible = false
	for child in enfermedades.get_children():
		_set_branch_enabled(child, false)

	# Reset antes de cambiar
	_init_teeth_refs()
	_init_models_refs()
	_hide_label()
	_hide_tooth_preview()  # ✨ NUEVO
	_disable_teeth_layers()
	if diente_parte:
		_set_branch_enabled(diente_parte, false)
	_hide_all_family_meshes()
	_rotate_target = null

	match state. get("type"):
		StateType.PANEL:
			_simulacion_activa = false
			var panel: Node = state.get("node", null)
			if panel:
				_set_branch_enabled(panel, true)

		StateType.ENFER:
			_simulacion_activa = false
			var idx: int = state.get("idx", 0)
			enfermedades.process_mode = Node.PROCESS_MODE_INHERIT
			if enfermedades is Node3D:
				(enfermedades as Node3D).visible = true
			var sel_path: String = "Opcion%d" % idx
			if enfermedades.has_node(sel_path):
				_set_branch_enabled(enfermedades. get_node(sel_path), true)

		StateType. TEETH:
			_simulacion_activa = false
			if not _ensure_teeth_exist():
				return
			await _show_teeth_sequence()

		StateType.SIMULACION:
			_iniciar_simulacion()

		StateType.DIAGNOSTICO:
			pass

	current_state = state

# ------------------- Utilitarios de interfaz -------------------
func _update_back_visibility() -> void:
	var show: bool = history.size() > 0 and not _simulacion_activa
	_set_branch_enabled(back_button, show)

func _set_branch_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	node.process_mode = (Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED)
	if node is Node3D:
		(node as Node3D).visible = enabled
	if node is CollisionObject3D:
		(node as CollisionObject3D). set_deferred("disabled", not enabled)
	for c in node.get_children():
		_set_branch_enabled(c, enabled)

func _connect_button(btn: Node, callback: Callable) -> void:
	if btn == null:
		return
	if btn.has_signal("button_selected"):
		btn.button_selected.connect(func(_n): callback. call())
	elif btn.has_signal("input_event"):
		btn.input_event.connect(func(_cam, event, _pos, _normal, _shape_idx):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				callback.call()
		)

# =================================================================
#                      SIMULACIÓN DE CASOS
# =================================================================
func _iniciar_simulacion() -> void:
	_simulacion_activa = true
	
	# Emitir señal para mover cámara
	simulacion_iniciada.emit()
	
	# Ocultar menú principal y botón regresar global
	_set_branch_enabled(cuadros_menu, false)
	_set_branch_enabled(back_button, false)
	
	# Mostrar panel de simulación (botones de diagnóstico)
	_set_branch_enabled(simulacion_casos, true)
	
	# Ocultar TODOS los pacientes primero
	_hide_all_pacientes()
	
	# Reiniciar lista de pacientes disponibles
	_pacientes_disponibles. clear()
	if paciente_sano:
		_pacientes_disponibles.append(paciente_sano)
	if paciente_bruxismo:
		_pacientes_disponibles. append(paciente_bruxismo)
	if paciente_caries:
		_pacientes_disponibles.append(paciente_caries)
	if paciente_gingivitis:
		_pacientes_disponibles.append(paciente_gingivitis)
	
	print("[Simulación] Pacientes disponibles: ", _pacientes_disponibles.size())
	
	# Verificar que hay pacientes
	if _pacientes_disponibles.is_empty():
		push_warning("[Simulación] No hay pacientes disponibles!")
		_salir_simulacion()
		return
	
	# Mezclar aleatoriamente
	_pacientes_disponibles.shuffle()
	
	# Mostrar SOLO el primer paciente aleatorio
	_mostrar_siguiente_paciente()

func _hide_all_pacientes() -> void:
	# Ocultar todos los pacientes - ninguno visible
	if paciente_sano:
		_set_branch_enabled(paciente_sano, false)
	if paciente_bruxismo:
		_set_branch_enabled(paciente_bruxismo, false)
	if paciente_caries:
		_set_branch_enabled(paciente_caries, false)
	if paciente_gingivitis:
		_set_branch_enabled(paciente_gingivitis, false)

func _mostrar_siguiente_paciente() -> void:
	# Ocultar paciente actual si existe (el anterior desaparece)
	if _paciente_actual != null:
		_set_branch_enabled(_paciente_actual, false)
		_paciente_actual = null
	
	# Verificar si quedan pacientes
	if _pacientes_disponibles.is_empty():
		print("[Simulación] ¡Todos los pacientes han sido diagnosticados!")
		_finalizar_simulacion()
		return
	
	# Obtener siguiente paciente de la lista
	_paciente_actual = _pacientes_disponibles.pop_front()
	
	# Validar que no sea null
	if _paciente_actual == null:
		push_warning("[Simulación] Paciente obtenido es null, intentando siguiente...")
		_mostrar_siguiente_paciente()
		return
	
	# Mostrar SOLO este paciente
	_set_branch_enabled(_paciente_actual, true)
	print("[Simulación] Mostrando paciente: ", _paciente_actual.name)

func _verificar_diagnostico(diagnostico: String) -> void:
	if not _simulacion_activa:
		return
	
	if _paciente_actual == null:
		push_warning("[Simulación] No hay paciente actual para diagnosticar")
		return
	
	var enfermedad_real := _obtener_enfermedad_paciente(_paciente_actual)
	
	if diagnostico == enfermedad_real:
		print("[Simulación] ¡Diagnóstico CORRECTO! Era: ", enfermedad_real)
		diagnostico_correcto.emit()  # Señal verde
		# Pasar al siguiente paciente (el actual desaparece)
		_mostrar_siguiente_paciente()
	else:
		print("[Simulación] Diagnóstico INCORRECTO.  Seleccionaste: ", diagnostico, " pero era: ", enfermedad_real)
		diagnostico_incorrecto.emit()  # Señal rojo
		# El paciente sigue visible para reintentar

func _obtener_enfermedad_paciente(paciente: Node3D) -> String:
	if paciente == null:
		return ""
	
	var nombre := paciente.name. to_lower()
	if nombre.find("sano") != -1:
		return "sano"
	elif nombre.find("bruxismo") != -1:
		return "bruxismo"
	elif nombre.find("caries") != -1:
		return "caries"
	elif nombre.find("gingivitis") != -1:
		return "gingivitis"
	return ""

func _finalizar_simulacion() -> void:
	print("[Simulación] Simulación completada exitosamente.")
	_salir_simulacion()

func _salir_simulacion() -> void:
	_simulacion_activa = false
	_paciente_actual = null
	_pacientes_disponibles.clear()
	
	# Emitir señal para volver cámara
	simulacion_terminada.emit()
	
	# Ocultar todos los pacientes
	_hide_all_pacientes()
	
	# Ocultar simulación completa
	_set_branch_enabled(simulacion_casos, false)
	
	# Limpiar historial y volver al menú principal
	history.clear()
	_render_state({"type": StateType.PANEL, "node": cuadros_menu})
	_update_back_visibility()

# =================================================================
#                      Dientes (rama + modelos)
# =================================================================
func _init_teeth_refs() -> void:
	if diente_parte == null:
		diente_parte = get_node_or_null("DienteParte1")
		if diente_parte == null:
			diente_parte = find_child("DienteParte1", true, false) as Node3D
	
	if label_3d == null:
		label_3d = get_node_or_null("Label3D")
		if label_3d == null:
			label_3d = find_child("Label3D", true, false) as Label3D
	
	# ✨ NUEVO: Inicializar LabelPreview
	if label_preview == null:
		label_preview = get_node_or_null("LabelPreview") as Label3D
		if label_preview == null:
			label_preview = find_child("LabelPreview", true, false) as Label3D
		if label_preview == null:
			push_warning("[Menu] No se encontró 'LabelPreview'")
	
	# Ocultar preview al inicio
	if label_preview:
		label_preview.visible = false
		label_preview.text = ""
		print("✅ LabelPreview encontrado y configurado")
	
	if diente_parte:
		dientes_anim = diente_parte.get_node_or_null("AnimationPlayer") as AnimationPlayer
	else:
		dientes_anim = null

func _ensure_teeth_exist() -> bool:
	if diente_parte == null:
		push_warning("[Menu] No se encontró 'DienteParte1'.")
		return false
	return true

func _setup_teeth_branch() -> void:
	_tooth_bodies. clear()
	if diente_parte:
		_set_branch_enabled(diente_parte, false)
	if label_3d:
		_hide_label()
	if diente_parte:
		for n in diente_parte.get_children():
			_collect_collision_objects_recursive(n)
	_disable_teeth_layers()
	for body in _tooth_bodies:
		_connect_tooth_selection(body)

func _collect_collision_objects_recursive(n: Node) -> void:
	if n is CollisionObject3D:
		_tooth_bodies.append(n)
	for c in n.get_children():
		_collect_collision_objects_recursive(c)

func _connect_tooth_selection(body: CollisionObject3D) -> void:
	var callable := func():
		_on_tooth_selected(body. name)
	if body.has_signal("button_selected"):
		body.button_selected.connect(func(_n): callable.call())
	elif body.has_signal("input_event"):
		body. input_event.connect(func(_cam, event, _pos, _normal, _shape_idx):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				callable.call()
		)

func _hide_label() -> void:
	if label_3d:
		label_3d.visible = false
		label_3d.text = ""

func _disable_teeth_layers() -> void:
	for b in _tooth_bodies:
		b.set_collision_layer_value(21, false)
		b.set_collision_layer_value(23, false)
		b.set_collision_mask_value(21, false)
		b.set_collision_mask_value(23, false)

func _enable_teeth_layers() -> void:
	for b in _tooth_bodies:
		b.set_collision_layer_value(21, true)
		b.set_collision_layer_value(23, true)
		b.set_collision_mask_value(21, true)
		b.set_collision_mask_value(23, true)

func _show_teeth_sequence() -> void:
	_set_branch_enabled(diente_parte, true)
	if dientes_anim and dientes_anim.has_animation("ArmatureAction_004"):
		dientes_anim.play("ArmatureAction_004")
		await dientes_anim.animation_finished
	else:
		push_warning("[Menu] Falta AnimationPlayer o 'ArmatureAction_004'")
	_enable_teeth_layers()

# ------------------- Texto + FAMILIA (mesh + giro infinito Z) -------------------
func _on_tooth_selected(tooth_name: String) -> void:
	# ✨ Ocultar preview porque ahora se muestra información completa
	hide_tooth_name_preview()
	
	var title := _formal_tooth_title(tooth_name)
	var body := _tooth_text_for(tooth_name)
	var paragraphs := ["Nombre del diente: %s" % title]
	paragraphs.append_array(body)
	if label_3d:
		label_3d.text = "\n\n".join(paragraphs)
		label_3d.visible = true

	var fam := _family_from_tooth_name(tooth_name)
	_show_family_mesh(fam)

func _formal_tooth_title(raw: String) -> String:
	var lower := raw.to_lower()
	var side_digit := lower.substr(lower.length() - 1, 1)
	var lado := "izquierdo" if side_digit == "1" else ("derecho" if side_digit == "2" else "lado")
	var base := lower
	if side_digit == "1" or side_digit == "2":
		base = lower.substr(0, lower.length() - 1)
	base = base.replace("incisivocentralsuperior", "Incisivo central superior")
	base = base. replace("incisivolateralsuperior", "Incisivo lateral superior")
	base = base.replace("caninosuperior", "Canino superior")
	base = base.replace("primerpremolarsuperior", "Primer premolar superior")
	base = base.replace("segundopremolarsuperior", "Segundo premolar superior")
	base = base.replace("primermolarsuperior", "Primer molar superior")
	base = base.replace("segundomolarsuperior", "Segundo molar superior")
	base = base. replace("incisivocentralinferior", "Incisivo central inferior")
	base = base.replace("incisivolateralinferior", "Incisivo lateral inferior")
	base = base.replace("caninoinferior", "Canino inferior")
	base = base.replace("primerpremolarinferior", "Primer premolar inferior")
	base = base. replace("segundopremolarinferior", "Segundo premolar inferior")
	base = base.replace("primermolarinferior", "Primer molar inferior")
	base = base.replace("segundomolarinferior", "Segundo molar inferior")
	if base.length() > 0:
		base = base[0].to_upper() + base. substr(1, base.length() - 1)
	return "%s %s" % [base, lado]

func _tooth_text_for(raw: String) -> PackedStringArray:
	var key := raw
	if raw.ends_with("1"):
		key = raw.substr(0, raw.length() - 1) + "2"
	var M := {
		"Incisivocentralsuperior2": [
			"Diente frontal principal, con borde cortante.",
			"Función: cortar los alimentos.",
			"Participa en la pronunciación y estética."
		],
		"Incisivolateralsuperior2": [
			"Más pequeño que el incisivo central, con borde afilado.",
			"Función: cortar alimentos.",
			"Ayuda a guiar la mordida."
		],
		"Caninosuperior2": [
			"Diente puntiagudo con raíz larga y resistente.",
			"Función principal: desgarrar alimentos.",
			"Contribuye al soporte del arco dental."
		],
		"Primerpremolarsuperior2": [
			"Premolar con dos cúspides bien definidas.",
			"Función: desgarrar y triturar.",
			"Apoya la transición entre caninos y molares."
		],
		"Segundopremolarsuperior2": [
			"Similar al primero, con cúspides más redondeadas.",
			"Función: triturar alimentos.",
			"Estabiliza la oclusión posterior."
		],
		"Primermolarsuperior2": [
			"Diente grande con cuatro cúspides principales.",
			"Función: moler y triturar alimentos.",
			"Clave para el soporte de la mordida."
		],
		"Segundomolarsuperior2": [
			"Ligeramente más pequeño que el primero, con varias cúspides.",
			"Función: moler alimentos.",
			"Colabora en la masticación final."
		],
		"Incisivocentralinferior2": [
			"Diente pequeño y delgado en la línea media.",
			"Función: cortar alimentos.",
			"Contribuye al guiado inicial del cierre mandibular."
		],
		"Incisivolateralinferior2": [
			"Ligeramente más grande que el incisivo central inferior.",
			"Función: cortar alimentos.",
			"Apoya la dirección de la mordida."
		],
		"Caninoinferior2": [
			"Punta aguda con raíz fuerte.",
			"Función: desgarrar alimentos.",
			"Estabiliza los movimientos laterales."
		],
		"Primerpremolarinferior2": [
			"Dos cúspides (una mayor).",
			"Función: desgarrar e iniciar trituración.",
			"Transfiere fuerzas hacia molares."
		],
		"Segundopremolarinferior2": [
			"Cúspides redondeadas.",
			"Función: triturar alimentos.",
			"Aporta superficie masticatoria adicional."
		],
		"Primermolarinferior2": [
			"Superficie amplia con hasta cinco cúspides.",
			"Función: moler y triturar alimentos.",
			"Fundamental en eficiencia masticatoria."
		],
		"Segundomolarinferior2": [
			"Más pequeño que el primer molar inferior.",
			"Función: triturar alimentos.",
			"Completa la arcada posterior."
		],
	}
	if not M.has(key):
		return [
			"Diente seleccionado.",
			"Función: masticación y guía oclusal.",
			"Elemento anatómico del arco dental."
		]
	return M[key]

# ------------------- MODELOS 3D: helpers -------------------
func _init_models_refs() -> void:
	if modelos_root == null:
		modelos_root = get_node_or_null("Dientes/dientes/RigidBody3D") as Node3D
		if modelos_root == null:
			modelos_root = find_child("RigidBody3D", true, false) as Node3D
	if modelos_root:
		mesh_incisivo = modelos_root.get_node_or_null("Incisivo") as MeshInstance3D
		if mesh_incisivo == null:
			mesh_incisivo = modelos_root.find_child("Incisivo", true, false) as MeshInstance3D
		mesh_canino = modelos_root.get_node_or_null("Canino") as MeshInstance3D
		if mesh_canino == null:
			mesh_canino = modelos_root.find_child("Canino", true, false) as MeshInstance3D
		mesh_premolar = modelos_root.get_node_or_null("Premolar") as MeshInstance3D
		if mesh_premolar == null:
			mesh_premolar = modelos_root.find_child("Premolar", true, false) as MeshInstance3D
		mesh_molar = modelos_root.get_node_or_null("Molar") as MeshInstance3D
		if mesh_molar == null:
			mesh_molar = modelos_root.find_child("Molar", true, false) as MeshInstance3D

func _hide_all_family_meshes() -> void:
	if mesh_incisivo: mesh_incisivo.visible = false
	if mesh_canino: mesh_canino.visible = false
	if mesh_premolar: mesh_premolar.visible = false
	if mesh_molar: mesh_molar.visible = false

func _show_family_mesh(kind: String) -> void:
	_hide_all_family_meshes()
	_rotate_target = null
	match kind. to_lower():
		"incisivo":
			if mesh_incisivo:
				mesh_incisivo. visible = true
				_rotate_target = mesh_incisivo
		"canino":
			if mesh_canino:
				mesh_canino.visible = true
				_rotate_target = mesh_canino
		"premolar":
			if mesh_premolar:
				mesh_premolar.visible = true
				_rotate_target = mesh_premolar
		"molar":
			if mesh_molar:
				mesh_molar.visible = true
				_rotate_target = mesh_molar
		_:
			pass

func _family_from_tooth_name(raw: String) -> String:
	var s := raw.to_lower()
	if s.find("canino") != -1: return "canino"
	if s.find("incisivo") != -1: return "incisivo"
	if s.find("premolar") != -1: return "premolar"
	if s.find("molar") != -1: return "molar"
	return ""

# =================================================================
#                      PREVIEW DE NOMBRES
# =================================================================
func show_tooth_name_preview(tooth_name: String) -> void:
	if not label_preview:
		push_warning("[Preview] LabelPreview no disponible")
		return
	
	var title := _formal_tooth_title(tooth_name)
	label_preview.text = title
	label_preview.visible = true
	print("[Preview] Mostrando: ", title)

func hide_tooth_name_preview() -> void:
	if label_preview:
		label_preview.visible = false
		label_preview.text = ""

func _hide_tooth_preview() -> void:
	# Función privada para uso interno
	hide_tooth_name_preview()

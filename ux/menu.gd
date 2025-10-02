# MenuController.gd  (adjuntar al nodo raíz: Menu)
extends Node3D

@onready var cuadros_menu: Node = $CuadrosMenu
@onready var cuadros_enfermedades: Node = $CuadrosEnfermedades
@onready var enfermedades: Node = $Enfermedades

# --- Botones del Menú principal (por ahora usas solo Opcion3) ---
@onready var btn_menu_op3: Node = $"CuadrosMenu/Opcion3"

# --- Botones del submenú de enfermedades ---
@onready var btn_enf_op1: Node = $"CuadrosEnfermedades/Opcion1"
@onready var btn_enf_op2: Node = $"CuadrosEnfermedades/Opcion2"
@onready var btn_enf_op3: Node = $"CuadrosEnfermedades/Opcion3"
@onready var btn_back_from_cuadros: Node = (
	$"CuadrosEnfermedades/Regresar" if has_node("CuadrosEnfermedades/Regresar") else null
)

# --- Botón Regresar dentro de Enfermedades ---
@onready var btn_back_from_enfer: Node = $"Enfermedades/Regresar"

func _ready() -> void:
	# Estado inicial: solo el menú visible/habilitado
	_set_branch_enabled(cuadros_menu, true)
	_set_branch_enabled(cuadros_enfermedades, false)
	_set_branch_enabled(enfermedades, false)
	# Asegura que ninguna opción dentro de Enfermedades esté visible al inicio
	_hide_all_enfermedades()

	# Conexiones de botones (funciona con tu señal `button_selected` o con `input_event`)
	_connect_button(btn_menu_op3, _go_to_cuadros_enfermedades)

	_connect_button(btn_enf_op1, func(): _show_enfermedad(1))
	_connect_button(btn_enf_op2, func(): _show_enfermedad(2))
	_connect_button(btn_enf_op3, func(): _show_enfermedad(3))

	if btn_back_from_cuadros:
		_connect_button(btn_back_from_cuadros, _back_to_menu)

	_connect_button(btn_back_from_enfer, _back_to_cuadros_enfermedades)


# ------------------ Navegación ------------------

func _back_to_menu() -> void:
	# Mostrar solo el menú principal
	_set_branch_enabled(cuadros_menu, true)
	_set_branch_enabled(cuadros_enfermedades, false)
	_set_branch_enabled(enfermedades, false)
	_hide_all_enfermedades()

func _go_to_cuadros_enfermedades() -> void:
	# Ocultar menú / Mostrar submenú de enfermedades
	_set_branch_enabled(cuadros_menu, false)
	_set_branch_enabled(cuadros_enfermedades, true)
	_set_branch_enabled(enfermedades, false)
	_hide_all_enfermedades()

func _show_enfermedad(idx: int) -> void:
	# Entra al nodo Enfermedades mostrando SOLO la opción elegida + el botón Regresar
	_set_branch_enabled(cuadros_menu, false)
	_set_branch_enabled(cuadros_enfermedades, false)

	# Oculta todo dentro de Enfermedades
	for child in enfermedades.get_children():
		_set_branch_enabled(child, false)

	# Activa solo la opción seleccionada
	var sel_path := "Opcion{0}".format([idx])
	if enfermedades.has_node(sel_path):
		_set_branch_enabled(enfermedades.get_node(sel_path), true)

	# Asegura que el botón Regresar dentro de Enfermedades esté activo
	if enfermedades.has_node("Regresar"):
		_set_branch_enabled(enfermedades.get_node("Regresar"), true)

	# Importante: el nodo raíz "Enfermedades" puede quedar como está (no es visible por sí mismo)
	# Solo activamos los hijos necesarios.

func _back_to_cuadros_enfermedades() -> void:
	# Vuelve del detalle de Enfermedades al submenú de Enfermedades
	_set_branch_enabled(cuadros_enfermedades, true)
	_set_branch_enabled(enfermedades, false)
	_hide_all_enfermedades()


# ------------------ Utilitarios de visibilidad/habilitación ------------------

func _hide_all_enfermedades() -> void:
	# Oculta/deshabilita Opcion1, Opcion2, Opcion3 y también Regresar dentro de Enfermedades.
	for child in enfermedades.get_children():
		_set_branch_enabled(child, false)

# Habilita/Deshabilita de forma segura todo un subárbol:
# - VisualInstance3D/Label3D: visible on/off
# - CollisionObject3D: disabled on/off (deferred para evitar warnings durante colisiones)
# - process_mode: detiene procesos/scripts si es necesario
func _set_branch_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return

	# Detener procesos del subárbol cuando está deshabilitado
	node.process_mode = (Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED)

	# Aplicar al propio nodo si es visible o colisionable
	if node is VisualInstance3D or node is Label3D:
		node.visible = enabled
	if node is CollisionObject3D:
		node.set_deferred("disabled", not enabled)

	# Recursivo para hijos
	for c in node.get_children():
		_set_branch_enabled(c, enabled)

# Conecta un botón a un callback. Soporta:
# 1) Tu señal personalizada `button_selected(button_name)` (recomendada)
# 2) Señal nativa `input_event(...)` como fallback
func _connect_button(btn: Node, callback: Callable) -> void:
	if btn == null:
		return
	if btn.has_signal("button_selected"):
		# Tu botón personalizado emite `button_selected(String)` al ser seleccionado
		btn.button_selected.connect(func(_n): callback.call())
	elif btn.has_signal("input_event"):
		# Fallback simple: click/trigger sobre el cuerpo
		btn.input_event.connect(func(_cam, event, _pos, _normal, _shape_idx):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				callback.call()
		)

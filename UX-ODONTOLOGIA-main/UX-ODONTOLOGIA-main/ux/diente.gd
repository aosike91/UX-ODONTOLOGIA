#boton.gd
extends RigidBody3D

signal button_selected(button_name: String)

@onready var boton : AudioStreamPlayer = $AudioStreamPlayer
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var material_original: Material
var material_hover: StandardMaterial3D
var esta_hover: bool = false
var game_controller: Node3D
var menu_controller: Node3D = null  # ✨ NUEVO
var is_enabled: bool = true

@export var color_borde: Color = Color. YELLOW
@export var intensidad_brillo: float = 0.3
@export var button_name: String = ""

func _ready():
	# Configurar nombre del botón
	if button_name == "":
		button_name = name. to_lower()
	
	# Buscar y conectar con el controlador del juego
	setup_game_controller()
	
	# Configurar efectos visuales
	configurar_efectos_hover()
	
	# Configurar estado inicial
	is_enabled = true
	
	print("✅ Botón '", button_name, "' configurado correctamente")

func setup_game_controller():
	game_controller = find_game_controller()
	
	if not game_controller:
		print("⚠️ No se encontró el controlador del juego para botón: ", button_name)
	else:
		print("✅ Controlador del juego vinculado para botón: ", button_name)

func find_game_controller() -> Node3D:
	# Buscar en la jerarquía hacia arriba
	var current_node = get_parent()
	while current_node != null:
		if has_game_controller_methods(current_node):
			return current_node
		# ✨ NUEVO: Buscar también menu_controller
		if has_menu_controller_methods(current_node):
			menu_controller = current_node
		current_node = current_node. get_parent()
	
	# Buscar en los hijos del nodo raíz
	var root_children = get_tree().root.get_children()
	for child in root_children:
		if has_game_controller_methods(child):
			return child
		# ✨ NUEVO
		if has_menu_controller_methods(child):
			menu_controller = child
			
	return null

func has_game_controller_methods(node: Node) -> bool:
	return (node. has_method("is_menu_available") and 
			node.has_method("_on_button_selected"))

# ✨ NUEVO
func has_menu_controller_methods(node: Node) -> bool:
	return (node.has_method("show_tooth_name_preview") and 
			node.has_method("hide_tooth_name_preview"))

func configurar_efectos_hover():
	if not mesh_instance:
		print("⚠️ MeshInstance3D no encontrado en botón: ", button_name)
		return
	
	# Guardar configuración original
	material_original = get_current_material()
	
	# Crear material para hover
	crear_material_hover()

func get_current_material() -> Material:
	var material = mesh_instance.get_surface_override_material(0)
	if not material and mesh_instance.mesh:
		material = mesh_instance. mesh.surface_get_material(0)
	return material

func crear_material_hover():
	material_hover = StandardMaterial3D.new()
	
	# Copiar propiedades del material original si existe
	if material_original and material_original is StandardMaterial3D:
		copy_material_properties(material_original as StandardMaterial3D)
	else:
		set_default_material_properties()
	
	# Aplicar efectos de hover
	apply_hover_effects()

func copy_material_properties(original: StandardMaterial3D):
	material_hover.albedo_color = original.albedo_color
	material_hover.albedo_texture = original.albedo_texture
	material_hover.metallic = original.metallic
	material_hover.roughness = original.roughness
	material_hover.normal_texture = original.normal_texture

func set_default_material_properties():
	material_hover.albedo_color = Color. WHITE
	material_hover.metallic = 0.1
	material_hover.roughness = 0.3

func apply_hover_effects():
	# Efectos de borde y emisión
	material_hover.rim_enabled = true
	material_hover. rim_color = color_borde
	material_hover.rim_tint = 1.0
	
	material_hover.emission_enabled = true
	material_hover.emission_color = color_borde
	material_hover.emission_energy = intensidad_brillo
	
	# Iluminar un poco el color base
	material_hover.albedo_color = material_hover.albedo_color. lightened(0.15)

func is_button_enabled() -> bool:
	if not game_controller:
		return true
	
	if button_name == "regresar":
		if game_controller.has_method("is_return_button_available"):
			return game_controller. is_return_button_available()
		return false
	else:
		if game_controller. has_method("is_menu_available"):
			return game_controller.is_menu_available()
		return true

func update_button_state():
	# Método llamado por el controlador del juego para actualizar el estado
	var was_enabled = is_enabled
	is_enabled = is_button_enabled()
	
	if was_enabled != is_enabled:
		print("🔄 Estado del botón '", button_name, "' cambiado a: ", "habilitado" if is_enabled else "deshabilitado")
		
		if not is_enabled and esta_hover:
			force_disable_hover()

func pointer_event(event: XRToolsPointerEvent) -> void:
	# Verificar si el botón está habilitado
	if not is_button_enabled():
		if esta_hover:
			force_disable_hover()
		return
	
	# Procesar eventos del puntero
	match event.event_type:
		XRToolsPointerEvent.Type.ENTERED:
			handle_pointer_entered()
		XRToolsPointerEvent.Type. EXITED:
			handle_pointer_exited()
		XRToolsPointerEvent.Type. PRESSED:
			handle_pointer_pressed()
		XRToolsPointerEvent.Type.RELEASED:
			handle_pointer_released()

func handle_pointer_entered():
	print("🎯 Puntero entró en botón: ", button_name)
	if is_button_enabled():
		activar_hover()
		
		# ✨ NUEVO: Mostrar preview del nombre del diente
		if menu_controller and menu_controller.has_method("show_tooth_name_preview"):
			menu_controller.show_tooth_name_preview(button_name)

func handle_pointer_exited():
	print("🎯 Puntero salió del botón: ", button_name)
	desactivar_hover()
	
	# ✨ NUEVO: Ocultar preview del nombre del diente
	if menu_controller and menu_controller. has_method("hide_tooth_name_preview"):
		menu_controller.hide_tooth_name_preview()

func handle_pointer_pressed():
	if not is_button_enabled():
		print("🚫 Botón presionado pero deshabilitado: ", button_name)
		return
		
	print("🎯 Botón presionado: ", button_name)
	
	# ✨ NUEVO: Ocultar preview porque se seleccionó el diente
	if menu_controller and menu_controller.has_method("hide_tooth_name_preview"):
		menu_controller.hide_tooth_name_preview()
	
	# Efecto visual de presión
	play_press_effect()
	
	# Emitir señal
	button_selected.emit(button_name)
	print("📡 Señal 'button_selected' emitida para: ", button_name)

func handle_pointer_released():
	print("🎯 Botón liberado: ", button_name)
	
	# Restaurar hover si el puntero sigue sobre el botón
	if esta_hover and is_button_enabled():
		await get_tree().process_frame  # Esperar un frame
		activar_hover()

func activar_hover():
	if not mesh_instance or esta_hover or not is_button_enabled():
		return
	
	print("✨ Activando hover en botón: ", button_name)
	esta_hover = true
	
	# Aplicar material de hover
	mesh_instance.set_surface_override_material(0, material_hover)

func desactivar_hover():
	if not mesh_instance or not esta_hover:
		return
	
	print("✨ Desactivando hover en botón: ", button_name)
	esta_hover = false
	
	# Restaurar material original
	if material_original:
		mesh_instance.set_surface_override_material(0, material_original)
	else:
		mesh_instance.set_surface_override_material(0, null)

func force_disable_hover():
	if not mesh_instance:
		return
	
	print("🔴 Forzando desactivación del hover: ", button_name)
	esta_hover = false
	
	# Restaurar estado original inmediatamente
	if material_original:
		mesh_instance.set_surface_override_material(0, material_original)
	else:
		mesh_instance.set_surface_override_material(0, null)

func play_press_effect():
	if not mesh_instance or not is_button_enabled():
		return
	
	print("🎯 Reproduciendo efecto de presión para: ", button_name)
	
	# Crear material temporal más brillante
	if material_hover:
		var material_temp = material_hover.duplicate() as StandardMaterial3D
		material_temp.emission_energy = intensidad_brillo * 2.0
		material_temp.emission_color = Color. CYAN
		
		# Aplicar material temporal
		mesh_instance.set_surface_override_material(0, material_temp)
		
		# Restaurar después de un tiempo
		await get_tree().create_timer(0.2).timeout
		
		# Solo restaurar si el botón sigue habilitado y en hover
		if esta_hover and is_button_enabled():
			mesh_instance.set_surface_override_material(0, material_hover)

func _process(_delta):
	# Verificar estado en cada frame (para casos edge)
	if esta_hover and not is_button_enabled():
		force_disable_hover()

# Métodos públicos para configuración externa
func configurar_colores_boton(nuevo_color: Color):
	color_borde = nuevo_color
	crear_material_hover()
	
	# Aplicar inmediatamente si está en hover
	if esta_hover and mesh_instance and is_button_enabled():
		mesh_instance.set_surface_override_material(0, material_hover)

func set_button_enabled(enabled: bool):
	is_enabled = enabled
	if not enabled and esta_hover:
		force_disable_hover()

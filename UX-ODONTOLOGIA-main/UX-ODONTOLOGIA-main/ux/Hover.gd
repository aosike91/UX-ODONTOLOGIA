#Hover.gd
extends RigidBody3D

@onready var ojoanimacion: AnimationPlayer = $Cornea/AnimationPlayer
@onready var mesh_instance: MeshInstance3D = $Cornea  # Si el ojo es un MeshInstance3D hijo
# Si el script está en el mismo MeshInstance3D, usar: @onready var mesh_instance: MeshInstance3D = self

# Variables para el efecto hover
var escala_original: Vector3
var material_original: Material
var material_hover: StandardMaterial3D
var tween_escala: Tween
var esta_hover: bool = false

# Configuración del efecto específica para el ojo
@export var factor_escala: float = 1.2
@export var velocidad_transicion: float = 0.3
@export var color_borde: Color = Color.YELLOW
@export var intensidad_brillo: float = 0.3

func _ready():
	# Si el script está directamente en el MeshInstance3D del ojo
	# Iniciar animación del ojo
	if ojoanimacion:
		ojoanimacion.play("ojoarribaojoabajo")
		print("👁️ Animación del ojo iniciada")
	
	# Configurar efectos hover
	configurar_efectos_hover()
	
	print("✅ Ojo configurado con hover effects")

func configurar_efectos_hover():
	if not mesh_instance:
		return
	
	# Guardar valores originales
	escala_original = mesh_instance.scale
	material_original = mesh_instance.get_surface_override_material(0)
	
	# Si no hay material override, usar el material del mesh
	if not material_original and mesh_instance.mesh:
		material_original = mesh_instance.mesh.surface_get_material(0)
	
	# Crear material para hover
	crear_material_hover()

func crear_material_hover():
	material_hover = StandardMaterial3D.new()
	
	# Copiar propiedades del material original si existe
	if material_original and material_original is StandardMaterial3D:
		var mat_orig = material_original as StandardMaterial3D
		material_hover.albedo_color = mat_orig.albedo_color
		material_hover.albedo_texture = mat_orig.albedo_texture
		material_hover.metallic = mat_orig.metallic
		material_hover.roughness = mat_orig.roughness
		material_hover.normal_texture = mat_orig.normal_texture
	else:
		# Valores por defecto para ojos
		material_hover.albedo_color = Color.WHITE
		material_hover.metallic = 0.1
		material_hover.roughness = 0.3
	
	# Configurar el efecto de borde amarillo específico para ojos
	material_hover.rim_enabled = true
	material_hover.rim_color = color_borde
	material_hover.rim_tint = 1.0
	
	# Efecto de emisión para que el ojo "brille"
	material_hover.emission_enabled = true
	material_hover.emission_color = color_borde
	material_hover.emission_energy = intensidad_brillo
	
	# Hacer el ojo ligeramente más brillante cuando está en hover
	material_hover.albedo_color = material_hover.albedo_color.lightened(0.15)

# Función principal que maneja todos los eventos del puntero
func pointer_event(event : XRToolsPointerEvent) -> void:
	match event.event_type:
		XRToolsPointerEvent.Type.ENTERED:
			print("👁️ Puntero entró en el ojo")
			activar_hover()
		
		XRToolsPointerEvent.Type.EXITED:
			print("👁️ Puntero salió del ojo")
			desactivar_hover()
		
		XRToolsPointerEvent.Type.PRESSED:
			print("👁️ Ojo presionado - ¡Acción especial!")
			efecto_presion_ojo()
			
			# Conectar con el script principal hospital.gd
			var main_scene = get_tree().current_scene
			if main_scene and main_scene.has_method("on_ojo_button_pressed"):
				if main_scene.on_ojo_button_pressed():
					print("✅ Menú activado desde el botón del ojo")
				else:
					print("⚠️ El ojo no está disponible para selección en este momento")
			else:
				print("❌ No se pudo encontrar el controlador principal hospital.gd")
			
		XRToolsPointerEvent.Type.RELEASED:
			print("👁️ Botón liberado del ojo")
			if esta_hover:
				activar_hover()

# Activar efecto hover específico para el ojo
func activar_hover():
	if not mesh_instance or esta_hover:
		return
	
	print("✨ Activando hover en el ojo")
	esta_hover = true
	
	# Pausar animación del ojo durante hover
	if ojoanimacion and ojoanimacion.is_playing():
		ojoanimacion.pause()
	
	# Animar escala
	if tween_escala:
		tween_escala.kill()
	tween_escala = create_tween()
	tween_escala.set_parallel(true)
	
	tween_escala.tween_property(mesh_instance, "scale", escala_original * factor_escala, velocidad_transicion)
	
	# Aplicar material de hover
	mesh_instance.set_surface_override_material(0, material_hover)

# Desactivar efecto hover
func desactivar_hover():
	if not mesh_instance or not esta_hover:
		return
	
	print("✨ Desactivando hover en el ojo")
	esta_hover = false
	
	# Reanudar animación del ojo
	if ojoanimacion and not ojoanimacion.is_playing():
		ojoanimacion.play("ojoarribaojoabajo")
	
	# Animar vuelta a escala original
	if tween_escala:
		tween_escala.kill()
	tween_escala = create_tween()
	tween_escala.tween_property(mesh_instance, "scale", escala_original, velocidad_transicion)
	
	# Restaurar material original
	mesh_instance.set_surface_override_material(0, material_original)

# Efecto especial cuando se presiona el ojo
func efecto_presion_ojo():
	if not mesh_instance:
		return
	
	print("👁️ ¡Efecto especial del ojo activado!")
	
	# Efecto de "parpadeo" al presionar
	if tween_escala:
		tween_escala.kill()
	tween_escala = create_tween()
	tween_escala.set_parallel(true)
	
	# Crear efecto de "parpadeo" con escalas
	var escala_cerrado = Vector3(escala_original.x, escala_original.y * 0.1, escala_original.z)
	var escala_hover = escala_original * factor_escala
	
	# Secuencia de parpadeo
	tween_escala.tween_property(mesh_instance, "scale", escala_cerrado, 0.1)
	tween_escala.tween_property(mesh_instance, "scale", escala_hover, 0.15)
	
	# Efecto de brillo intenso al parpadear
	if material_hover:
		var material_temp = material_hover.duplicate()
		material_temp.emission_energy = intensidad_brillo * 2.0
		material_temp.emission_color = Color.CYAN  # Cambiar a cyan para efecto especial
		mesh_instance.set_surface_override_material(0, material_temp)
		
		# Volver al material hover normal
		await get_tree().create_timer(0.3).timeout
		if esta_hover:
			mesh_instance.set_surface_override_material(0, material_hover)

# Función específica para acciones del ojo (ya no es necesaria directamente, pero se mantiene por compatibilidad)
func accion_ojo_presionado():
	print("🎯 Ejecutando acción específica del ojo")
	# Esta función ahora se maneja en pointer_event PRESSED
	# Se mantiene para compatibilidad con código existente

# Función para personalizar colores del ojo
func configurar_colores_ojo(color_iris: Color, color_pupila: Color, color_hover: Color):
	color_borde = color_hover
	crear_material_hover()
	
	if esta_hover and mesh_instance:
		mesh_instance.set_surface_override_material(0, material_hover)

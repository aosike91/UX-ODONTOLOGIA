# XROrigin3D.gd (parte relevante) — crea accum_image/accum_tex y los expone
extends XROrigin3D

@export var heatmap_resolution: Vector2i = Vector2i(1024,1024)
@export var brush_radius: int = 18
@export var brush_strength: float = 0.12

# Exponemos la textura para que Main la pueda leer/usar
var heatmap_texture: ImageTexture = null setget ,_noop_setget

# Internals
var _accum_image: Image = null
var _accum_tex: ImageTexture = null
var _brush_kernel: PoolRealArray = PoolRealArray()
var xr_interface: XRInterface = null

func _noop_setget(v): pass

func _ready():
	print("Starting VR test scene...")
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.initialize():
		print("OpenXR initialized successfully")
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
		print("VR mode enabled")
	else:
		print("OpenXR not initialized")

	# Crear acumulador (Image) y textura (ImageTexture)
	_accum_image = Image.create(heatmap_resolution.x, heatmap_resolution.y, false, Image.FORMAT_R8)
	_accum_image.fill(Color(0,0,0,1))
	_accum_tex = ImageTexture.new()
	_accum_tex.create_from_image(_accum_image, 0)
	heatmap_texture = _accum_tex  # exponemos

	_precompute_brush()
	print("Heatmap (ImageTexture) creado en XROrigin, resolución:", heatmap_resolution)

func _precompute_brush():
	_brush_kernel = PoolRealArray()
	var r = brush_radius
	var sigma = max(1.0, r * 0.45)
	var two_sigma2 = 2.0 * sigma * sigma
	var sum = 0.0
	for y in range(-r, r+1):
		for x in range(-r, r+1):
			var d2 = float(x*x + y*y)
			var v = 0.0
			if d2 <= float(r*r):
				v = exp(-d2 / two_sigma2)
				sum += v
			_brush_kernel.append(v)
	if sum > 0.0:
		for i in range(_brush_kernel.size()):
			_brush_kernel[i] /= sum

# Aplica en la imagen acumuladora alrededor de px,py
func apply_heat_point(px:int, py:int):
	_accum_image.lock()
	var idx = 0
	var r = brush_radius
	for y in range(-r, r+1):
		var iy = py + y
		if iy < 0 or iy >= heatmap_resolution.y:
			idx += (r*2+1)
			continue
		for x in range(-r, r+1):
			var ix = px + x
			if ix < 0 or ix >= heatmap_resolution.x:
				idx += 1
				continue
			var k = _brush_kernel[idx]
			if k > 0.0:
				var old = _accum_image.get_pixel(ix, iy).r
				var nv = clamp(old + k * brush_strength, 0.0, 1.0)
				_accum_image.set_pixel(ix, iy, Color(nv,0,0))
			idx += 1
	_accum_image.unlock()
	_accum_tex.set_data(_accum_image)  # actualiza textura expuesta
	heatmap_texture = _accum_tex

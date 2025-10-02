extends XROrigin3D

var xr_interface: XRInterface

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

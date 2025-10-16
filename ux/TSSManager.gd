# TTSManager.gd (Godot 4.3) — AutoLoad
extends Node
class_name TTSManager

# === Config ===
var OPENAI_API_KEY: String = "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"   # Para pruebas (no recomendado en prod)
var OPENAI_TTS_MODEL: String = "tts-1"                # "tts-1-hd" o "gpt-4o-mini-tts"
var OPENAI_TTS_VOICE: String = "alloy"
var OPENAI_TTS_FORMAT: String = "wav"                 # "wav" | "mp3" | "opus" | "aac"
var OPENAI_TTS_URL: String = "https://api.openai.com/v1/audio/speech"

signal tts_finished(path: String)

func _ready() -> void:
	# Asegura ambas carpetas (editor y runtime)
	_ensure_dir("res://audios")
	_ensure_dir("user://audios")

func _ensure_dir(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		DirAccess.make_dir_recursive_absolute(path)

# Decide dónde GUARDAR el archivo nuevo
# - En editor: res://audios/<basename>.<fmt>
# - Exportado: user://audios/<basename>.<fmt>
func _target_save_path(basename: String, fmt: String) -> String:
	if Engine.is_editor_hint():
		return "res://audios/%s.%s" % [basename, fmt]
	else:
		return "user://audios/%s.%s" % [basename, fmt]

# Intenta emitir el cache si ya existe (res:// primero, luego user://)
func _emit_if_cached(basename: String, fmt: String) -> bool:
	var paths := PackedStringArray([
		"res://audios/%s.%s" % [basename, fmt],
		"user://audios/%s.%s" % [basename, fmt]
	])
	for p in paths:
		if FileAccess.file_exists(p):
			print("[TTS] Cache encontrado:", p)
			emit_signal("tts_finished", p)
			return true
	return false

# ---------- TTS principal (no reproduce, solo emite ruta) ----------
func speak_text(text: String, basename: String = "tts_output", opts: Dictionary = {}) -> void:
	# 1) Cache: si ya existe en res:// o user://, emitir y salir
	var fmt: String = OPENAI_TTS_FORMAT
	if opts.has("format") and typeof(opts["format"]) == TYPE_STRING:
		fmt = String(opts["format"])
	if _emit_if_cached(basename, fmt):
		return

	# 2) API key
	if OPENAI_API_KEY == "" or OPENAI_API_KEY == null:
		push_warning("[TTS] Falta OPENAI_API_KEY.")
		return

	# 3) Opciones
	var model: String = OPENAI_TTS_MODEL
	if opts.has("model") and typeof(opts["model"]) == TYPE_STRING:
		model = String(opts["model"])

	var voice: String = OPENAI_TTS_VOICE
	if opts.has("voice") and typeof(opts["voice"]) == TYPE_STRING:
		voice = String(opts["voice"])

	var out_path: String = _target_save_path(basename, fmt)
	_ensure_dir(out_path.get_base_dir())
	print("[TTS] Guardaré en:", out_path)

	# 4) Payload correcto (usa "format")
	var payload := {
		"model": model,
		"voice": voice,
		"input": text,
		"format": fmt
	}

	# 5) HTTPRequest
	var req: HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_tts_request_completed.bind(req, out_path))

	var headers: PackedStringArray = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + OPENAI_API_KEY
	])

	var err: int = req.request(
		OPENAI_TTS_URL,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		push_warning("[TTS] HTTP request error: %s" % str(err))

# ---------- Handler HTTP ----------
func _on_tts_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest, out_path: String) -> void:
	if is_instance_valid(req):
		req.queue_free()

	# Errores HTTP (429 = cuota)
	if response_code < 200 or response_code >= 300:
		var err_text: String = ""
		if body.size() > 0:
			err_text = body.get_string_from_utf8()
		push_warning("[TTS] Error HTTP %s: %s" % [str(response_code), err_text])
		return

	# Verifica Content-Type: audio/*
	var is_audio: bool = false
	for h in headers:
		var hl := h.to_lower()
		if hl.begins_with("content-type:") and hl.find("audio/") != -1:
			is_audio = true
			break
	if not is_audio:
		var txt := body.get_string_from_utf8()
		push_warning("[TTS] Respuesta no-audio. Cuerpo: %s" % txt)
		return

	# Guardar a disco
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_warning("[TTS] No se pudo abrir archivo: " + out_path)
		return
	f.store_buffer(body)
	f.close()

	print("[TTS] Archivo creado:", out_path)
	emit_signal("tts_finished", out_path)

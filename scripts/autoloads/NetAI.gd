# NetAI.gd
# Networking + AI bridge used by mods and game systems.
#
# Design notes
# ─────────────
# The interpreter calls these helpers from inside `Callable` lambdas
# that are *not* coroutines, so we cannot `await` here. All helpers
# are therefore **callback-based** and return immediately. The
# callback (if provided) is invoked with the response on the main
# thread.
#
# Configuration is read from environment variables — NO keys are
# ever stored in the repo. Profiles live in `user://ai_profiles.cfg`.
#
# Environment variables (read on demand, never logged):
#   OPENROUTER_API_KEY     — used by ai_chat()
#   OPENROUTER_MODEL       — default model id (optional)
#   TELEGRAM_BOT_TOKEN     — used by tg_send_message() (optional)
#   TELEGRAM_CHAT_ID       — default chat id for tg_send_message
extends Node

const PROFILES_PATH := "user://ai_profiles.cfg"
const DEFAULT_MODEL := "qwen/qwen3-coder:free"
const ENDPOINT := "https://openrouter.ai/api/v1/chat/completions"

var _profiles: Dictionary = {}


func _ready() -> void:
	_load_profiles()


# ── Profiles persistence ─────────────────────────────────────────────────
func _load_profiles() -> void:
	if not FileAccess.file_exists(PROFILES_PATH):
		return
	var f := FileAccess.open(PROFILES_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_profiles = parsed


func save_profile(name: String, model: String, api_key: String) -> void:
	# Stored only on the user's machine, in user://. Never echoed back.
	_profiles[name] = {"model": model, "api_key": api_key}
	var f := FileAccess.open(PROFILES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_profiles, "  "))
		f.close()


func get_model(profile: String = "default") -> String:
	if _profiles.has(profile):
		var p = _profiles[profile]
		if typeof(p) == TYPE_DICTIONARY and p.get("model", "") != "":
			return p["model"]
	var env := OS.get_environment("OPENROUTER_MODEL")
	return env if env != "" else DEFAULT_MODEL


func _get_key(profile: String) -> String:
	if _profiles.has(profile):
		var p = _profiles[profile]
		if typeof(p) == TYPE_DICTIONARY and p.get("api_key", "") != "":
			return p["api_key"]
	return OS.get_environment("OPENROUTER_API_KEY")


# ── HTTP helpers (callback-based, no `await` so they're safe to call
# from arbitrary Callable lambdas). ──────────────────────────────────────
func http_get(url: String, headers: PackedStringArray = PackedStringArray(),
		on_done: Callable = Callable()) -> Dictionary:
	return _do_request(url, HTTPClient.METHOD_GET, "", headers, on_done)


func http_post(url: String, body: String,
		headers: PackedStringArray = PackedStringArray(),
		on_done: Callable = Callable()) -> Dictionary:
	return _do_request(url, HTTPClient.METHOD_POST, body, headers, on_done)


func http_post_json(url: String, data: Variant,
		extra_headers: PackedStringArray = PackedStringArray(),
		on_done: Callable = Callable()) -> Dictionary:
	var body := JSON.stringify(data)
	var hdr := PackedStringArray(["Content-Type: application/json"])
	for h in extra_headers:
		hdr.append(h)
	return _do_request(url, HTTPClient.METHOD_POST, body, hdr, on_done)


func _do_request(url: String, method: int, body: String,
		headers: PackedStringArray, on_done: Callable) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	if not on_done.is_null():
		req.request_completed.connect(
			func(result, status, _h, b):
				var d: Dictionary = _http_to_dict([result, status, _h, b])
				on_done.call(d)
				req.queue_free(),
			CONNECT_ONE_SHOT
		)
	else:
		req.request_completed.connect(
			func(_a, _b, _c, _d): req.queue_free(),
			CONNECT_ONE_SHOT
		)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "request_failed:%d" % err}
	return {"ok": true, "pending": true}


func _http_to_dict(result: Array) -> Dictionary:
	var code: int = result[0] if result.size() > 0 else -1
	var status: int = result[1] if result.size() > 1 else 0
	var body: PackedByteArray = result[3] if result.size() > 3 \
		else PackedByteArray()
	var text := body.get_string_from_utf8()
	var parsed: Variant = null
	if text != "":
		parsed = JSON.parse_string(text)
	return {
		"ok": code == HTTPRequest.RESULT_SUCCESS and status >= 200 \
			and status < 300,
		"status": status,
		"body": text,
		"json": parsed,
	}


# ── OpenRouter chat completion ───────────────────────────────────────────
func ai_chat(prompt: String, profile: String = "default",
		on_done: Callable = Callable(), system: String = "") -> Dictionary:
	var key := _get_key(profile)
	if key == "":
		ChatOverlay.error("OPENROUTER_API_KEY не задан — задай через " +
			"переменную окружения или save_profile().", "NetAI")
		if not on_done.is_null():
			on_done.call("")
		return {"ok": false, "error": "no_key"}
	var model := get_model(profile)
	var msgs: Array = []
	if system != "":
		msgs.append({"role": "system", "content": system})
	msgs.append({"role": "user", "content": prompt})
	var hdr := PackedStringArray([
		"Authorization: Bearer %s" % key,
		"Content-Type: application/json",
	])
	var data := {"model": model, "messages": msgs}
	# Wrap so the user callback receives just the assistant text.
	var inner := func(resp: Dictionary):
		var text := ""
		var j = resp.get("json", null)
		if typeof(j) == TYPE_DICTIONARY:
			var choices = j.get("choices", [])
			if typeof(choices) == TYPE_ARRAY and not choices.is_empty():
				var msg = choices[0].get("message", {})
				text = String(msg.get("content", ""))
		ChatOverlay.ai(text if text != "" else "(нет ответа)", "AI")
		if not on_done.is_null():
			on_done.call(text)
	return http_post_json(ENDPOINT, data, hdr, inner)


# ── Telegram (optional) ──────────────────────────────────────────────────
func tg_send_message(text: String, chat_id: String = "",
		on_done: Callable = Callable()) -> Dictionary:
	var token := OS.get_environment("TELEGRAM_BOT_TOKEN")
	if token == "":
		return {"ok": false, "error": "no_token"}
	if chat_id == "":
		chat_id = OS.get_environment("TELEGRAM_CHAT_ID")
	if chat_id == "":
		return {"ok": false, "error": "no_chat_id"}
	var url := "https://api.telegram.org/bot%s/sendMessage" % token
	return http_post_json(url, {
		"chat_id": chat_id, "text": text,
	}, PackedStringArray(), on_done)

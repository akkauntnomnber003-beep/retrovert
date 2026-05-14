# NetAPI.gd
# Thin async HTTP layer used by mods (and the AI chat helper). All requests
# go through HTTPRequest nodes so they never block the main thread.
#
# Mods access this via ModAPI.net (same shape as ModAPI.chat / ModAPI.files).
# Results are delivered through the bus signal "net_response" (request_id,
# code, body) so RatScript can call:
#
#   let id = http_get("https://example.com/")
#   on("net_response") func(rid, code, body)
#       if rid == id then chat_log("got " .. code) end
#   end
#
extends Node

signal net_response(request_id: int, code: int, body: String)

var _next_id: int = 1
var _pending: Dictionary = {}


func _new_request() -> HTTPRequest:
	var req := HTTPRequest.new()
	req.use_threads = true
	req.timeout = 30.0
	add_child(req)
	return req


func _finish(req: HTTPRequest, request_id: int, callback: Callable) -> void:
	# Cleanup once HTTPRequest emits request_completed.
	req.request_completed.connect(
		func(_result: int, code: int, _hdrs: PackedStringArray, body: PackedByteArray):
			var text := body.get_string_from_utf8()
			_pending.erase(request_id)
			emit_signal("net_response", request_id, code, text)
			EventBus.emit_signal("net_response", request_id, code, text)
			if callback.is_valid():
				callback.call(request_id, code, text)
			req.queue_free()
	)


func get_async(url: String, headers: PackedStringArray = PackedStringArray(),
		callback: Callable = Callable()) -> int:
	var rid := _next_id
	_next_id += 1
	var req := _new_request()
	_pending[rid] = req
	_finish(req, rid, callback)
	var err := req.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_warning("NetAPI.get_async failed: %s" % err)
		_pending.erase(rid)
		req.queue_free()
		emit_signal("net_response", rid, 0, "request error: " + str(err))
	return rid


func post_async(url: String, body: String,
		headers: PackedStringArray = PackedStringArray(),
		callback: Callable = Callable()) -> int:
	var rid := _next_id
	_next_id += 1
	var req := _new_request()
	_pending[rid] = req
	_finish(req, rid, callback)
	var err := req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("NetAPI.post_async failed: %s" % err)
		_pending.erase(rid)
		req.queue_free()
		emit_signal("net_response", rid, 0, "request error: " + str(err))
	return rid


func cancel(rid: int) -> void:
	if not _pending.has(rid):
		return
	var req: HTTPRequest = _pending[rid]
	if is_instance_valid(req):
		req.cancel_request()
		req.queue_free()
	_pending.erase(rid)


# ──────────────────────────────────────────────────────────────────────────
# OpenRouter / OpenAI-style chat-completions helper.
# Returns request_id; result arrives via net_response (body = JSON, parse
# yourself or use ai_chat_text() which gives clean string).
# ──────────────────────────────────────────────────────────────────────────
func ai_chat(prompt: String, model: String = "",
		callback: Callable = Callable()) -> int:
	var api_key: String = ApiKeys.get_key("openrouter", "default")
	if api_key == "":
		var rid := _next_id
		_next_id += 1
		var msg: String = "[NetAPI] OpenRouter key is not set. Open Settings → API keys."
		emit_signal("net_response", rid, 401, msg)
		ChatLog.send_error(msg, "NetAPI")
		return rid
	var m: String = model
	if m == "":
		m = ApiKeys.get_key("openrouter", "model")
	if m == "":
		m = "google/gemma-3-12b-it:free"
	var headers := PackedStringArray([
		"Authorization: Bearer " + api_key,
		"Content-Type: application/json",
		"HTTP-Referer: https://github.com/akkauntnomnber003-beep/retrovert",
		"X-Title: RatRovert",
	])
	var body := JSON.stringify({
		"model": m,
		"messages": [
			{"role": "user", "content": prompt}
		]
	})
	return post_async("https://openrouter.ai/api/v1/chat/completions",
		body, headers, callback)


# Same as ai_chat but pre-parses the OpenAI-style response so the callback
# (and chat_message) receives only the text content. Useful when you want
# to drop the LLM reply directly into the in-game chat.
func ai_chat_text(prompt: String, model: String = "",
		callback: Callable = Callable()) -> int:
	return ai_chat(prompt, model, func(rid: int, code: int, body: String):
		var text: String = body
		if code == 200:
			var parsed = JSON.parse_string(body)
			if parsed is Dictionary and parsed.has("choices"):
				var choices: Array = parsed["choices"]
				if choices.size() > 0 and choices[0] is Dictionary:
					var msg = choices[0].get("message", {})
					if msg is Dictionary:
						text = String(msg.get("content", body))
		else:
			text = "[NetAPI %d] %s" % [code, body]
		if callback.is_valid():
			callback.call(rid, code, text)
		else:
			ChatLog.send("ИИ", text, "info", "ai"))

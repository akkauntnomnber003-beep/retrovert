# RatScript — a small, embeddable scripting language for RatRovert mods.
#
# Syntax highlights (Lua + Godot flavoured):
#
#   -- comments
#   let x = 10
#   var y = vec(0, 0)                    -- mutable
#
#   func add(a, b)
#       return a + b
#   end
#
#   if x > 5 then
#       log("big")
#   elseif x == 5 then
#       log("five")
#   else
#       log("small")
#   end
#
#   while x > 0 do
#       x = x - 1
#   end
#
#   for i in range(0, 10) do
#       log(i)
#   end
#
#   on("enemy_died") func(pos, type)
#       state.add_coins(1)
#   end
#
#   item({
#       id = "my_item",
#       name = "Tiny Tear",
#       active = false,
#       stats = { player_damage = 1.0 }
#   })
#
#   spawn("res://scenes/enemies/Fly.tscn", vec(640, 360))
#
# This is a tree-walking interpreter — slow but easy to embed and modify.
# The whole thing lives in this file so mod authors can read it.
extends RefCounted

const TOK_NUM := "NUM"
const TOK_STR := "STR"
const TOK_ID := "ID"
const TOK_OP := "OP"
const TOK_KW := "KW"
const TOK_EOF := "EOF"

const KEYWORDS := [
	"let", "var", "func", "end", "if", "then", "elseif", "else",
	"while", "do", "for", "in", "return", "true", "false", "nil",
	"and", "or", "not", "break", "continue",
]

var last_error: String = ""
var mod_info  # ModLoader.ModInfo
var _globals: Dictionary = {}
var _bus_conns: Array = []


# ──────────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────────
func set_mod_context(info) -> void:
	mod_info = info
	_globals = _build_globals()


func run(source: String, file_label: String = "<mod>") -> bool:
	last_error = ""
	var tokens: Array
	var ok_lex := true
	var ast: Array = []
	tokens = _lex(source)
	if last_error != "":
		return false
	ast = _parse(tokens)
	if last_error != "":
		return false
	# Execute top-level statements.
	for node in ast:
		var r = _eval(node, _globals)
		if last_error != "":
			push_warning("[RatScript %s] %s" % [file_label, last_error])
			return false
	return true


func shutdown() -> void:
	# Disconnect any signals the mod subscribed to.
	for c in _bus_conns:
		if EventBus.is_connected(c[0], c[1]):
			EventBus.disconnect(c[0], c[1])
	_bus_conns.clear()


# ──────────────────────────────────────────────────────────────────────────
# Globals available to mod scripts
# ──────────────────────────────────────────────────────────────────────────
func _build_globals() -> Dictionary:
	var g: Dictionary = {}

	g["log"] = func(args: Array):
		var parts: Array = []
		for a in args:
			parts.append(str(a))
		var prefix: String = "[mod:%s] " % (mod_info.id if mod_info else "?")
		print(prefix + " ".join(parts))
		return null

	g["print"] = g["log"]

	g["vec"] = func(args: Array) -> Vector2:
		var x: float = float(args[0]) if args.size() > 0 else 0.0
		var y: float = float(args[1]) if args.size() > 1 else 0.0
		return Vector2(x, y)

	g["range"] = func(args: Array) -> Array:
		var a: int = int(args[0]) if args.size() > 0 else 0
		var b: int = int(args[1]) if args.size() > 1 else a
		if args.size() < 2:
			a = 0
			b = int(args[0]) if args.size() > 0 else 0
		var out: Array = []
		for i in range(a, b):
			out.append(i)
		return out

	g["len"] = func(args: Array) -> int:
		if args.is_empty():
			return 0
		var v = args[0]
		if v is Array or v is Dictionary or v is String:
			return v.size() if not (v is String) else v.length()
		return 0

	g["clamp"] = func(args: Array) -> float:
		return clampf(float(args[0]), float(args[1]), float(args[2]))

	g["rand"] = func(_args: Array) -> float:
		return randf()

	g["randi"] = func(args: Array) -> int:
		if args.size() >= 2:
			return randi_range(int(args[0]), int(args[1]))
		return randi()

	g["deg2rad"] = func(args: Array) -> float:
		return deg_to_rad(float(args[0]))

	g["sin"] = func(args: Array) -> float: return sin(float(args[0]))
	g["cos"] = func(args: Array) -> float: return cos(float(args[0]))
	g["tan"] = func(args: Array) -> float: return tan(float(args[0]))
	g["sqrt"] = func(args: Array) -> float: return sqrt(float(args[0]))
	g["abs"] = func(args: Array) -> float: return abs(float(args[0]))

	# Event-bus subscription. on("enemy_died", func(pos, type) ... end)
	g["on"] = func(args: Array):
		if args.size() < 2:
			return null
		var sig: String = String(args[0])
		var fn = args[1]  # CallableUserFunc captured in the closure below.
		if not EventBus.has_signal(sig):
			push_warning("RatScript: unknown signal '%s'" % sig)
			return null
		# Lambda captures `fn` directly — using .bind() would append the
		# user fn *after* the signal args, which silently breaks every
		# subscription whose signal carries fewer than 4 args.
		var captured = fn
		var self_ref = self
		var bridge = func(a1 = null, a2 = null, a3 = null, a4 = null):
			var passed: Array = []
			for v in [a1, a2, a3, a4]:
				if v != null:
					passed.append(v)
			self_ref._invoke(captured, passed)
		EventBus.connect(sig, bridge)
		_bus_conns.append([sig, bridge])
		return null

	g["emit"] = func(args: Array):
		if args.size() < 1: return null
		var sig: String = String(args[0])
		if not EventBus.has_signal(sig):
			return null
		var rest: Array = args.slice(1)
		EventBus.callv("emit_signal", [sig] + rest)
		return null

	g["state"] = {
		"get": func(args: Array): return GameState.get(String(args[0])),
		"set": func(args: Array):
			GameState.set(String(args[0]), args[1])
			GameState.stats_recomputed.emit()
			return null,
		"add": func(args: Array):
			var key := String(args[0])
			GameState.set(key, GameState.get(key) + args[1])
			GameState.stats_recomputed.emit()
			return null,
		"add_coins": func(args: Array):
			GameState.add_coins(int(args[0])); return null,
		"add_bombs": func(args: Array):
			GameState.add_bombs(int(args[0])); return null,
		"add_keys": func(args: Array):
			GameState.add_keys(int(args[0])); return null,
		"heal": func(args: Array):
			GameState.heal_red(float(args[0])); return null,
		"heal_soul": func(args: Array):
			GameState.heal_soul(float(args[0])); return null,
		"damage": func(args: Array):
			GameState.take_damage(float(args[0])); return null,
	}

	g["item"] = func(args: Array):
		if args.is_empty(): return false
		var d: Dictionary = args[0]
		var mod_uuid: String = mod_info.uuid if mod_info else ""
		return ModAPI.items.register_from_dict(d, mod_uuid)

	g["grant"] = func(args: Array):
		ModAPI.items.grant(String(args[0])); return null

	g["spawn"] = func(args: Array):
		if args.size() < 2: return null
		return ModAPI.entities.spawn_enemy(
			String(args[0]),
			args[1] if args[1] is Vector2 else Vector2.ZERO,
		)

	g["damage_in_radius"] = func(args: Array):
		return ModAPI.entities.damage_enemies_in_radius(
			args[0], float(args[1]), float(args[2]))

	g["shake"] = func(args: Array):
		var s: float = float(args[0]) if args.size() > 0 else 4.0
		var d: float = float(args[1]) if args.size() > 1 else 0.3
		ModAPI.camera_shake(s, d); return null

	g["sfx"] = func(args: Array):
		ModAPI.play_sfx(String(args[0])); return null

	g["player"] = func(_args: Array): return ModAPI.player()
	g["enemies"] = func(_args: Array): return ModAPI.enemies()

	# ── Chat API ──────────────────────────────────────────────────────────
	var mod_name: String = mod_info.name if mod_info else "Мод"
	var mod_uuid: String = mod_info.uuid if mod_info else ""

	g["chat_send"] = func(args: Array):
		if args.size() < 2: return null
		var sender: String = String(args[0])
		var text: String = String(args[1])
		var kind: String = String(args[2]) if args.size() > 2 else "mod"
		var sid: String = String(args[3]) if args.size() > 3 else mod_uuid
		ChatLog.send(sender, text, kind, sid)
		return null

	g["chat_log"] = func(args: Array):
		if args.is_empty(): return null
		ChatLog.send(mod_name, String(args[0]), "mod", mod_uuid)
		return null

	g["chat_error"] = func(args: Array):
		if args.is_empty(): return null
		ChatLog.send(mod_name, String(args[0]), "error", mod_uuid)
		return null

	g["chat_enemy"] = func(args: Array):
		if args.size() < 2: return null
		ChatLog.send(String(args[0]), String(args[1]), "enemy",
			String(args[2]) if args.size() > 2 else "")
		return null

	g["chat_item"] = func(args: Array):
		if args.size() < 2: return null
		ChatLog.send(String(args[0]), String(args[1]), "item",
			String(args[2]) if args.size() > 2 else "")
		return null

	g["chat_clear"] = func(_args: Array): ChatLog.clear(); return null
	g["chat_show"] = func(_args: Array): ChatLog.set_visible(true); return null
	g["chat_hide"] = func(_args: Array): ChatLog.set_visible(false); return null

	# ── Files API ─────────────────────────────────────────────────────────
	g["file_read"] = func(args: Array) -> String:
		if args.is_empty(): return ""
		var rel: String = String(args[0])
		var dv: String = String(args[1]) if args.size() > 1 else ""
		return ModAPI.files.read(mod_uuid, rel, dv)

	g["file_write"] = func(args: Array) -> bool:
		if args.size() < 2: return false
		return ModAPI.files.write(mod_uuid, String(args[0]), String(args[1]))

	g["file_list"] = func(args: Array) -> Array:
		var rel: String = String(args[0]) if args.size() > 0 else ""
		return ModAPI.files.list(mod_uuid, rel)

	g["file_exists"] = func(args: Array) -> bool:
		if args.is_empty(): return false
		return ModAPI.files.exists(mod_uuid, String(args[0]))

	g["file_remove"] = func(args: Array) -> bool:
		if args.is_empty(): return false
		return ModAPI.files.remove(mod_uuid, String(args[0]))

	# ── More math / helpers ───────────────────────────────────────────────
	g["floor"] = func(args: Array) -> int: return int(floor(float(args[0])))
	g["ceil"] = func(args: Array) -> int: return int(ceil(float(args[0])))
	g["round"] = func(args: Array) -> int: return int(round(float(args[0])))
	g["min"] = func(args: Array): return min(args[0], args[1])
	g["max"] = func(args: Array): return max(args[0], args[1])
	g["dist"] = func(args: Array) -> float:
		if args.size() < 2: return 0.0
		var a = args[0]
		var b = args[1]
		if a is Vector2 and b is Vector2:
			return a.distance_to(b)
		return 0.0
	g["now"] = func(_args: Array) -> float:
		return Time.get_ticks_msec() / 1000.0
	g["keys"] = func(args: Array) -> Array:
		if args.is_empty(): return []
		var v = args[0]
		if v is Dictionary:
			return v.keys()
		return []

	g["mod_id"] = func(_args: Array) -> String: return mod_uuid
	g["mod_name"] = func(_args: Array) -> String: return mod_name

	# ── Networking / AI API ───────────────────────────────────────────────
	g["http_get"] = func(args: Array) -> int:
		if args.is_empty(): return 0
		var url: String = String(args[0])
		var hdrs: PackedStringArray = PackedStringArray()
		if args.size() > 1 and args[1] is Array:
			for h in args[1]:
				hdrs.append(String(h))
		return NetAPI.get_async(url, hdrs)

	g["http_post"] = func(args: Array) -> int:
		if args.size() < 2: return 0
		var url: String = String(args[0])
		var body: String = String(args[1])
		var hdrs: PackedStringArray = PackedStringArray()
		if args.size() > 2 and args[2] is Array:
			for h in args[2]:
				hdrs.append(String(h))
		return NetAPI.post_async(url, body, hdrs)

	g["http_cancel"] = func(args: Array):
		if args.is_empty(): return null
		NetAPI.cancel(int(args[0])); return null

	g["ai_chat"] = func(args: Array) -> int:
		if args.is_empty(): return 0
		var prompt: String = String(args[0])
		var model: String = String(args[1]) if args.size() > 1 else ""
		return NetAPI.ai_chat_text(prompt, model)

	g["ai_chat_as"] = func(args: Array) -> int:
		if args.size() < 3: return 0
		var prompt: String = String(args[0])
		var sender: String = String(args[1])
		var sid: String = String(args[2])
		var model: String = String(args[3]) if args.size() > 3 else ""
		return NetAPI.ai_chat_text(prompt, model,
			func(_rid: int, _code: int, text: String):
				ChatLog.send(sender, text, "info", sid))

	# ── API keys (read-only access from RatScript) ────────────────────────
	g["api_key"] = func(args: Array) -> String:
		if args.is_empty(): return ""
		var service: String = String(args[0])
		var name: String = String(args[1]) if args.size() > 1 else "default"
		return ApiKeys.get_key(service, name)

	g["api_has_key"] = func(args: Array) -> bool:
		if args.is_empty(): return false
		var service: String = String(args[0])
		var name: String = String(args[1]) if args.size() > 1 else "default"
		return ApiKeys.has(service, name)

	# ── String helpers ────────────────────────────────────────────────────
	g["len"] = func(args: Array) -> int:
		if args.is_empty(): return 0
		var v = args[0]
		if v is String: return v.length()
		if v is Array: return v.size()
		if v is Dictionary: return v.size()
		return 0
	g["str"] = func(args: Array) -> String:
		if args.is_empty(): return ""
		return String(args[0])
	g["lower"] = func(args: Array) -> String:
		return String(args[0]).to_lower() if not args.is_empty() else ""
	g["upper"] = func(args: Array) -> String:
		return String(args[0]).to_upper() if not args.is_empty() else ""
	g["contains"] = func(args: Array) -> bool:
		if args.size() < 2: return false
		return String(args[0]).find(String(args[1])) != -1
	g["replace"] = func(args: Array) -> String:
		if args.size() < 3: return ""
		return String(args[0]).replace(String(args[1]), String(args[2]))

	# ── JSON ──────────────────────────────────────────────────────────────
	g["json_parse"] = func(args: Array):
		if args.is_empty(): return null
		return JSON.parse_string(String(args[0]))
	g["json_stringify"] = func(args: Array) -> String:
		if args.is_empty(): return ""
		return JSON.stringify(args[0])

	return g


# ──────────────────────────────────────────────────────────────────────────
# Lexer
# ──────────────────────────────────────────────────────────────────────────
func _lex(src: String) -> Array:
	var tokens: Array = []
	var i: int = 0
	var line: int = 1
	while i < src.length():
		var c: String = src[i]
		# whitespace
		if c == "\n":
			line += 1
			i += 1
			continue
		if c == " " or c == "\t" or c == "\r":
			i += 1
			continue
		# comments: -- to end of line
		if c == "-" and i + 1 < src.length() and src[i + 1] == "-":
			while i < src.length() and src[i] != "\n":
				i += 1
			continue
		# numbers
		if c >= "0" and c <= "9":
			var start: int = i
			while i < src.length() and (
				(src[i] >= "0" and src[i] <= "9") or src[i] == "."
			):
				i += 1
			tokens.append([TOK_NUM, float(src.substr(start, i - start)), line])
			continue
		# strings  "..."
		if c == "\"":
			i += 1
			var buf := ""
			while i < src.length() and src[i] != "\"":
				if src[i] == "\\" and i + 1 < src.length():
					var esc: String = src[i + 1]
					match esc:
						"n": buf += "\n"
						"t": buf += "\t"
						"\"": buf += "\""
						"\\": buf += "\\"
						_: buf += esc
					i += 2
				else:
					buf += src[i]
					i += 1
			i += 1  # closing quote
			tokens.append([TOK_STR, buf, line])
			continue
		# identifiers / keywords
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_":
			var start: int = i
			while i < src.length() and (
				(src[i] >= "a" and src[i] <= "z") or
				(src[i] >= "A" and src[i] <= "Z") or
				(src[i] >= "0" and src[i] <= "9") or
				src[i] == "_"
			):
				i += 1
			var ident: String = src.substr(start, i - start)
			if KEYWORDS.has(ident):
				tokens.append([TOK_KW, ident, line])
			else:
				tokens.append([TOK_ID, ident, line])
			continue
		# multi-char operators
		var two: String = ""
		if i + 1 < src.length():
			two = src.substr(i, 2)
		if two in ["==", "!=", "<=", ">=", "&&", "||", ".."]:
			tokens.append([TOK_OP, two, line])
			i += 2
			continue
		# single-char operators
		if c in "+-*/%(){}[],.;:<>=!":
			tokens.append([TOK_OP, c, line])
			i += 1
			continue
		last_error = "Lex error at line %d near '%s'" % [line, c]
		return []
	tokens.append([TOK_EOF, "", line])
	return tokens


# ──────────────────────────────────────────────────────────────────────────
# Parser — recursive-descent producing a tree of plain Dictionaries.
# ──────────────────────────────────────────────────────────────────────────
var _toks: Array
var _ti: int

func _parse(tokens: Array) -> Array:
	_toks = tokens
	_ti = 0
	var stmts: Array = []
	while not _is_eof():
		var s = _parse_stmt()
		if last_error != "":
			return []
		if s != null:
			stmts.append(s)
	return stmts


func _peek(off: int = 0) -> Array:
	if _ti + off < _toks.size():
		return _toks[_ti + off]
	return [TOK_EOF, "", -1]


func _is_eof() -> bool:
	return _peek()[0] == TOK_EOF


func _consume(typ, val = null) -> Array:
	var t = _peek()
	if t[0] != typ or (val != null and t[1] != val):
		last_error = "Parse error at line %d: expected %s '%s', got %s '%s'" % \
			[t[2], typ, str(val), t[0], str(t[1])]
		return [TOK_EOF, "", -1]
	_ti += 1
	return t


func _match_kw(words) -> bool:
	var t = _peek()
	if t[0] != TOK_KW: return false
	if words is String: return t[1] == words
	return t[1] in words


func _match_op(ops) -> bool:
	var t = _peek()
	if t[0] != TOK_OP: return false
	if ops is String: return t[1] == ops
	return t[1] in ops


func _parse_stmt():
	if _match_kw("let") or _match_kw("var"):
		return _parse_let()
	if _match_kw("func"):
		return _parse_func_decl()
	if _match_kw("if"):
		return _parse_if()
	if _match_kw("while"):
		return _parse_while()
	if _match_kw("for"):
		return _parse_for()
	if _match_kw("return"):
		_ti += 1
		var v = null
		if not _is_eof() and not _match_kw(["end", "elseif", "else"]):
			v = _parse_expr()
		return {"type": "ret", "value": v}
	if _match_kw("break"):
		_ti += 1
		return {"type": "break"}
	if _match_kw("continue"):
		_ti += 1
		return {"type": "continue"}
	# expression statement (or assignment)
	return _parse_expr_or_assign()


func _parse_let():
	_ti += 1  # let/var
	var name_tok := _consume(TOK_ID)
	_consume(TOK_OP, "=")
	var val = _parse_expr()
	return {"type": "let", "name": name_tok[1], "value": val}


func _parse_func_decl():
	_ti += 1  # func
	var name_tok := _consume(TOK_ID)
	_consume(TOK_OP, "(")
	var params: Array = []
	if not _match_op(")"):
		while true:
			var p := _consume(TOK_ID)
			params.append(p[1])
			if _match_op(","):
				_ti += 1
				continue
			break
	_consume(TOK_OP, ")")
	var body: Array = []
	while not _match_kw("end") and not _is_eof():
		var s = _parse_stmt()
		if last_error != "": return null
		body.append(s)
	_consume(TOK_KW, "end")
	return {"type": "func_decl", "name": name_tok[1],
		"params": params, "body": body}


func _parse_if():
	_ti += 1  # if
	var cond = _parse_expr()
	_consume(TOK_KW, "then")
	var then_body: Array = []
	while not _match_kw(["elseif", "else", "end"]) and not _is_eof():
		var s = _parse_stmt()
		if last_error != "": return null
		then_body.append(s)
	var else_branch = null
	if _match_kw("elseif"):
		else_branch = [_parse_if()]
	elif _match_kw("else"):
		_ti += 1
		else_branch = []
		while not _match_kw("end") and not _is_eof():
			var s = _parse_stmt()
			else_branch.append(s)
	if _match_kw("end"):
		_ti += 1
	return {"type": "if", "cond": cond,
		"then": then_body, "else": else_branch}


func _parse_while():
	_ti += 1  # while
	var cond = _parse_expr()
	_consume(TOK_KW, "do")
	var body: Array = []
	while not _match_kw("end") and not _is_eof():
		var s = _parse_stmt()
		if last_error != "": return null
		body.append(s)
	_consume(TOK_KW, "end")
	return {"type": "while", "cond": cond, "body": body}


func _parse_for():
	_ti += 1  # for
	var name_tok := _consume(TOK_ID)
	_consume(TOK_KW, "in")
	var iter = _parse_expr()
	_consume(TOK_KW, "do")
	var body: Array = []
	while not _match_kw("end") and not _is_eof():
		var s = _parse_stmt()
		body.append(s)
	_consume(TOK_KW, "end")
	return {"type": "for", "var": name_tok[1], "iter": iter, "body": body}


func _parse_expr_or_assign():
	var left = _parse_expr()
	if _match_op("="):
		_ti += 1
		var right = _parse_expr()
		return {"type": "assign", "target": left, "value": right}
	return {"type": "expr_stmt", "value": left}


func _parse_expr():
	return _parse_or()


func _parse_or():
	var left = _parse_and()
	while _match_kw("or") or _match_op("||"):
		_ti += 1
		var right = _parse_and()
		left = {"type": "bin", "op": "or", "lhs": left, "rhs": right}
	return left


func _parse_and():
	var left = _parse_not()
	while _match_kw("and") or _match_op("&&"):
		_ti += 1
		var right = _parse_not()
		left = {"type": "bin", "op": "and", "lhs": left, "rhs": right}
	return left


func _parse_not():
	if _match_kw("not") or _match_op("!"):
		_ti += 1
		return {"type": "unary", "op": "not", "expr": _parse_not()}
	return _parse_cmp()


func _parse_cmp():
	var left = _parse_add()
	while _match_op(["==", "!=", "<=", ">=", "<", ">"]):
		var op: String = _peek()[1]
		_ti += 1
		var right = _parse_add()
		left = {"type": "bin", "op": op, "lhs": left, "rhs": right}
	return left


func _parse_add():
	var left = _parse_mul()
	while _match_op(["+", "-", ".."]):
		var op: String = _peek()[1]
		_ti += 1
		var right = _parse_mul()
		left = {"type": "bin", "op": op, "lhs": left, "rhs": right}
	return left


func _parse_mul():
	var left = _parse_unary()
	while _match_op(["*", "/", "%"]):
		var op: String = _peek()[1]
		_ti += 1
		var right = _parse_unary()
		left = {"type": "bin", "op": op, "lhs": left, "rhs": right}
	return left


func _parse_unary():
	if _match_op("-"):
		_ti += 1
		return {"type": "unary", "op": "-", "expr": _parse_unary()}
	return _parse_postfix()


func _parse_postfix():
	var node = _parse_atom()
	while true:
		if _match_op("("):
			_ti += 1
			var args: Array = []
			if not _match_op(")"):
				while true:
					args.append(_parse_expr())
					if _match_op(","):
						_ti += 1
						continue
					break
			_consume(TOK_OP, ")")
			node = {"type": "call", "fn": node, "args": args}
		elif _match_op("."):
			_ti += 1
			var nm := _consume(TOK_ID)
			node = {"type": "member", "obj": node, "name": nm[1]}
		elif _match_op("["):
			_ti += 1
			var idx = _parse_expr()
			_consume(TOK_OP, "]")
			node = {"type": "index", "obj": node, "index": idx}
		else:
			break
	return node


func _parse_atom():
	var t = _peek()
	if t[0] == TOK_NUM:
		_ti += 1
		return {"type": "num", "value": t[1]}
	if t[0] == TOK_STR:
		_ti += 1
		return {"type": "str", "value": t[1]}
	if t[0] == TOK_KW and t[1] in ["true", "false"]:
		_ti += 1
		return {"type": "bool", "value": t[1] == "true"}
	if t[0] == TOK_KW and t[1] == "nil":
		_ti += 1
		return {"type": "nil"}
	if t[0] == TOK_KW and t[1] == "func":
		# Anonymous function literal:  func(a, b) ... end
		_ti += 1
		_consume(TOK_OP, "(")
		var params: Array = []
		if not _match_op(")"):
			while true:
				var p := _consume(TOK_ID)
				params.append(p[1])
				if _match_op(","):
					_ti += 1
					continue
				break
		_consume(TOK_OP, ")")
		var body: Array = []
		while not _match_kw("end") and not _is_eof():
			var s = _parse_stmt()
			body.append(s)
		_consume(TOK_KW, "end")
		return {"type": "func", "params": params, "body": body}
	if t[0] == TOK_OP and t[1] == "(":
		_ti += 1
		var e = _parse_expr()
		_consume(TOK_OP, ")")
		return e
	if t[0] == TOK_OP and t[1] == "[":
		_ti += 1
		var arr: Array = []
		if not _match_op("]"):
			while true:
				arr.append(_parse_expr())
				if _match_op(","):
					_ti += 1
					continue
				break
		_consume(TOK_OP, "]")
		return {"type": "array", "values": arr}
	if t[0] == TOK_OP and t[1] == "{":
		_ti += 1
		var d: Dictionary = {}
		if not _match_op("}"):
			while true:
				var key_tok := _consume(TOK_ID)
				_consume(TOK_OP, "=")
				var v = _parse_expr()
				d[key_tok[1]] = v
				if _match_op(","):
					_ti += 1
					continue
				break
		_consume(TOK_OP, "}")
		return {"type": "dict", "pairs": d}
	if t[0] == TOK_ID:
		_ti += 1
		return {"type": "name", "value": t[1]}
	last_error = "Parse error: unexpected %s '%s' at line %d" % \
		[t[0], str(t[1]), t[2]]
	return {"type": "nil"}


# ──────────────────────────────────────────────────────────────────────────
# Evaluator
# ──────────────────────────────────────────────────────────────────────────
class _Env:
	var parent: _Env
	var values: Dictionary = {}

	func _init(p: _Env = null) -> void:
		parent = p

	func get_var(name: String):
		if values.has(name): return values[name]
		if parent: return parent.get_var(name)
		return null

	func set_var(name: String, value) -> void:
		if values.has(name) or parent == null:
			values[name] = value
			return
		# Try to find an existing scope binding.
		var e: _Env = parent
		while e:
			if e.values.has(name):
				e.values[name] = value
				return
			e = e.parent
		values[name] = value

	func define(name: String, value) -> void:
		values[name] = value


class _BreakSignal extends RefCounted: pass
class _ContinueSignal extends RefCounted: pass
class _ReturnSignal extends RefCounted:
	var value
	func _init(v): value = v


func _eval(node, env_or_dict):
	if last_error != "":
		return null
	if node == null:
		return null
	# env_or_dict may be a Dictionary (globals) or _Env (nested scope).
	# Wrap dictionaries on first descent so we treat both uniformly.
	if env_or_dict is Dictionary:
		var top := _Env.new()
		top.values = env_or_dict
		env_or_dict = top
	var env: _Env = env_or_dict
	match node["type"]:
		"num": return node["value"]
		"str": return node["value"]
		"bool": return node["value"]
		"nil": return null
		"name": return env.get_var(node["value"])
		"array":
			var arr: Array = []
			for v in node["values"]:
				arr.append(_eval(v, env))
			return arr
		"dict":
			var d: Dictionary = {}
			for k in node["pairs"]:
				d[k] = _eval(node["pairs"][k], env)
			return d
		"unary":
			var v = _eval(node["expr"], env)
			match node["op"]:
				"-": return -float(v)
				"not": return not bool(v)
			return null
		"bin":
			var op: String = node["op"]
			if op == "and":
				var l = _eval(node["lhs"], env)
				if not l: return l
				return _eval(node["rhs"], env)
			if op == "or":
				var l2 = _eval(node["lhs"], env)
				if l2: return l2
				return _eval(node["rhs"], env)
			var lhs = _eval(node["lhs"], env)
			var rhs = _eval(node["rhs"], env)
			match op:
				"+":
					if lhs is String or rhs is String:
						return str(lhs) + str(rhs)
					return lhs + rhs
				"-": return lhs - rhs
				"*": return lhs * rhs
				"/":
					if typeof(rhs) in [TYPE_FLOAT, TYPE_INT] and float(rhs) == 0.0:
						return 0.0
					return lhs / rhs
				"%":
					if typeof(rhs) in [TYPE_FLOAT, TYPE_INT] and float(rhs) == 0.0:
						return 0.0
					return fposmod(float(lhs), float(rhs))
				"..": return str(lhs) + str(rhs)
				"==": return lhs == rhs
				"!=": return lhs != rhs
				"<": return lhs < rhs
				">": return lhs > rhs
				"<=": return lhs <= rhs
				">=": return lhs >= rhs
			return null
		"call":
			var callee = _eval(node["fn"], env)
			var args: Array = []
			for a in node["args"]:
				args.append(_eval(a, env))
			return _invoke(callee, args)
		"member":
			var obj = _eval(node["obj"], env)
			if obj is Dictionary:
				return obj.get(node["name"], null)
			if obj is Object and obj.has_method(node["name"]):
				return Callable(obj, node["name"])
			return null
		"index":
			var obj2 = _eval(node["obj"], env)
			var idx = _eval(node["index"], env)
			if obj2 is Array:
				return obj2[int(idx)] if int(idx) >= 0 and int(idx) < obj2.size() else null
			if obj2 is Dictionary:
				return obj2.get(idx, null)
			return null
		"let":
			env.define(node["name"], _eval(node["value"], env))
			return null
		"assign":
			var val = _eval(node["value"], env)
			var target = node["target"]
			if target["type"] == "name":
				env.set_var(target["value"], val)
			elif target["type"] == "member":
				var obj3 = _eval(target["obj"], env)
				if obj3 is Dictionary:
					obj3[target["name"]] = val
			elif target["type"] == "index":
				var obj4 = _eval(target["obj"], env)
				var idx4 = _eval(target["index"], env)
				if obj4 is Array:
					obj4[int(idx4)] = val
				elif obj4 is Dictionary:
					obj4[idx4] = val
			return null
		"func", "func_decl":
			var fn := {
				"_ratscript_fn": true,
				"params": node["params"],
				"body": node["body"],
				"closure": env,
			}
			if node["type"] == "func_decl":
				env.define(node["name"], fn)
			return fn
		"expr_stmt":
			_eval(node["value"], env)
			return null
		"ret":
			var rv = _eval(node["value"], env) if node["value"] != null else null
			return _ReturnSignal.new(rv)
		"break": return _BreakSignal.new()
		"continue": return _ContinueSignal.new()
		"if":
			var c = _eval(node["cond"], env)
			if c:
				var sub := _Env.new(env)
				for s in node["then"]:
					var r = _eval(s, sub)
					if r is _ReturnSignal or r is _BreakSignal or r is _ContinueSignal:
						return r
			else:
				if node["else"] != null:
					var sub2 := _Env.new(env)
					for s in node["else"]:
						var r2 = _eval(s, sub2)
						if r2 is _ReturnSignal or r2 is _BreakSignal or r2 is _ContinueSignal:
							return r2
			return null
		"while":
			while _eval(node["cond"], env):
				var sub := _Env.new(env)
				var br := false
				for s in node["body"]:
					var r = _eval(s, sub)
					if r is _BreakSignal:
						br = true
						break
					if r is _ContinueSignal: break
					if r is _ReturnSignal: return r
				if br: break
			return null
		"for":
			var iter = _eval(node["iter"], env)
			if iter is Array:
				for v in iter:
					var sub := _Env.new(env)
					sub.define(node["var"], v)
					var br := false
					for s in node["body"]:
						var r = _eval(s, sub)
						if r is _BreakSignal:
							br = true
							break
						if r is _ContinueSignal: break
						if r is _ReturnSignal: return r
					if br: break
			return null
	return null


func _invoke(callee, args: Array):
	if callee is Callable:
		# Many builtins accept a single Array argument; call directly.
		return callee.call(args)
	if callee is Dictionary and callee.get("_ratscript_fn", false):
		var sub := _Env.new(callee["closure"])
		var params: Array = callee["params"]
		for i in params.size():
			sub.define(params[i], args[i] if i < args.size() else null)
		for s in callee["body"]:
			var r = _eval(s, sub)
			if r is _ReturnSignal:
				return r.value
		return null
	if callee == null:
		return null
	push_warning("RatScript: attempted to call non-callable %s" % str(callee))
	return null


# NOTE: the on() lambda now captures the user fn in its closure directly,
# so no separate _invoke_user_fn bridge is needed.

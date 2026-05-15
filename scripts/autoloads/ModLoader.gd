# ModLoader.gd
# Discovers, parses, and activates RatRovert mods (.retrovert files).
#
# A .retrovert file is a ZIP archive with the following layout:
#
#   mod.json              ← required manifest (id, name, version, …)
#   icon.png              ← optional 64×64 RGBA icon
#   scripts/*.rrs         ← RatScript source files
#   assets/sprites/*.png  ← optional sprite overrides
#   assets/audio/*.wav    ← optional sfx overrides
#   data/items.json       ← optional declarative item definitions
#   README.md             ← optional documentation
#
# Mods are extracted into user://mods/<mod_uuid>/.  Each mod is identified
# by a Minecraft-style "fancy UUID" — short, URL-safe, mostly readable.
extends Node

const MODS_DIR := "user://mods"
const MODS_REGISTRY := "user://mods.cfg"
const RATSCRIPT_EXT := ".rrs"

# Active mods, by uuid.
var active_mods: Dictionary = {}
# Discovered mods (active and inactive).
var registered_mods: Dictionary = {}
# Interpreter pool — one per active mod.
var _interpreters: Dictionary = {}


# ──────────────────────────────────────────────────────────────────────────
# Mod manifest object
# ──────────────────────────────────────────────────────────────────────────
class ModInfo:
	var uuid: String = ""
	var id: String = ""
	var name: String = ""
	var version: String = "1.0.0"
	var author: String = ""
	var description: String = ""
	var icon_path: String = ""
	var entry: String = "scripts/main.rrs"
	var dependencies: Array = []
	var tags: Array = []
	var installed_path: String = ""
	var enabled: bool = true

	func to_dict() -> Dictionary:
		return {
			"uuid": uuid, "id": id, "name": name, "version": version,
			"author": author, "description": description,
			"icon_path": icon_path, "entry": entry,
			"dependencies": dependencies, "tags": tags,
			"installed_path": installed_path, "enabled": enabled,
		}


# ──────────────────────────────────────────────────────────────────────────
# Lifecycle
# ──────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_ensure_mods_dir()
	# Import bundled `.retrovert` packs (first run only) before scanning.
	if ModBundles and ModBundles.has_method("import_if_needed"):
		ModBundles.import_if_needed()
	_load_registry()
	_scan_installed_mods()
	set_process(true)
	# Defer activation so all autoloads are ready.
	call_deferred("_activate_all_enabled")


func _process(delta: float) -> void:
	# Dispatch on_tick(dt) to every active mod that defined it.
	for uuid in _interpreters.keys():
		var interp = _interpreters[uuid]
		if interp and interp.has_method("call_lifecycle"):
			interp.call_lifecycle("on_tick", [delta])


func _ensure_mods_dir() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(MODS_DIR)):
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(MODS_DIR))


# ──────────────────────────────────────────────────────────────────────────
# UUID generation — Minecraft-style fancy short ids.
# ──────────────────────────────────────────────────────────────────────────
const _UUID_CHARS := "0123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ"
const _UUID_SUFFIXES := ["mh", "kp", "rg", "tt", "qx", "nn", "yz", "ds", "vf",
	"xp", "kf", "ji", "li", "io"]


func generate_uuid(seed_str: String = "") -> String:
	# Format: <8 hex>:<6 mixed>&name+<4 digits>%<symbol>.<1-2>
	# e.g.   64ffjbhk:6yddmh&name+7890%$.1
	var rng := RandomNumberGenerator.new()
	if seed_str != "":
		rng.seed = hash(seed_str + str(Time.get_unix_time_from_system()))
	else:
		rng.randomize()
	var p1 := ""
	for i in 8:
		p1 += _UUID_CHARS[rng.randi() % _UUID_CHARS.length()]
	var p2 := ""
	for i in 4:
		p2 += _UUID_CHARS[rng.randi() % _UUID_CHARS.length()]
	var suf: String = _UUID_SUFFIXES[rng.randi() % _UUID_SUFFIXES.size()]
	var digits := "%04d" % rng.randi_range(0, 9999)
	var sym: String = "$#@!".substr(rng.randi() % 4, 1)
	var tail: int = rng.randi_range(1, 9)
	return "%s:%s%s&name+%s%s.%d" % [p1, p2, suf, digits, sym, tail]


# ──────────────────────────────────────────────────────────────────────────
# Discovery
# ──────────────────────────────────────────────────────────────────────────
func _scan_installed_mods() -> void:
	var dir := DirAccess.open(MODS_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != ".." and dir.current_is_dir():
			var path: String = MODS_DIR.path_join(name)
			var manifest_path: String = path.path_join("mod.json")
			if FileAccess.file_exists(manifest_path):
				var info := _read_manifest(manifest_path, path)
				if info:
					registered_mods[info.uuid] = info
		name = dir.get_next()
	dir.list_dir_end()


func _read_manifest(path: String, install_dir: String) -> ModInfo:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ModLoader: invalid manifest at %s" % path)
		return null
	var info := ModInfo.new()
	info.uuid = parsed.get("uuid", generate_uuid(parsed.get("id", "")))
	info.id = parsed.get("id", "mod_%s" % info.uuid.substr(0, 8))
	info.name = parsed.get("name", info.id)
	info.version = parsed.get("version", "1.0.0")
	info.author = parsed.get("author", "")
	info.description = parsed.get("description", "")
	info.entry = parsed.get("entry", "scripts/main.rrs")
	info.dependencies = parsed.get("dependencies", [])
	info.tags = parsed.get("tags", [])
	info.installed_path = install_dir
	var icon = install_dir.path_join("icon.png")
	info.icon_path = icon if FileAccess.file_exists(icon) else ""
	info.enabled = _registry_enabled(info.uuid, true)
	return info


# ──────────────────────────────────────────────────────────────────────────
# Import / install a .retrovert archive.
# ──────────────────────────────────────────────────────────────────────────
func import_mod_from_file(zip_path: String) -> ModInfo:
	if not FileAccess.file_exists(zip_path):
		push_warning("import_mod_from_file: file not found %s" % zip_path)
		return null
	var zip := ZIPReader.new()
	if zip.open(zip_path) != OK:
		push_warning("import_mod_from_file: cannot open zip %s" % zip_path)
		return null
	# Read manifest first to get a uuid (or assign one).
	var manifest_bytes := zip.read_file("mod.json")
	if manifest_bytes.is_empty():
		push_warning("import_mod_from_file: missing mod.json")
		zip.close()
		return null
	var parsed = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		zip.close()
		return null
	var uuid: String = parsed.get("uuid", "")
	if uuid == "":
		uuid = generate_uuid(parsed.get("id", ""))
		parsed["uuid"] = uuid
	var install_dir: String = MODS_DIR.path_join(uuid)
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(install_dir))
	for name in zip.get_files():
		var dest: String = install_dir.path_join(name)
		var bytes := zip.read_file(name)
		var parent_dir: String = dest.get_base_dir()
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(parent_dir))
		if name == "mod.json":
			# Rewrite manifest with assigned uuid.
			var f := FileAccess.open(dest, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify(parsed, "  "))
				f.close()
		else:
			var f := FileAccess.open(dest, FileAccess.WRITE)
			if f:
				f.store_buffer(bytes)
				f.close()
	zip.close()
	var info := _read_manifest(install_dir.path_join("mod.json"), install_dir)
	if info:
		registered_mods[info.uuid] = info
		_save_registry()
	return info


# ──────────────────────────────────────────────────────────────────────────
# Export an installed mod back into .retrovert (zip).
# ──────────────────────────────────────────────────────────────────────────
func export_mod(uuid: String, dest_zip: String) -> bool:
	var info: ModInfo = registered_mods.get(uuid)
	if info == null:
		return false
	var writer := ZIPPacker.new()
	if writer.open(dest_zip) != OK:
		return false
	_zip_walk(writer, info.installed_path, "")
	writer.close()
	return true


func _zip_walk(writer: ZIPPacker, base: String, prefix: String) -> void:
	var dir := DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full: String = base.path_join(name)
			var inner: String = prefix.path_join(name) if prefix != "" else name
			if dir.current_is_dir():
				_zip_walk(writer, full, inner)
			else:
				var f := FileAccess.open(full, FileAccess.READ)
				if f:
					var bytes := f.get_buffer(f.get_length())
					f.close()
					writer.start_file(inner)
					writer.write_file(bytes)
					writer.close_file()
		name = dir.get_next()
	dir.list_dir_end()


# ──────────────────────────────────────────────────────────────────────────
# Activation
# ──────────────────────────────────────────────────────────────────────────
func _activate_all_enabled() -> void:
	for uuid in registered_mods:
		var info: ModInfo = registered_mods[uuid]
		if info.enabled:
			activate(uuid)


func activate(uuid: String) -> bool:
	if active_mods.has(uuid):
		return true
	var info: ModInfo = registered_mods.get(uuid)
	if info == null:
		return false
	var entry: String = info.installed_path.path_join(info.entry)
	if not FileAccess.file_exists(entry):
		push_warning("ModLoader: missing entry %s" % entry)
		EventBus.mod_error.emit(uuid, "missing entry")
		return false
	var interp = load("res://scripts/mods/ratscript/Interpreter.gd").new()
	interp.set_mod_context(info)
	active_mods[uuid] = info
	_interpreters[uuid] = interp
	# Auto-register declarative data files.
	_register_data_files(info)
	# Run the entry script.
	var f := FileAccess.open(entry, FileAccess.READ)
	if f:
		var src := f.get_as_text()
		f.close()
		var ok = interp.run(src, info.entry)
		if not ok:
			EventBus.mod_error.emit(uuid, interp.last_error)
	info.enabled = true
	_save_registry()
	# Fire `on_load` if the script defined one.
	if interp.has_method("call_lifecycle"):
		interp.call_lifecycle("on_load", [])
	ChatOverlay.mod("loaded", info.name)
	EventBus.mod_loaded.emit(uuid)
	return true


func deactivate(uuid: String) -> void:
	if not active_mods.has(uuid):
		return
	var interp = _interpreters.get(uuid)
	if interp and interp.has_method("call_lifecycle"):
		interp.call_lifecycle("on_unload", [])
	if interp and interp.has_method("shutdown"):
		interp.shutdown()
	_interpreters.erase(uuid)
	active_mods.erase(uuid)
	ItemDatabase.unregister_mod_items(uuid)
	var info: ModInfo = registered_mods.get(uuid)
	if info:
		ChatOverlay.mod("unloaded", info.name)
	if registered_mods.has(uuid):
		registered_mods[uuid].enabled = false
	_save_registry()
	EventBus.mod_unloaded.emit(uuid)


func uninstall(uuid: String) -> void:
	deactivate(uuid)
	var info: ModInfo = registered_mods.get(uuid)
	if info == null:
		return
	_delete_dir(info.installed_path)
	registered_mods.erase(uuid)
	_save_registry()


func reload_all() -> void:
	for uuid in active_mods.keys():
		deactivate(uuid)
	_scan_installed_mods()
	_activate_all_enabled()
	EventBus.mods_reloaded.emit()


# ──────────────────────────────────────────────────────────────────────────
# Declarative items (data/items.json)
# ──────────────────────────────────────────────────────────────────────────
func _register_data_files(info: ModInfo) -> void:
	var items_path: String = info.installed_path.path_join("data/items.json")
	if not FileAccess.file_exists(items_path):
		return
	var f := FileAccess.open(items_path, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var arr = JSON.parse_string(raw)
	if typeof(arr) != TYPE_ARRAY:
		return
	for entry in arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		ModAPI.items.register_from_dict(entry, info.uuid)


# ──────────────────────────────────────────────────────────────────────────
# Registry helpers
# ──────────────────────────────────────────────────────────────────────────
func _registry_enabled(uuid: String, default_val: bool) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(MODS_REGISTRY) != OK:
		return default_val
	return bool(cfg.get_value("enabled", uuid, default_val))


func _load_registry() -> void:
	pass  # registry is read on demand via _registry_enabled


func _save_registry() -> void:
	var cfg := ConfigFile.new()
	for uuid in registered_mods:
		var info: ModInfo = registered_mods[uuid]
		cfg.set_value("enabled", uuid, info.enabled)
	cfg.save(MODS_REGISTRY)


func _delete_dir(path: String) -> void:
	var abs: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs):
		return
	OS.move_to_trash(abs)  # safer than rmdir


# ──────────────────────────────────────────────────────────────────────────
# Public queries
# ──────────────────────────────────────────────────────────────────────────
func list_installed() -> Array:
	return registered_mods.values()


func list_active() -> Array:
	return active_mods.values()


func is_active(uuid: String) -> bool:
	return active_mods.has(uuid)


func get_info(uuid: String) -> ModInfo:
	return registered_mods.get(uuid)

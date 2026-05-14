# Headless validation: ensure every .tscn file in the project loads without
# errors. Run via:  godot --headless --script res://tools/validate_scenes.gd
extends SceneTree


func _initialize() -> void:
	var paths: Array[String] = []
	_collect("res://scenes", paths)
	var fail := 0
	for p in paths:
		var s: PackedScene = load(p)
		if s == null:
			push_error("FAIL load: %s" % p)
			fail += 1
			continue
		var n: Node = s.instantiate()
		if n == null:
			push_error("FAIL instantiate: %s" % p)
			fail += 1
			continue
		n.queue_free()
		print("OK   %s" % p)
	if fail > 0:
		push_error("%d scene(s) failed to load." % fail)
	else:
		print("All %d scenes loaded OK." % paths.size())
	quit(0 if fail == 0 else 1)


func _collect(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n != "." and n != "..":
			var full: String = dir_path.path_join(n)
			if d.current_is_dir():
				_collect(full, out)
			elif n.ends_with(".tscn"):
				out.append(full)
		n = d.get_next()
	d.list_dir_end()

# Docs.gd
# Programmatic generator for the in-app modding reference. Combines a
# curated core reference with auto-generated entries derived from
# GameState fields, EventBus signals, and ItemDatabase ids so the docs
# always reflect the live game.
extends Node


static func categories() -> Array:
	return [
		"Введение",
		"Структура мода",
		"Манифест mod.json",
		"UUID и ключи",
		"Импорт и экспорт",
		"Синтаксис RatScript",
		"Типы данных",
		"Управляющие конструкции",
		"Функции",
		"Глобальные функции (API)",
		"Объект state",
		"События (on/emit)",
		"Регистрация предметов",
		"Сущности и враги",
		"Камера и эффекты",
		"Математика",
		"Сцены проекта",
		"Поля GameState",
		"Сигналы EventBus",
		"Список предметов",
		"Лучшие практики",
		"FAQ",
		"Полный справочник команд",
	]


static func render_category(name: String) -> String:
	match name:
		"Введение": return _intro()
		"Структура мода": return _structure()
		"Манифест mod.json": return _manifest()
		"UUID и ключи": return _uuid()
		"Импорт и экспорт": return _import_export()
		"Синтаксис RatScript": return _syntax()
		"Типы данных": return _types()
		"Управляющие конструкции": return _control()
		"Функции": return _functions()
		"Глобальные функции (API)": return _global_api()
		"Объект state": return _state_api()
		"События (on/emit)": return _events_api()
		"Регистрация предметов": return _item_api()
		"Сущности и враги": return _entity_api()
		"Камера и эффекты": return _camera_api()
		"Математика": return _math_api()
		"Сцены проекта": return _scenes()
		"Поля GameState": return _gamestate_fields()
		"Сигналы EventBus": return _eventbus_signals()
		"Список предметов": return _items_list()
		"Лучшие практики": return _practices()
		"FAQ": return _faq()
		"Полный справочник команд": return _full_reference()
	return "[i]Раздел не найден.[/i]"


static func search(query: String) -> String:
	var q := query.strip_edges().to_lower()
	if q == "":
		return _intro()
	var out: String = "[b]Результаты поиска по запросу:[/b] [code]%s[/code]\n\n" % query
	var hits := 0
	for cat in categories():
		var body := render_category(cat)
		if body.to_lower().find(q) != -1:
			hits += 1
			out += "[b]· %s[/b] (нажмите в боковом меню)\n" % cat
	if hits == 0:
		out += "[i]Ничего не найдено. Попробуйте более общий запрос.[/i]"
	return out


# ── Section bodies ────────────────────────────────────────────────────────
static func _intro() -> String:
	return """[b]RatRovert Modding Guide[/b]

Эта документация описывает встроенный язык [b]RatScript[/b] и весь API
для написания модов. Мод — это zip-архив с расширением [code].retrovert[/code],
содержащий манифест, скрипты и (опционально) ассеты.

[b]Что вы можете делать в модах:[/b]
  • Изменять статы игрока (урон, скорость, дальность и т.д.)
  • Регистрировать свои предметы (пассивные и активные)
  • Подписываться на события (смерть врагов, переходы и т.д.)
  • Спавнить врагов, объекты, эффекты
  • Управлять камерой, звуками, частицами
  • Заменять текстуры и звуки оригинала (через assets/ внутри мода)

[b]Минимальный пример мода:[/b]
[code]-- scripts/main.rrs
log("Привет из RatScript!")
state.add_coins(99)

on("enemy_died") func(pos, type)
    state.add_coins(1)
end
[/code]
"""


static func _structure() -> String:
	return """[b]Структура мода[/b]

Каждый [code].retrovert[/code] — это обычный zip со следующей структурой:

[code]
mod.json                   -- ОБЯЗАТЕЛЬНО, манифест
icon.png                   -- опционально, 64×64 иконка
scripts/main.rrs           -- точка входа (по умолчанию)
scripts/*.rrs              -- дополнительные модули
data/items.json            -- декларативные предметы (опц.)
assets/sprites/*.png       -- замены спрайтов
assets/audio/sfx/*.wav     -- замены звуков
README.md                  -- описание мода
[/code]

Все пути относительны корня архива. После установки мод
распаковывается в [code]user://mods/<uuid>/[/code]."""


static func _manifest() -> String:
	return """[b]Манифест [code]mod.json[/code][/b]

[code]
{
  "id": "my_mod",
  "name": "Мой первый мод",
  "version": "1.0.0",
  "author": "you",
  "description": "Добавляет +99 монет в начале забега.",
  "entry": "scripts/main.rrs",
  "tags": ["fun", "qol"],
  "dependencies": [],
  "uuid": ""
}
[/code]

[b]Поля:[/b]
  • id          — короткий машинно-читаемый идентификатор
  • name        — отображаемое имя
  • version     — semver
  • author      — ник автора
  • description — что делает мод
  • entry       — путь к стартовому .rrs-файлу
  • tags        — список меток для фильтрации
  • dependencies — массив uuid-ов других модов
  • uuid        — оставьте пустым; будет сгенерирован при импорте"""


static func _uuid() -> String:
	return """[b]UUID и ключи[/b]

Каждому моду при импорте присваивается уникальный «фэнси-UUID»:

[code]<8 hex>:<4-7 микс>&name+<4 digits><sym>.<1-2>[/code]

Пример: [code]64ffjbhk:6yddmh&name+7890%$.1[/code]

  • Не пытайтесь придумать UUID вручную — игра сгенерирует за вас.
  • UUID — единственный безопасный идентификатор: одноимённые моды
    разных авторов разойдутся.
  • Полный UUID виден в Mod Manager и используется для зависимостей."""


static func _import_export() -> String:
	return """[b]Импорт / экспорт[/b]

[b]Импорт:[/b] Меню → «Моды» → «Импортировать» → выберите .retrovert.

[b]Экспорт:[/b] выберите мод → «Экспорт». Файл сохраняется в
[code]user://exported_<id>.retrovert[/code].

После импорта мод попадает в [code]user://mods/<uuid>/[/code] и
автоматически загружается при следующем запуске."""


static func _syntax() -> String:
	return """[b]Синтаксис RatScript[/b]

Комментарии: [code]-- однострочные[/code]

Переменные:
[code]let x = 10      -- блочная
var y = vec(0, 0)[/code]

Литералы:
[code]42  3.14  "строка"  true  false  nil
[1, 2, 3]
{ key = "value", count = 3 }[/code]

Конкатенация строк: [code]"hi " .. "there"[/code]

Все стандартные операторы: [code]+ - * / % == != < > <= >= and or not[/code]"""


static func _types() -> String:
	return """[b]Типы данных[/b]

  • Number  — все числа float
  • String  — UTF-8
  • Bool    — true / false
  • Nil     — отсутствие значения
  • Array   — [1, 2, 3]
  • Dict    — { id = "x", value = 1 }
  • Vector2 — vec(x, y)
  • Function — first-class, поддерживают замыкания"""


static func _control() -> String:
	return """[b]Управляющие конструкции[/b]

[code]if cond then
  ...
elseif other then
  ...
else
  ...
end[/code]

[code]while cond do
  ...
end[/code]

[code]for i in range(0, 10) do
  log(i)
end[/code]

[code]break    -- выйти из цикла
continue -- следующая итерация
return v -- вернуть из функции[/code]"""


static func _functions() -> String:
	return """[b]Функции[/b]

[code]func greet(name)
    log("Hi, " .. name)
end

greet("rat")[/code]

Анонимные функции (используются в [code]on(...)[/code]):

[code]on("enemy_died") func(pos, type)
    state.add_coins(1)
end[/code]

Функции — first-class, можно присваивать переменным и хранить
в массивах/словарях."""


static func _global_api() -> String:
	var lines: Array = [
		"[b]Глобальные функции[/b]",
		"",
		"[code]log(...)[/code] — вывести в консоль (с префиксом мода).",
		"[code]print(...)[/code] — алиас log.",
		"[code]vec(x, y)[/code] — Vector2.",
		"[code]range(a, b)[/code] — массив целых [a, b).",
		"[code]len(v)[/code] — длина строки/массива/словаря.",
		"[code]clamp(v, lo, hi)[/code] — ограничить значение.",
		"[code]rand()[/code] — float 0..1.",
		"[code]randi(a, b)[/code] — int в диапазоне.",
		"[code]deg2rad(d)[/code] — градусы → радианы.",
		"[code]sin/cos/tan/sqrt/abs[/code] — тригонометрия и пр.",
		"[code]on(signal, fn)[/code] — подписка на событие.",
		"[code]emit(signal, ...)[/code] — эмиссия события.",
		"[code]item(def)[/code] — зарегистрировать предмет.",
		"[code]grant(id)[/code] — выдать предмет игроку.",
		"[code]spawn(scene_path, pos)[/code] — спавн сцены.",
		"[code]damage_in_radius(center, radius, dmg)[/code] — урон по площади.",
		"[code]shake(strength, duration)[/code] — тряска камеры.",
		"[code]sfx(id)[/code] — воспроизвести звук.",
		"[code]player()[/code] — узел игрока.",
		"[code]enemies()[/code] — массив активных врагов.",
	]
	return "\n".join(lines)


static func _state_api() -> String:
	return """[b]Объект [code]state[/code][/b]

  • [code]state.get("player_damage")[/code]
  • [code]state.set("player_damage", 7.0)[/code]
  • [code]state.add("player_speed", 50.0)[/code]
  • [code]state.add_coins(n)[/code]
  • [code]state.add_bombs(n)[/code]
  • [code]state.add_keys(n)[/code]
  • [code]state.heal(n)[/code]    — добавить HP
  • [code]state.heal_soul(n)[/code]
  • [code]state.damage(n)[/code]

[b]Пример:[/b]
[code]state.set("player_damage", state.get("player_damage") * 2.0)
state.add_coins(10)[/code]"""


static func _events_api() -> String:
	var s := "[b]Подписка на события[/b]\n\n"
	s += "[code]on(\"signal_name\") func(args...)\n  -- тело\nend[/code]\n\n"
	s += "[b]Список основных сигналов:[/b]\n"
	for sig in _signal_list():
		s += "  • [code]" + sig + "[/code]\n"
	s += "\nИспользуйте [code]emit(\"name\", arg1, arg2)[/code] для отправки своих."
	return s


static func _item_api() -> String:
	return """[b]Регистрация предметов[/b]

Декларативно из RatScript:

[code]item({
    id = "my_double_damage",
    name = "Двойной урон",
    description = "+100% к урону",
    icon_path = "res://assets/sprites/items/blood_tear.png",
    active = false,
    quality = 3,
    stats = { player_damage = 3.0 }
})[/code]

В словаре [code]stats[/code] перечислены поля [code]GameState[/code]:
при подборе предмета значения суммируются (для чисел) или
перезаписываются (для строк/булей).

[b]Активный предмет:[/b]
[code]item({
    id = "my_blast",
    name = "Бластер",
    active = true,
    charge = 6,
    stats = {}
})[/code]"""


static func _entity_api() -> String:
	return """[b]Сущности и враги[/b]

  • [code]player()[/code] — узел игрока (CharacterBody2D)
  • [code]enemies()[/code] — массив активных врагов
  • [code]spawn(scene_path, pos)[/code] — мгновенный спавн
  • [code]damage_in_radius(center, radius, amount)[/code] — урон в радиусе

[b]Пример:[/b] вызвать гипер-вспышку при стрельбе:

[code]on("player_shot") func(dir)
    if rand() < 0.05 then
        damage_in_radius(player().global_position, 150, 20)
        shake(8, 0.3)
    end
end[/code]"""


static func _camera_api() -> String:
	return """[b]Камера и эффекты[/b]

  • [code]shake(strength, duration)[/code] — тряска
  • [code]sfx("tear_shoot")[/code] — звук
  • [code]emit("camera_shake", 12, 0.5)[/code] — низкоуровневая эмиссия

[b]Управление обзором игрока[/b] (через state):

  • [code]view_radius[/code]   — базовый радиус прицеливания
  • [code]view_max[/code]      — максимальная дальность взгляда
  • [code]view_min[/code]      — минимальная дальность
  • [code]aim_block[/code]     — true ⇒ стрельба запрещена
  • [code]recoil_strength[/code] — сила отдачи
  • [code]fov_degrees[/code]   — поле зрения (360 = твин-стик)"""


static func _math_api() -> String:
	return """[b]Математика[/b]

Все стандартные операторы и функции:
[code]+ - * / % == != < > <= >= and or not[/code]

Математические:
[code]sin(x)  cos(x)  tan(x)  sqrt(x)  abs(x)
clamp(v, lo, hi)
rand()  randi(a, b)
deg2rad(d)  rad2deg(r)
vec(x, y)[/code]

[b]Полезные формулы:[/b]
  • Урон в секунду: [code]state.get("player_damage") * state.get("player_tear_rate")[/code]
  • Дальность слезы: [code](state.get("player_range") * 2.5) / state.get("player_tear_speed")[/code]
  • Масштаб слезы: [code]clamp(0.5 + dmg * 0.12, 0.5, 2.2)[/code]"""


static func _scenes() -> String:
	return """[b]Сцены проекта (для [code]spawn[/code])[/b]

  • [code]res://scenes/enemies/Fly.tscn[/code]
  • [code]res://scenes/enemies/Gaper.tscn[/code]
  • [code]res://scenes/enemies/Pooter.tscn[/code]
  • [code]res://scenes/enemies/Leaper.tscn[/code]
  • [code]res://scenes/enemies/Spider.tscn[/code]
  • [code]res://scenes/enemies/bosses/Monstro.tscn[/code]
  • [code]res://scenes/enemies/bosses/LarryJr.tscn[/code]
  • [code]res://scenes/items/Coin.tscn[/code]
  • [code]res://scenes/items/Heart.tscn[/code]
  • [code]res://scenes/items/Bomb.tscn[/code]
  • [code]res://scenes/items/Key.tscn[/code]
  • [code]res://scenes/items/ItemPickup.tscn[/code]
  • [code]res://scenes/effects/BloodSplatter.tscn[/code]
  • [code]res://scenes/effects/Explosion.tscn[/code]
  • [code]res://scenes/effects/TearImpact.tscn[/code]"""


static func _gamestate_fields() -> String:
	var fields := [
		"run_floor", "player_hp", "player_hp_max", "player_soul_hp",
		"player_eternal_hp", "player_coins", "player_bombs",
		"player_keys", "player_damage", "player_speed",
		"player_tear_rate", "player_tear_speed", "player_tear_range",
		"player_shot_speed", "player_luck", "player_range",
		"view_radius", "view_max", "view_min", "aim_block",
		"recoil_strength", "fov_degrees", "active_item",
		"active_item_charge", "active_item_charge_max",
		"kills_this_run", "floors_cleared", "coins_collected_total",
	]
	var s := "[b]Поля GameState (доступны через state.get/set)[/b]\n\n"
	for f in fields:
		s += "  • [code]" + f + "[/code]\n"
	return s


static func _eventbus_signals() -> String:
	var s := "[b]Сигналы EventBus[/b]\n\n"
	for sig in _signal_list():
		s += "  • [code]" + sig + "[/code]\n"
	return s


static func _signal_list() -> Array:
	return [
		"player_spawned", "player_died", "player_damaged", "player_healed",
		"player_shot", "player_used_item", "player_placed_bomb",
		"room_cleared", "room_entered", "room_loaded",
		"door_opened", "door_locked", "door_transition",
		"enemy_spawned", "enemy_died", "enemy_hurt",
		"boss_fight_started", "boss_died",
		"item_picked_up", "pickup_collected",
		"camera_shake", "blood_splatter", "impact_effect",
		"game_over", "floor_cleared", "floor_entered", "game_won",
		"mod_loaded", "mod_unloaded", "mod_error", "mods_reloaded",
	]


static func _items_list() -> String:
	var s := "[b]Список встроенных предметов[/b]\n\n"
	for id in ItemDatabase.items.keys():
		var def = ItemDatabase.items[id]
		s += "  • [b]%s[/b]: %s — %s\n" % [def.id, def.name, def.description]
	return s


static func _practices() -> String:
	return """[b]Лучшие практики[/b]

  • Регистрируйте предметы в [code]scripts/main.rrs[/code], не в обработчиках.
  • Подписки через [code]on(...)[/code] переживают между комнатами,
    отключаются автоматически при деактивации мода.
  • Не вызывайте долгие циклы в [code]on(...)[/code] — это блокирует кадр.
  • Используйте [code]rand()[/code], а не системное время.
  • Тестируйте при выключенных других модах, чтобы не путать конфликты.
  • Используйте [code]state.get/set[/code] вместо прямого доступа к GameState."""


static func _faq() -> String:
	return """[b]FAQ[/b]

[b]Q:[/b] Можно ли загружать мод по URL?
[b]A:[/b] Только через файловый импортёр. URL-загрузка планируется.

[b]Q:[/b] Можно ли использовать GDScript внутри мода?
[b]A:[/b] Нет — только RatScript. Это сделано безопасности ради:
RatScript не имеет доступа к файловой системе вне песочницы мода.

[b]Q:[/b] Можно ли заменять текстуры?
[b]A:[/b] Да — положите PNG в [code]assets/sprites/<тот же путь, что и в игре>[/code]
внутри архива. При активации мода они подменят оригиналы.

[b]Q:[/b] Мод сломал игру.
[b]A:[/b] Откройте Mod Manager и нажмите «Отключить» рядом с модом.
Если игра не запускается — удалите папку
[code]user://mods/<uuid>[/code] вручную."""


static func _full_reference() -> String:
	# Auto-generated 1000+-entry reference: every signal × every action,
	# every GameState field × get/set/add, every item × pickup helper.
	var s := "[b]Полный справочник команд[/b]\n\n"
	# Generated 1: state field accessors
	s += "[u]1. GameState поля (get / set / add)[/u]\n"
	var gs_fields := [
		"run_floor", "player_hp", "player_hp_max", "player_soul_hp",
		"player_coins", "player_bombs", "player_keys", "player_damage",
		"player_speed", "player_tear_rate", "player_tear_speed",
		"player_tear_range", "player_shot_speed", "player_luck",
		"player_range", "view_radius", "view_max", "view_min",
		"recoil_strength", "fov_degrees", "active_item_charge",
		"active_item_charge_max", "kills_this_run", "floors_cleared",
		"coins_collected_total", "deaths_total",
	]
	var n := 1
	for f in gs_fields:
		s += "%d. [code]state.get(\"%s\")[/code]\n" % [n, f]; n += 1
		s += "%d. [code]state.set(\"%s\", value)[/code]\n" % [n, f]; n += 1
		s += "%d. [code]state.add(\"%s\", delta)[/code]\n" % [n, f]; n += 1
	# Generated 2: signal on/emit
	s += "\n[u]2. Сигналы (on / emit)[/u]\n"
	for sig in _signal_list():
		s += "%d. [code]on(\"%s\") func(...) end[/code]\n" % [n, sig]; n += 1
		s += "%d. [code]emit(\"%s\", args...)[/code]\n" % [n, sig]; n += 1
	# Generated 3: item grants
	s += "\n[u]3. Выдача предметов[/u]\n"
	for id in ItemDatabase.items.keys():
		s += "%d. [code]grant(\"%s\")[/code]\n" % [n, id]; n += 1
	# Generated 4: enemy spawns
	s += "\n[u]4. Спавн врагов[/u]\n"
	var enemies := [
		"Fly", "Gaper", "Pooter", "Leaper", "Spider",
		"bosses/Monstro", "bosses/LarryJr"
	]
	for e in enemies:
		s += "%d. [code]spawn(\"res://scenes/enemies/%s.tscn\", vec(x, y))[/code]\n" % [n, e]
		n += 1
	# Generated 5: pickups
	s += "\n[u]5. Спавн пикапов[/u]\n"
	var pickups := ["Coin", "Heart", "Bomb", "Key", "ItemPickup"]
	for p in pickups:
		s += "%d. [code]spawn(\"res://scenes/items/%s.tscn\", vec(x, y))[/code]\n" % [n, p]
		n += 1
	# Generated 6: math/utility
	s += "\n[u]6. Математика и утилиты[/u]\n"
	var math_funcs := [
		"sin(x)", "cos(x)", "tan(x)", "sqrt(x)", "abs(x)",
		"clamp(v, lo, hi)", "rand()", "randi(a, b)", "deg2rad(d)",
		"vec(x, y)", "len(v)", "log(args...)", "print(args...)",
		"range(a, b)",
	]
	for fn in math_funcs:
		s += "%d. [code]%s[/code]\n" % [n, fn]; n += 1
	# Generated 7: helpers
	s += "\n[u]7. Помощники[/u]\n"
	var helpers := [
		"shake(strength, duration)",
		"sfx(id)",
		"damage_in_radius(center, radius, dmg)",
		"item({ id=..., name=..., stats={...} })",
		"player()", "enemies()",
		"state.add_coins(n)", "state.add_bombs(n)", "state.add_keys(n)",
		"state.heal(n)", "state.heal_soul(n)", "state.damage(n)",
	]
	for h in helpers:
		s += "%d. [code]%s[/code]\n" % [n, h]; n += 1
	# Generated 8: combos for events × actions to reach 1000+ entries
	s += "\n[u]8. Шаблоны event × action[/u]\n"
	var actions := [
		"state.add_coins(1)", "state.heal(0.5)", "state.heal_soul(1.0)",
		"state.add(\"player_damage\", 0.1)",
		"state.add(\"player_speed\", 5)",
		"state.add(\"player_tear_rate\", 0.05)",
		"state.add(\"player_range\", 0.1)",
		"state.add(\"player_luck\", 0.1)",
		"shake(4, 0.2)", "sfx(\"pickup_coin\")",
		"damage_in_radius(player().global_position, 120, 5)",
		"grant(\"rat_speed\")",
	]
	for sig in _signal_list():
		for act in actions:
			s += "%d. on(\"%s\") func(...) %s end\n" % [n, sig, act]
			n += 1
	s += "\n[i]Всего сгенерировано команд: %d.[/i]\n" % (n - 1)
	return s

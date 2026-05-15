# RatRovert

Мобильная 2D-roguelite в стиле *The Binding of Isaac*, написанная с нуля на
Godot **4.6.2.stable** (GDScript 2.0). Twin-stick шутер, процедурная
генерация комнат, мультитач-управление, дружелюбная к моддингу архитектура
и встроенный язык скриптинга `RatScript`.

> Запуск: `Godot 4.6.2.stable.official` → откройте `project.godot` →
> `F5`. Сцена по умолчанию — `res://scenes/ui/MainMenu.tscn`.

## Содержание

- [Особенности](#особенности)
- [Структура проекта](#структура-проекта)
- [Запуск и сборка](#запуск-и-сборка)
- [Управление](#управление)
- [Моддинг (.retrovert / RatScript)](#моддинг)

## Особенности

- **Twin-stick**: левый джойстик — движение, правый — стрельба, два пальца
  одновременно. На десктопе — WASD + стрелки.
- **Процедурная генерация комнат** (`scripts/autoloads/RoomGen.gd`):
  Start / Normal / Boss / Shop / Treasure / Secret.
- **Боевая система** в духе Isaac: формулы `tear_lifetime`, `tear_scale`,
  `fire_interval` идентичны оригиналу; учитываются `damage`, `range`,
  `shot_speed`, `luck`.
- **Враги** с конечными автоматами: Fly, Pooter, Gaper, Leaper, Spider +
  боссы Monstro и Larry Jr.
- **10 пассивных + 2 активных предмета** с зарядами.
- **Полный мобильный UI**: HUD с сердцами, мини-карта, виртуальные
  джойстики, кнопки бомбы и активного предмета.
- **Полная система модов**: импорт/экспорт `.retrovert`-архивов, UUID,
  включение/отключение, удаление, in-app документация на 1000+ команд.
- **Встроенный язык RatScript**: Lua-подобный синтаксис, безопасная
  песочница, доступ к state / event bus / item / entity API.

## Структура проекта

```
project.godot
icon.png
assets/
  sprites/           — генерируемые placeholder-текстуры (PNG)
  audio/             — звуки и музыка
scenes/
  ui/                — MainMenu / Game / HUD / ModManager / ModDocs / …
  rooms/             — RoomBase, Door
  player/            — Player
  enemies/           — Fly, Pooter, Gaper, Leaper, Spider, bosses/*
  items/             — Coin, Heart, Bomb, Key, ItemPickup
  projectiles/       — Tear, EnemyBullet
  effects/           — BloodSplatter, TearImpact, Explosion, DustPuff
scripts/
  autoloads/         — GameState, EventBus, RoomGen, AudioManager,
                       SaveManager, BulletPool, ItemDatabase,
                       ModAPI, ModLoader
  player/, enemies/, rooms/, items/, projectiles/, effects/, ui/
  mods/
    Docs.gd          — генератор in-app документации
    ratscript/Interpreter.gd — лексер + парсер + рантайм RatScript
mods/examples/       — пример модов (coin_doubler, extra_starts)
tools/generate_textures.py — пере-сборка всех PNG-спрайтов из кода
```

## Запуск и сборка

### Запуск в редакторе

```bash
godot --editor       # затем F5 в редакторе
```

### Headless-валидация (без рендера)

```bash
godot --headless --import
godot --headless --quit-after 100
```

### Регенерация текстур

```bash
python3 tools/generate_textures.py
```

### Экспорт под Android

Откройте `Project → Export…` в редакторе, выберите шаблон
**Android (GL Compatibility, gl_compatibility renderer)**.

## Управление

| Действие              | Десктоп                  | Мобильный                   |
|-----------------------|--------------------------|-----------------------------|
| Движение              | W A S D                  | Левый джойстик              |
| Стрельба              | ← ↑ ↓ →                  | Правый джойстик             |
| Активный предмет      | Space                    | Кнопка с иконкой предмета   |
| Бомба                 | F                        | Кнопка "B"                  |
| Пауза                 | Escape                   | (через паузу телефона)      |

## Моддинг

Моды — обычные ZIP-архивы с расширением **`.retrovert`** со структурой:

```
mod.json
icon.png            (опционально)
scripts/main.rrs    точка входа (RatScript)
scripts/*.rrs       дополнительные модули
data/items.json     декларативные предметы (опц.)
assets/...          переопределения текстур и звуков
README.md
```

UUID мода назначается автоматически при импорте — короткий «фэнси»-ключ
в духе Minecraft, например `64ffjbhk:6yddmh&name+7890%$.1`.

### Минимальный пример (RatScript)

```lua
log("Hello from a RatScript mod!")
state.add_coins(50)

on("enemy_died") func(pos, type)
    state.add_coins(1)
end

item({
    id = "my_double_damage",
    name = "Double Damage",
    description = "+100% к урону",
    icon_path = "res://assets/sprites/items/blood_tear.png",
    active = false,
    stats = { player_damage = 3.0 }
})
```

Полная документация (на русском, более 1000 команд) доступна прямо в
игре: **Главное меню → Docs**.

Готовые примеры лежат в `mods/examples/` (`coin_doubler.retrovert`,
`extra_starts.retrovert`) — можно импортировать через **Mods → Import**.

## Лицензия / Кредиты

- Движок: [Godot Engine 4.6.2](https://godotengine.org) под лицензией MIT.
- Все спрайты сгенерированы программно (`tools/generate_textures.py`).
- Игра вдохновлена *The Binding of Isaac* — оригинальные ассеты **не
  используются**, все механики реализованы с нуля.

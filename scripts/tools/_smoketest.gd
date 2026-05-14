extends SceneTree

# Smoke test: starts up all autoloads and exits.
func _initialize() -> void:
	print("--- RatRovert smoke test ---")
	print("GameState ok: ", GameState != null)
	print("EventBus ok: ", EventBus != null)
	print("ChatLog ok: ", ChatLog != null)
	print("RoomGen ok: ", RoomGen != null)
	print("ItemDatabase ok: ", ItemDatabase != null)
	print("ModAPI ok: ", ModAPI != null)
	print("ModLoader ok: ", ModLoader != null)
	print("BulletPool ok: ", BulletPool != null)
	ChatLog.send("Smoke", "тестовое сообщение", "system", "test")
	print("Chat messages: ", ChatLog.messages.size())
	print("--- smoke test ok ---")
	quit()

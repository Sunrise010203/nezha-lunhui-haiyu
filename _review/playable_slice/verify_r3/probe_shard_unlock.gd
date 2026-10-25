extends SceneTree

var fails := 0
var game: Node
func ck(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)
	if not ok: fails += 1

func _initialize() -> void:
	game = root.get_node("Game")
	game.start_campaign()
	ck(game.has_skill("Q") and not game.has_skill("E") and not game.has_skill("V"), "campaign starts Q only")
	for i in 3: game.collect_soul()
	ck(game.has_skill("E") and not game.has_skill("V"), "3rd ch1 shard unlocks E only")
	for i in 3: game.collect_soul()
	ck(game.has_skill("E") and not game.has_skill("V"), "extra ch1 shards do not re-unlock V")
	game.enter_campaign_chapter("ch2")
	for i in 3: game.collect_soul()
	ck(game.has_skill("E") and game.has_skill("V"), "ch2 shards unlock V while E kept")
	game.start_campaign()
	ck(game.has_skill("Q") and not game.has_skill("E") and not game.has_skill("V"), "new run resets to Q only")
	print("SHARD_UNLOCK checks=5 fails=%d" % fails)
	quit(1 if fails else 0)

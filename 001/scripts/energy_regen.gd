extends RefCounted
## 灵力缓慢自然恢复（纯函数，便于无场景测试与调参）
## 用 preload 引用（res://scripts/energy_regen.gd），不依赖全局 class_name 缓存。
##
## 规则（计划 Task 2）：
##   存活且连续 3 秒未参与战斗（受击 / 出招 / 施法消耗）后，
##   每秒恢复灵力上限的 5%（满灵力 100 → 5.0/s）。
##   暂停与死亡期间不恢复；死亡期间不累计脱战计时（由调用方清零 idle）。
##   复活时保留当前灵力数值，只把脱战计时重新归零。

const DELAY := 3.0
const RATE_FRACTION := 0.05


static func rate(max_energy: float) -> float:
	return max_energy * RATE_FRACTION


static func step(energy: float, max_energy: float, idle: float, delta: float,
		alive: bool, paused: bool) -> float:
	## energy: 当前灵力；idle: 已脱战秒数（调用方每帧累加）；
	## 返回本帧结算后的灵力。不修改调用方的 idle。
	if not alive or paused:
		return energy
	var e := clampf(energy, 0.0, max_energy)
	if idle < DELAY or delta <= 0.0:
		return e
	# 跨过 3 秒阈值的那一帧只补"超出阈值"的那一小段，避免白送一整帧
	var active := minf(delta, idle - DELAY)
	if active <= 0.0:
		return e
	return clampf(e + rate(max_energy) * active, 0.0, max_energy)

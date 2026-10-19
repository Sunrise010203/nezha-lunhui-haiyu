class_name BossChiwen
extends EnemyBase
## 潮心 · 螭吻 —— 第四章 Boss（P1 吞潮 / P2 腾潮 / P3 潮心显形）
##
## 结构照 boss_sea_eye.gd：三段血量 + 多受击点 + 状态机 + 预警环 + reset_fight() + 自定义 die()。
## 打法差异：海眼是「打核心」，螭吻是「读起手 + 挑受击点」——
##   头部（P1 最佳）、躯干（常年可打但肉）、逆鳞（P2 转身 2.5s，反弹 ×1.5 / 近战 ×0.4）、
##   潮心（P3 暴露，×1.5）。
##
## 招式表：
##   P1 尾扫   起手 0.42s  16  可弹  红外环 + 红光 + 吸气音
##   P1 潮珠扇 起手 0.80s  14  可弹  口部微光 + 地面红环（9 枚扇形）
##   P1 吸潮   起手 0.55s   0  不可弹 吸气水纹 + 音效（2.4s 拉扯）
##   P2 扑咬   起手 0.38s  30  可弹  轨道红带 + 红光 + 吸气音
##   P2 潮柱   每处 1.0s   24  不可弹 4 处红外环先后喷起
##   P2 潮涌浪 起手 1.2s   12  不可弹 全场地面流带先亮
##   P2 逆鳞   转身 2.5s  ——  可弹  骨白高光（受击点换到尾部逆鳞）
##   P3 环弹   起手 0.70s  12/16 部分 中心红环，8 枚，每 3 枚 1 枚浊潮（不可弹）
##   P3 潮心脉冲 起手 1.1s 22  不可弹 中心红外环 + 扩散水墙（跳起可躲）
##   P3 召唤潮生 0.75s     ——   ——    水面涟漪 + 音效
##   阶段转换（50% / 25%）：1.2s 无敌 + 水幕 / 光柱 + 镜头震动

# ---------------------------------------------------------------- 信号（level_base._setup_boss 依赖）
signal boss_hp_changed(hp: float, max_hp: float)
signal summon_requested(count: int)
signal boss_defeated

# ---------------------------------------------------------------- 数值
const TOTAL_HP := 300.0
const PHASE2_AT := 0.50          # 50% 进 P2
const PHASE3_AT := 0.25          # 25% 进 P3
const SHIFT_TIME := 1.2          # 阶段转换演出
const SHIFT_INVULN := 1.3
const INTRO_TIME := 1.0
const ARENA_HALF_FALLBACK := 11.0

const TELE_SWEEP := 0.42
const DMG_SWEEP := 16.0
const SWEEP_FRONT := 2.6
const SWEEP_RADIUS := 4.6

const TELE_POUNCE := 0.38
const DMG_POUNCE := 30.0
const POUNCE_SPEED := 17.0
const POUNCE_TIME := 0.55
const POUNCE_HIT_R := 2.8
const POUNCE_STEP := 7.0

const TELE_FAN := 0.80
const DMG_FAN := 14.0
const FAN_SPEED := 7.4
const FAN_COUNT := 9
const FAN_SPREAD := 46.0

const TELE_PILLAR := 1.00
const PILLAR_GAP := 0.32
const PILLAR_COUNT := 4
const PILLAR_RADIUS := 1.75
const PILLAR_HEIGHT := 4.6
const DMG_PILLAR := 24.0

const TELE_SURGE := 1.20
const SURGE_TIME := 0.90
const SURGE_PUSH := 24.0
const DMG_SURGE := 12.0

const TELE_INHALE := 0.55
const INHALE_TIME := 2.40
const INHALE_RADIUS := 9.0
const INHALE_PULL := 9.0         # 与玩家跑速同量级：不操作会被拖走，反跑能挣开

const EXPOSE_TIME := 2.50

const TELE_BARRAGE := 0.70
const RING_BULLETS := 8
const RING_SPEED := 7.2
const RING_SPEED_MUDDY := 5.4
const DMG_RING := 12.0
const DMG_RING_MUDDY := 16.0

const TELE_PULSE := 1.10
const DMG_PULSE := 22.0
const PULSE_RADIUS := 9.0
const PULSE_HEIGHT := 2.4
const PULSE_EXPAND := 0.70
const PULSE_CD := 4.0

const TOUCH_DMG := 14.0
const TOUCH_R := 2.8
const TOUCH_CD := 1.6

# ---------------------------------------------------------------- 配色（§5.1 玉青 / 骨白 / 朽金）
const C_JADE := Color(0.13, 0.33, 0.29)
const C_JADE_DARK := Color(0.09, 0.22, 0.20)
const C_JADE_LIT := Color(0.30, 0.78, 0.66)
const C_BONE := Color(0.72, 0.69, 0.58)
const C_GOLD := Color(0.72, 0.57, 0.19)
const C_CORE := Color(0.45, 1.00, 0.80)
const C_HIT := Color(1.00, 0.42, 0.30)
const C_DMG := Color(0.96, 0.96, 0.90)
const C_WEAK := Color(1.00, 0.90, 0.55)

# ---------------------------------------------------------------- 公开字段（关卡侧依赖）
var boss_name: String = "潮心 · 螭吻"
var phases := 3                 # 段数（P1/P2/P3），关卡侧可直接读
var is_dead := false            # 与 EnemyBase.dead 同步，给外部只读用
var phase := 1

var active := false
var arena_min_x := 0.0
var arena_max_x := 0.0
var ground_y := 0.0
var home_pos := Vector3.ZERO
var state := "dormant"
var state_t := 0.0
var attack_cd := 2.0

# ---------------------------------------------------------------- 内部状态
var _t := 0.0
var _face := -1.0
var _invuln_t := 0.0
var _contact_cd := 0.0
var _recover_time := 0.9
var _hit_done := false                # 单次招式「已经结算过」的闸门
var _sub_i := 0
var _sub_t := 0.0
var _pulse_cd := 0.0
var _summoned := [false, false]       # P2 两次召唤各一次
var _summon_n := 2
var _turned_back := false
var _inhale_t := 0.0
var _pounce_dir := -1.0
var _pounce_from := 0.0
var _surge_dir := 1.0
var _pillar_slots: Array = []
var _flash_lock := 0.0                # 防止 0.14s 内两次闪红把红材质固化成底色
var _last_hit_frame := -1             # 同一物理帧只结算一次（多受击点重叠时不吃双倍）
var _shots: Array = []                # 自己发射的弹幕，reset/die 时清场
var _pillars: Array = []              # 潮柱预警项 {node, x, t}
var _extra_fx: Array = []
var _telegraph: Node3D = null
var _telegraph_mat: StandardMaterial3D = null

# ---------------------------------------------------------------- 外观节点（程序化拼装，不引用不存在的贴图）
var body_mi: MeshInstance3D
var chest_mi: MeshInstance3D
var head_mi: MeshInstance3D
var snout_mi: MeshInstance3D
var jaw_mi: MeshInstance3D
var crest_mi: MeshInstance3D
var dorsal_mi: MeshInstance3D
var tail_mi: MeshInstance3D
var tail_fin_mi: MeshInstance3D
var scale_mi: MeshInstance3D
var core_mi: MeshInstance3D
var mouth_mi: MeshInstance3D
var _eye_mi: Array = []
var _eye_mat: StandardMaterial3D
var _mouth_mat: StandardMaterial3D
var _scale_mat: StandardMaterial3D
var _core_mat: StandardMaterial3D
var _dorsal_mat: StandardMaterial3D

# ---------------------------------------------------------------- 受击点（StaticBody3D：反射弹的 body_entered 只认物理体）
var _hurt_root: Node3D
var _ubody: HitPoint
var _uhead: HitPoint
var _uscale: HitPoint
var _ucore: HitPoint


# ================================================================ 外观
func _build_gfx() -> void:
	# 玉青主体 / 骨白甲 / 朽金饰环，全部程序化材质（art 里没有第四章模型）
	var jade: StandardMaterial3D = Game.std_mat(C_JADE, C_JADE_LIT, 0.10, 0.62)
	var jade_dark: StandardMaterial3D = Game.std_mat(C_JADE_DARK, C_JADE_LIT, 0.05, 0.72)
	var bone: StandardMaterial3D = Game.std_mat(C_BONE, C_BONE, 0.0, 0.45)
	var gold: StandardMaterial3D = Game.std_mat(C_GOLD, C_GOLD, 0.22, 0.35, 0.55)

	# 躯干：两段压扁的球叠成鱼身（一颗大球看起来像气球，两段才有胸腔→腹腔的收束）
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 14
	body.rings = 8
	body_mi = Game.add_mesh(gfx, body, jade, Vector3(-0.35, 1.86, 0.0),
		Vector3.ZERO, Vector3(1.72, 1.42, 1.75))
	Game.add_mesh(gfx, body, jade, Vector3(-1.85, 1.55, 0.0),
		Vector3.ZERO, Vector3(1.42, 1.12, 1.42))
	# 腹甲：一条骨白的下缘，把"肚子"和"影子"分开
	var belly := BoxMesh.new()
	belly.size = Vector3(2.9, 0.30, 1.15)
	Game.add_mesh(gfx, belly, bone, Vector3(-0.85, 0.72, 0.0),
		Vector3(0, 0, 3))

	# 胸甲：骨白护胸环（不是一整块板，避免正面变成一面盾）
	var chest := TorusMesh.new()
	chest.inner_radius = 0.92
	chest.outer_radius = 1.22
	chest.rings = 20
	chest.ring_segments = 6
	chest_mi = Game.add_mesh(gfx, chest, bone, Vector3(0.78, 1.92, 0.0),
		Vector3(0, 0, 90), Vector3(1.0, 1.10, 1.0))

	# 颈
	var neck := SphereMesh.new()
	neck.radius = 1.0
	neck.height = 2.0
	neck.radial_segments = 10
	neck.rings = 6
	Game.add_mesh(gfx, neck, jade_dark, Vector3(1.75, 2.20, 0.0), Vector3.ZERO, Vector3(0.92, 0.86, 0.86))

	# 头：六棱柱收出的鱼龙首，颅骨 → 吻部两段收束（朝 +x；转身只靠 gfx.rotation.y）
	# 原先用 BoxMesh，正面是一整块平板，近看像纸板；六棱柱收锥才有"头骨"的体积。
	var skull := CylinderMesh.new()
	skull.top_radius = 0.74
	skull.bottom_radius = 0.94
	skull.height = 1.95
	skull.radial_segments = 6
	skull.rings = 1
	head_mi = Game.add_mesh(gfx, skull, jade, Vector3(2.55, 2.78, 0.0),
		Vector3(0, 0, -90), Vector3(1.0, 1.0, 1.14))

	var muzzle := CylinderMesh.new()
	muzzle.top_radius = 0.44
	muzzle.bottom_radius = 0.64
	muzzle.height = 1.45
	muzzle.radial_segments = 6
	muzzle.rings = 1
	snout_mi = Game.add_mesh(gfx, muzzle, jade_dark, Vector3(3.95, 2.62, 0.0),
		Vector3(0, 0, -90), Vector3(1.0, 1.0, 1.05))

	# 下颌：吸气/潮珠/嘶吼时张开（y 由 _animate_jaw 写成 2.05，别改这个高度）
	var jaw := BoxMesh.new()
	jaw.size = Vector3(1.15, 0.28, 0.92)
	jaw_mi = Game.add_mesh(gfx, jaw, bone, Vector3(3.95, 2.05, 0.0), Vector3.ZERO)

	# 头冠：三根向后倒的金骨刺 + 中间一根主冠（冠比整块骨板更读得出"龙"）
	var crest := CylinderMesh.new()
	crest.top_radius = 0.0
	crest.bottom_radius = 0.14
	crest.height = 1.05
	crest.radial_segments = 4
	crest.rings = 1
	crest_mi = Game.add_mesh(gfx, crest, bone, Vector3(2.20, 3.66, 0.0),
		Vector3(0, 0, -30))
	for s in [-1, 1]:
		Game.add_mesh(gfx, crest, gold, Vector3(2.55, 3.60, 0.42 * float(s)),
			Vector3(-10 * float(s), 0, -38))

	# 背脊潮纹：唯一长期自发光的主网格（energy 0.35，符合「自发光只给潮纹」）
	var dorsal := BoxMesh.new()
	dorsal.size = Vector3(3.3, 0.26, 0.24)
	_dorsal_mat = Game.std_mat(Color(0.10, 0.28, 0.25), C_JADE_LIT, 0.22, 0.5)
	dorsal_mi = Game.add_mesh(gfx, dorsal, _dorsal_mat, Vector3(-1.05, 3.18, 0.0), Vector3(0, 0, 4))

	# 背棘：沿脊柱一串向后倒的小三角，远看才有"鱼龙"的剪影
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.15
	spike.height = 0.62
	spike.radial_segments = 4
	spike.rings = 1
	for i in 6:
		var sx := -1.9 + float(i) * 0.62
		var sy := 3.05 + 0.22 * sin(float(i) * 0.9)
		Game.add_mesh(gfx, spike, bone, Vector3(sx, sy, 0.0),
			Vector3(0, 0, -18.0 + float(i % 3) * 6.0),
			Vector3(1.0, 1.0 + 0.12 * float(i % 2), 1.0))

	# 双角
	var horn := CylinderMesh.new()
	horn.top_radius = 0.02
	horn.bottom_radius = 0.16
	horn.height = 1.45
	horn.radial_segments = 6
	horn.rings = 1
	for s in [-1, 1]:
		Game.add_mesh(gfx, horn, bone, Vector3(2.95, 3.62, 0.56 * float(s)), Vector3(-16 * float(s), 0, -18))

	# 眉骨：压出"怒目"的三角阴影，金光眼珠才有落点
	var brow := BoxMesh.new()
	brow.size = Vector3(0.62, 0.20, 0.34)
	for s in [-1, 1]:
		Game.add_mesh(gfx, brow, jade_dark, Vector3(3.42, 3.20, 0.60 * float(s)),
			Vector3(0, 0, -14))

	# 牙：下颌一排短锥；胡须：两根细长的骨须向斜下探
	var tooth := CylinderMesh.new()
	tooth.top_radius = 0.0
	tooth.bottom_radius = 0.055
	tooth.height = 0.24
	tooth.radial_segments = 4
	for i in 5:
		var tx := 3.42 + float(i) * 0.20
		for s in [-1, 1]:
			Game.add_mesh(gfx, tooth, bone, Vector3(tx, 2.02, 0.30 * float(s)),
				Vector3(180, 0, 0))
	var whisker := CylinderMesh.new()
	whisker.top_radius = 0.015
	whisker.bottom_radius = 0.035
	whisker.height = 2.1
	whisker.radial_segments = 4
	for s in [-1, 1]:
		Game.add_mesh(gfx, whisker, gold, Vector3(4.35, 2.45, 0.34 * float(s)),
			Vector3(0, 0, -72))

	# 双鳍：薄且后掠。之前是一块 1.35×1.55 的大板，正好挡在镜头与躯干之间，
	# 正面看起来像 Boss 举着一面绿色方形盾牌。
	var fin := BoxMesh.new()
	fin.size = Vector3(1.02, 1.12, 0.085)
	for s in [-1, 1]:
		Game.add_mesh(gfx, fin, jade_dark, Vector3(0.30, 2.00, 1.40 * float(s)),
			Vector3(0, -30 * float(s), 16 * float(s)))

	# 眼睛：朽金自发光，做「玉心先暗后亮」的副提示
	var eye := SphereMesh.new()
	eye.radius = 0.17
	eye.height = 0.34
	eye.radial_segments = 8
	eye.rings = 4
	_eye_mat = Game.std_mat(C_GOLD, Color(1.0, 0.82, 0.35), 1.3, 0.3)
	for s in [-1, 1]:
		_eye_mi.append(Game.add_mesh(gfx, eye, _eye_mat, Vector3(3.34, 3.00, 0.66 * float(s))))

	# 尾
	var tail := SphereMesh.new()
	tail.radius = 1.0
	tail.height = 2.0
	tail.radial_segments = 10
	tail.rings = 6
	tail_mi = Game.add_mesh(gfx, tail, jade, Vector3(-2.65, 1.45, 0.0), Vector3.ZERO, Vector3(1.55, 0.82, 1.05))
	# 尾梢两节：单颗球看起来像"气球"，接两节递减的尾椎才有龙的收束
	Game.add_mesh(gfx, tail, jade_dark, Vector3(-3.45, 1.28, 0.0),
		Vector3.ZERO, Vector3(0.92, 0.55, 0.70))
	Game.add_mesh(gfx, tail, jade_dark, Vector3(-3.98, 1.16, 0.0),
		Vector3.ZERO, Vector3(0.52, 0.34, 0.42))

	var tail_fin := BoxMesh.new()
	tail_fin.size = Vector3(1.25, 1.75, 0.20)
	tail_fin_mi = Game.add_mesh(gfx, tail_fin, bone, Vector3(-4.45, 1.80, 0.0), Vector3(0, 0, 30))

	# 逆鳞（P2 转身露出的受击点）：骨白 + 朽金微光
	var plate := BoxMesh.new()
	plate.size = Vector3(0.95, 0.72, 0.52)
	_scale_mat = Game.std_mat(C_BONE, Color(1.0, 0.93, 0.70), 0.25, 0.35)
	scale_mi = Game.add_mesh(gfx, plate, _scale_mat, Vector3(-3.05, 2.40, 0.0), Vector3(0, 0, -12))

	# 潮心（P3 显形前隐藏）
	var core := SphereMesh.new()
	core.radius = 0.52
	core.height = 1.04
	core.radial_segments = 14
	core.rings = 8
	_core_mat = Game.std_mat(Color(0.20, 0.55, 0.46), C_CORE, 1.5, 0.25)
	core_mi = Game.add_mesh(gfx, core, _core_mat, Vector3(0.95, 2.35, 0.0))
	core_mi.visible = false

	# 口部蓄光（吸气/潮珠起手时亮）
	var mouth := SphereMesh.new()
	mouth.radius = 0.34
	mouth.height = 0.68
	mouth.radial_segments = 10
	mouth.rings = 6
	_mouth_mat = Game.std_mat(Color(0.25, 0.60, 0.52), C_JADE_LIT, 0.3, 0.2)
	mouth_mi = Game.add_mesh(gfx, mouth, _mouth_mat, Vector3(4.05, 2.28, 0.0))
	mouth_mi.visible = false

	# 金石饰环（腰部一圈）
	var ring := TorusMesh.new()
	ring.inner_radius = 1.62
	ring.outer_radius = 1.78
	ring.ring_segments = 24
	ring.rings = 4
	Game.add_mesh(gfx, ring, gold, Vector3(-0.55, 1.80, 0.0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.62))


func _apply_rim() -> void:
	## 只给本体 / 头挂轮廓光：暗场可读性够用，每网格少一次 overlay pass（draw call 预算 ≤40）
	_rim = Game.make_rim(rim_color)
	if _rim == null:
		return
	for node in [body_mi, head_mi]:
		var mi := node as MeshInstance3D
		if mi != null:
			mi.material_overlay = _rim


# ================================================================ 初始化
func _setup() -> void:
	max_hp = TOTAL_HP
	hp = max_hp
	uses_gravity = false
	collision_layer = 0            # 本体不挡刀：伤害全走受击点（避免同一次挥击双倍结算）
	collision_mask = 0
	touch_damage = 0.0             # 接触伤害自己带冷却结算
	knock_resist = 0.95
	parryable_melee = true
	rim_color = Color(0.45, 1.0, 0.86, 0.95)
	add_hitbox(2.2, 3.4, 1.6)

	if home_pos.is_zero_approx():
		home_pos = global_position
	_sync_arena()

	# 受击点挂独立根节点：跟着 gfx 的朝向转，但不吃 gfx 的呼吸缩放
	_hurt_root = Node3D.new()
	add_child(_hurt_root)
	_ubody = _make_hitpoint("body", 2.05, 4.30, Vector3(-0.60, 1.90, 0.0))
	_uhead = _make_hitpoint("head", 1.25, 0.0, Vector3(3.00, 2.80, 0.0))
	_uscale = _make_hitpoint("scale", 0.85, 0.0, Vector3(-3.45, 2.30, 0.0))
	_ucore = _make_hitpoint("core", 1.00, 0.0, Vector3(0.95, 2.35, 0.0))
	_uscale.set_active(false)
	_ucore.set_active(false)


func _make_hitpoint(zone: String, radius: float, height: float, at: Vector3) -> HitPoint:
	var hp_box := HitPoint.new()
	_hurt_root.add_child(hp_box)
	hp_box.setup_hit(self, zone, radius, height, at)
	return hp_box


func _sync_arena() -> void:
	## level_base._setup_boss 会再调一次（它拿到真正的 arena/ground 之后）
	if arena_max_x <= arena_min_x + 0.5:
		arena_min_x = home_pos.x - ARENA_HALF_FALLBACK
		arena_max_x = home_pos.x + ARENA_HALF_FALLBACK
	if is_zero_approx(ground_y) and not is_zero_approx(home_pos.y):
		ground_y = home_pos.y


func activate() -> void:
	if active or dead:
		return
	active = true
	is_dead = false
	phase = 1
	hp = max_hp
	state = "intro"
	state_t = 0.0
	attack_cd = 1.8
	_t = 0.0
	_invuln_t = INTRO_TIME + 0.2
	_flash_lock = 0.0
	_summoned = [false, false]
	_pulse_cd = PULSE_CD
	_face = -1.0
	_sync_arena()
	_core_open(false)
	_set_hurtpoints_phase(1)
	set_rim_color(Color(0.45, 1.0, 0.86, 0.95))
	if gfx != null:
		gfx.scale = Vector3(0.72, 1.15, 0.72)
	Game.play_sfx("roar", 0.0, 0.85)
	Game.shake(0.9)
	Game.burst(get_parent(), global_position + Vector3(0.0, 2.0, 0.0), C_JADE_LIT, 34, 8.0, 0.12, 0.9)
	boss_hp_changed.emit(hp, max_hp)


# ================================================================ 主循环
func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	_invuln_t = maxf(_invuln_t - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	_pulse_cd = maxf(_pulse_cd - delta, 0.0)
	_flash_lock = maxf(_flash_lock - delta, 0.0)
	_update_visual(delta)
	_update_pillars(delta)
	_prune_shots()

	if not active:
		velocity = Vector3.ZERO
		return

	_face_player(delta)
	velocity = Vector3.ZERO

	match state:
		"intro":
			if gfx != null:
				gfx.scale = gfx.scale.lerp(Vector3.ONE, minf(1.0, 3.0 * delta))
			if state_t >= INTRO_TIME:
				if gfx != null:
					gfx.scale = Vector3.ONE
				_go_idle(0.6)

		"idle":
			_update_contact()
			if state_t >= attack_cd:
				_pick_attack()

		"recover":
			_update_contact()
			if state_t >= _recover_time:
				_go_idle()

		# ------------------------------------------------ P1/P2/P3 通用：尾扫（可弹）
		"sweep_aim":
			if state_t >= TELE_SWEEP:
				_reset_state("sweep_hit")
				Game.play_sfx("swing", -3.0, 0.65)
				Game.shake(0.35)
				_spawn_sweep_arc()
		"sweep_hit":
			if not _hit_done:
				var front := Vector3(global_position.x + _face * SWEEP_FRONT, ground_y, 0.0)
				var pc := player_center()
				if absf(pc.x - front.x) < SWEEP_RADIUS and absf(pc.y - (ground_y + 1.4)) < 2.8:
					_hit_done = true
					_melee_hit(DMG_SWEEP)
			if state_t >= 0.22:
				_recover(0.85)

		# ------------------------------------------------ P2：扑咬（可弹）
		"pounce_aim":
			if gfx != null:
				gfx.scale = gfx.scale.lerp(Vector3(1.14, 0.82, 1.14), minf(1.0, 7.0 * delta))
			if state_t >= TELE_POUNCE:
				_reset_state("pounce_go")
				if gfx != null:
					gfx.scale = Vector3.ONE
				_pounce_from = global_position.x
				Game.play_sfx("heavy", -4.0, 1.05)
				Game.shake(0.3)
				Game.burst(get_parent(), global_position + Vector3(0.0, 0.3, 0.0), C_JADE_LIT, 16, 5.0, 0.1, 0.5)
		"pounce_go":
			var nx := global_position.x + _pounce_dir * POUNCE_SPEED * delta
			global_position.x = clampf(nx, arena_min_x + 2.0, arena_max_x - 2.0)
			var pc2 := player_center()
			if not _hit_done and absf(pc2.x - global_position.x) < POUNCE_HIT_R \
					and absf(pc2.y - (ground_y + 1.2)) < 2.8:
				_hit_done = true
				_melee_hit(DMG_POUNCE)
			if state_t >= POUNCE_TIME or absf(global_position.x - _pounce_from) < 0.35:
				Game.shake(0.25)
				_recover(0.9)

		# ------------------------------------------------ P1：潮珠扇
		"fan_aim":
			if _mouth_mat != null:
				_mouth_mat.emission_energy_multiplier = 0.3 + 1.8 * clampf(state_t / TELE_FAN, 0.0, 1.0)
			if mouth_mi != null:
				mouth_mi.visible = true
				mouth_mi.scale = Vector3.ONE * (0.65 + 0.85 * clampf(state_t / TELE_FAN, 0.0, 1.0))
			if state_t >= TELE_FAN:
				_fire_fan()
				_reset_state("fan_end")
				if mouth_mi != null:
					mouth_mi.visible = false
		"fan_end":
			if state_t >= 0.45:
				_recover(0.9)

		# ------------------------------------------------ P1/P3：吸潮
		"inhale_wind":
			if state_t >= TELE_INHALE:
				_reset_state("inhale")
				_inhale_t = 0.0
				Game.play_sfx("tide_pull", -4.0, 0.9)
		"inhale":
			_inhale_t += delta
			_apply_inhale(delta)
			if _inhale_t >= INHALE_TIME:
				_clear_telegraph()
				if mouth_mi != null:
					mouth_mi.visible = false
				_recover(0.7)

		# ------------------------------------------------ P2：潮柱
		"pillar":
			if _sub_i < _pillar_slots.size():
				_sub_t -= delta
				if _sub_t <= 0.0:
					_spawn_pillar_warn(float(_pillar_slots[_sub_i]))
					_sub_i += 1
					_sub_t = PILLAR_GAP
			if _sub_i >= _pillar_slots.size() \
					and state_t >= float(_pillar_slots.size()) * PILLAR_GAP + TELE_PILLAR + 0.45:
				_recover(0.8)

		# ------------------------------------------------ P2：潮涌浪
		"surge_warn":
			if state_t >= TELE_SURGE:
				_reset_state("surge_push")
				_spawn_surge_fx()
				Game.shake(0.5)
				Game.play_sfx("tide", 0.0, 0.7)
		"surge_push":
			if state_t < SURGE_TIME:
				_apply_surge()
			else:
				_recover(0.7)

		# ------------------------------------------------ P2：逆鳞外露
		"expose":
			if _scale_mat != null:
				_scale_mat.emission_energy_multiplier = 1.25 + 0.55 * sin(_t * 6.0)
			if state_t >= EXPOSE_TIME:
				_turned_back = false
				if _uscale != null:
					_uscale.set_active(false)
				if _scale_mat != null:
					_scale_mat.emission_energy_multiplier = 0.25
				_recover(0.7)

		# ------------------------------------------------ P3：环形弹幕
		"ring_aim":
			if _core_mat != null:
				_core_mat.emission_energy_multiplier = lerpf(0.25, 2.5, clampf(state_t / TELE_BARRAGE, 0.0, 1.0))
			if state_t >= TELE_BARRAGE:
				_fire_ring()
				_reset_state("ring_end")
		"ring_end":
			if state_t >= 0.5:
				_recover(0.75)

		# ------------------------------------------------ P3：潮心脉冲
		"pulse_aim":
			if _core_mat != null:
				_core_mat.emission_energy_multiplier = 0.6 + 1.9 * clampf(state_t / TELE_PULSE, 0.0, 1.0)
			if state_t >= TELE_PULSE:
				_spawn_pulse()
				_clear_telegraph()
				_recover(0.9)

		# ------------------------------------------------ 召唤潮生
		"summon":
			if state_t >= 0.75 and not _hit_done:
				_hit_done = true
				_do_summon(_summon_n)
				Game.shake(0.3)
			if state_t >= 1.3:
				_recover(0.6)

		# ------------------------------------------------ 阶段转换（1.2s 无敌）
		"phase_shift":
			if gfx != null:
				gfx.position.y = sin(state_t * 9.0) * 0.05
			if state_t >= SHIFT_TIME:
				if gfx != null:
					gfx.position.y = 0.0
					gfx.scale = Vector3.ONE
				_go_idle(0.4)
				if phase == 2 and not bool(_summoned[0]):
					_summoned[0] = true
					_do_summon(2)


func _go_idle(extra := 0.0) -> void:
	state = "idle"
	state_t = 0.0
	attack_cd = _attack_interval() * randf_range(0.9, 1.15) + extra


func _attack_interval() -> float:
	if phase >= 3:
		return 1.4
	if phase == 2:
		return 1.7
	return 2.0


func _reset_state(s: String) -> void:
	state = s
	state_t = 0.0
	_hit_done = false
	_sub_i = 0
	_sub_t = 0.0
	_clear_telegraph()


func _recover(dur: float) -> void:
	state = "recover"
	state_t = 0.0
	_recover_time = dur
	_clear_telegraph()


func _pick_attack() -> void:
	var d := dist_to_player()
	var r := randf()
	if phase == 1:
		# P1：贴身先尾扫，其余扇射/吸潮轮换
		if d < 6.5 and r < 0.42:
			_begin_sweep()
		elif r < 0.78:
			_begin_fan()
		else:
			_begin_inhale()
		return
	if phase == 2:
		if hp <= max_hp * 0.36 and not bool(_summoned[1]):
			_summoned[1] = true
			_begin_summon(3)
			return
		if d < 9.0 and r < 0.34:
			_begin_pounce()
		elif r < 0.56:
			_begin_pillar()
		elif r < 0.72:
			_begin_surge()
		elif r < 0.86:
			_begin_expose()
		else:
			_begin_sweep()
		return
	# P3
	if _pulse_cd <= 0.0 and r < 0.30:
		_begin_pulse()
		return
	if d < 6.5 and r < 0.45:
		_begin_sweep()
	elif r < 0.70:
		_begin_barrage()
	elif r < 0.86:
		_begin_pounce()
	else:
		_begin_inhale()


# ================================================================ 视觉更新
func _update_visual(delta: float) -> void:
	if gfx == null:
		return
	# 呼吸浮动只动 gfx，不动本体与受击点
	gfx.position.y = sin(_t * 1.7) * 0.055

	if tail_mi != null:
		tail_mi.rotation_degrees.z = sin(_t * 1.35) * 7.0
	if tail_fin_mi != null:
		tail_fin_mi.rotation_degrees.z = 30.0 + sin(_t * 1.35 + 0.5) * 9.0
	if _eye_mat != null:
		_eye_mat.emission_energy_multiplier = 1.15 + 0.45 * sin(_t * 2.4)

	# 下颌张合
	if jaw_mi != null:
		var want := 0.0
		if state == "fan_aim" or state == "inhale" or state == "inhale_wind" \
				or state == "pounce_aim" or state == "sweep_aim" or state == "phase_shift":
			want = 1.0
		var cur := float(jaw_mi.get_meta("open", 0.0))
		cur = move_toward(cur, want, 5.0 * delta)
		jaw_mi.set_meta("open", cur)
		jaw_mi.rotation_degrees.z = -20.0 * cur
		jaw_mi.position.y = 2.05 - 0.14 * cur

	# 背脊潮纹呼吸（只在 P2/P3 更亮）
	if _dorsal_mat != null:
		var base := 0.30 if phase <= 1 else 0.55
		_dorsal_mat.emission_energy_multiplier = base + 0.12 * sin(_t * 2.1)


func _face_player(delta: float) -> void:
	if not active:
		return
	if player_alive():
		var dx := player.global_position.x - global_position.x
		if absf(dx) > 0.8:
			_face = signf(dx)
	if is_zero_approx(_face):
		_face = -1.0

	var target := 0.0 if _face > 0.0 else PI
	if _turned_back or state == "pounce_aim" or state == "pounce_go":
		# 逆鳞外露：背对玩家；扑咬：锁方向，不再转向
		if _turned_back:
			target = PI if _face > 0.0 else 0.0
		else:
			target = 0.0 if _pounce_dir > 0.0 else PI
	var k := minf(1.0, 5.0 * delta)
	if gfx != null:
		gfx.rotation.y = lerp_angle(gfx.rotation.y, target, k)
	if _hurt_root != null:
		_hurt_root.rotation.y = gfx.rotation.y if gfx != null else 0.0


func player_center() -> Vector3:
	if not player_alive():
		return Vector3(global_position.x + _face * 3.0, ground_y + 1.2, 0.0)
	return player.global_position + Vector3(0.0, 1.2, 0.0)


# ================================================================ 招式：尾扫（可弹）
func _begin_sweep() -> void:
	_reset_state("sweep_aim")
	var front := Vector3(global_position.x + _face * SWEEP_FRONT, ground_y + 0.08, 0.0)
	_show_ring(front, SWEEP_RADIUS)
	_open_parry(TELE_SWEEP + 0.16)
	Game.play_sfx("swing", -9.0, 0.7)


func _spawn_sweep_arc() -> void:
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.05
	torus.outer_radius = 4.55
	torus.ring_segments = 36
	torus.rings = 6
	mi.mesh = torus
	var mat: StandardMaterial3D = Game.std_mat(Color(0.55, 1.0, 0.9, 0.55), Color(0.55, 1.0, 0.92), 2.2, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3(global_position.x + _face * SWEEP_FRONT, ground_y + 1.35, 0.0)
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mi.scale = Vector3(0.7, 1.0, 0.7)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.12, 1.0, 1.12), 0.22)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.30)
	tw.finished.connect(mi.queue_free)
	_extra_fx.append(mi)


# ================================================================ 招式：扑咬（可弹）
func _begin_pounce() -> void:
	_reset_state("pounce_aim")
	_pounce_dir = signf(player.global_position.x - global_position.x) if player_alive() else -_face
	if is_zero_approx(_pounce_dir):
		_pounce_dir = -1.0
	_show_pounce_line(global_position.x, global_position.x + _pounce_dir * POUNCE_STEP)
	_open_parry(TELE_POUNCE + 0.16)
	Game.play_sfx("roar", -10.0, 1.45)


func _show_pounce_line(from_x: float, to_x: float) -> void:
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(maxf(absf(to_x - from_x), 1.0), 0.05, 1.9)
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3((from_x + to_x) * 0.5, ground_y + 0.09, 0.0)
	var mat: StandardMaterial3D = Game.warning_ring_material()
	mi.material_override = mat
	var tw := mi.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 1.9, 0.14)
	tw.tween_property(mat, "emission_energy_multiplier", 0.85, 0.14)
	_telegraph = mi
	_telegraph_mat = mat


# ================================================================ 招式：潮珠扇
func _begin_fan() -> void:
	_reset_state("fan_aim")
	if mouth_mi != null:
		mouth_mi.visible = true
		mouth_mi.scale = Vector3.ONE * 0.65
	if _mouth_mat != null:
		_mouth_mat.emission_energy_multiplier = 0.3
	_show_ring(Vector3(global_position.x + _face * 3.2, ground_y + 0.08, 0.0), 2.6)
	Game.play_sfx("tide", -11.0, 1.1)


func _fire_fan() -> void:
	var origin := _mouth_pos()
	var target := player_center()
	var base := clampf(atan2(target.y - origin.y, target.x - origin.x), -1.15, 0.55)
	var spread := deg_to_rad(FAN_SPREAD)
	for i in FAN_COUNT:
		var a: float = base - spread * 0.5 + spread * float(i) / float(FAN_COUNT - 1)
		var dir := Vector3(cos(a), sin(a), 0.0)
		_spawn_orb(origin + dir * 1.25, dir * FAN_SPEED, DMG_FAN, false, 3.6)
	Game.play_sfx("tide_volley", -6.0, 1.0)
	Game.shake(0.18)
	Game.burst(get_parent(), origin, C_JADE_LIT, 12, 3.5, 0.08, 0.35)


# ================================================================ 招式：吸潮
func _begin_inhale() -> void:
	_reset_state("inhale_wind")
	_inhale_t = 0.0
	if mouth_mi != null:
		mouth_mi.visible = true
		mouth_mi.scale = Vector3.ONE * 1.1
	if _mouth_mat != null:
		_mouth_mat.emission_energy_multiplier = 1.6
	_telegraph = _make_suck_ring()
	Game.play_sfx("tide", -7.0, 0.75)


func _make_suck_ring() -> Node3D:
	var par := get_parent()
	if par == null:
		return null
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.92
	torus.ring_segments = 24
	torus.rings = 6
	mi.mesh = torus
	var mat: StandardMaterial3D = Game.std_mat(Color(0.55, 0.98, 0.9, 0.0), Color(0.5, 1.0, 0.92), 1.9, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = _mouth_pos()
	mi.scale = Vector3.ONE * 0.6
	var tw := mi.create_tween()
	tw.set_loops()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.8, 0.40)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.6, 0.40)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.6, 0.26)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.04, 0.26)
	return mi


func _apply_inhale(_delta: float) -> void:
	if not player_alive():
		return
	var to_boss := global_position - player.global_position
	var d := absf(to_boss.x)
	if d <= 1.2 or d >= INHALE_RADIUS:
		return
	# 越近吸力越强（不操作会被拖到嘴边）；反跑能挣开
	var pull := INHALE_PULL * clampf(1.0 - d / INHALE_RADIUS, 0.0, 1.0)
	player.apply_external_force(Vector3(signf(to_boss.x) * pull, 0.0, 0.0))


# ================================================================ 招式：潮柱
func _begin_pillar() -> void:
	_reset_state("pillar")
	_pillar_slots.clear()
	var px := global_position.x
	if player_alive():
		px = clampf(player.global_position.x, arena_min_x + 4.0, arena_max_x - 4.0)
	_pillar_slots.append(px)
	for i in PILLAR_COUNT - 1:
		var t := float(i + 1) / float(PILLAR_COUNT)
		_pillar_slots.append(lerpf(arena_min_x + 5.0, arena_max_x - 5.0, t))
	_sub_t = 0.0
	Game.play_sfx("tide_pull", -12.0, 0.8)


func _spawn_pillar_warn(x: float) -> void:
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = PILLAR_RADIUS * 0.86
	torus.outer_radius = PILLAR_RADIUS
	torus.ring_segments = 28
	torus.rings = 6
	mi.mesh = torus
	mi.scale = Vector3(1.0, 0.14, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3(x, ground_y + 0.07, 0.0)
	var mat: StandardMaterial3D = Game.style_warning_ring(mi, PILLAR_RADIUS)
	var tw := mi.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 1.9, 0.16)
	tw.tween_property(mat, "emission_energy_multiplier", 0.9, 0.16)
	_pillars.append({"node": mi, "x": x, "t": TELE_PILLAR})


func _update_pillars(delta: float) -> void:
	var i := _pillars.size() - 1
	while i >= 0:
		var p: Dictionary = _pillars[i]
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			var node: Variant = p["node"]
			if is_instance_valid(node):
				node.queue_free()
			_fire_pillar(float(p["x"]))
			_pillars.remove_at(i)
		i -= 1


func _fire_pillar(x: float) -> void:
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.35
	cyl.bottom_radius = 1.12
	cyl.height = PILLAR_HEIGHT
	cyl.radial_segments = 12
	cyl.rings = 1
	mi.mesh = cyl
	var mat: StandardMaterial3D = Game.std_mat(Color(0.42, 0.95, 0.86, 0.55), Color(0.45, 1.0, 0.9), 2.4, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3(x, ground_y + PILLAR_HEIGHT * 0.5, 0.0)
	mi.scale = Vector3(1.0, 0.08, 1.0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.10)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.44).set_delay(0.12)
	tw.finished.connect(mi.queue_free)
	_extra_fx.append(mi)

	if player_alive():
		var pc := player_center()
		if absf(pc.x - x) < PILLAR_RADIUS + 0.55 and pc.y < ground_y + PILLAR_HEIGHT:
			player.take_damage(DMG_PILLAR, x)
	Game.shake(0.32)
	Game.play_sfx("heavy", -3.0, 0.9)
	Game.burst(par, Vector3(x, ground_y + 0.25, 0.0), C_JADE_LIT, 18, 6.0, 0.1, 0.5)


func _clear_pillars() -> void:
	for p in _pillars:
		var node: Variant = p["node"]
		if is_instance_valid(node):
			node.queue_free()
	_pillars.clear()


# ================================================================ 招式：潮涌浪
func _begin_surge() -> void:
	_reset_state("surge_warn")
	_surge_dir = signf(player.global_position.x - global_position.x) if player_alive() else -_face
	if is_zero_approx(_surge_dir):
		_surge_dir = -1.0
	_show_surge_band()
	Game.play_sfx("tide", -6.0, 0.8)


func _show_surge_band() -> void:
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(maxf(arena_max_x - arena_min_x, 8.0), 0.06, 3.4)
	mi.mesh = box
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3((arena_min_x + arena_max_x) * 0.5, ground_y + 0.10, 0.0)
	var mat: StandardMaterial3D = Game.warning_ring_material()
	mi.material_override = mat
	var tw := mi.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 2.0, 0.18)
	tw.tween_property(mat, "emission_energy_multiplier", 0.9, 0.18)
	_telegraph = mi
	_telegraph_mat = mat


func _apply_surge() -> void:
	if not player_alive():
		return
	player.apply_external_force(Vector3(_surge_dir * SURGE_PUSH, 0.0, 0.0))
	if _hit_done:
		return
	var px := player.global_position.x
	if (_surge_dir > 0.0 and px >= arena_max_x - 1.8) or (_surge_dir < 0.0 and px <= arena_min_x + 1.8):
		_hit_done = true
		player.take_damage(DMG_SURGE, global_position.x)


func _spawn_surge_fx() -> void:
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 2.6, 4.2)
	mi.mesh = box
	var mat: StandardMaterial3D = Game.std_mat(Color(0.4, 0.92, 0.85, 0.5), Color(0.45, 1.0, 0.9), 2.2, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	var start_x := arena_min_x - 2.0 if _surge_dir > 0.0 else arena_max_x + 2.0
	mi.global_position = Vector3(start_x, ground_y + 1.3, 0.0)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position:x", global_position.x + _surge_dir * 26.0, 0.55)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.finished.connect(mi.queue_free)
	_extra_fx.append(mi)


# ================================================================ 招式：逆鳞外露
func _begin_expose() -> void:
	_reset_state("expose")
	_turned_back = true
	if _uscale != null:
		_uscale.set_active(true)
	if _scale_mat != null:
		_scale_mat.emission_energy_multiplier = 1.4
	Game.play_sfx("tide", -3.0, 1.4)
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0.0, 4.2, 0.0), "逆 鳞", Color(1.0, 0.92, 0.72))


# ================================================================ 招式：环形弹幕（每 3 枚 1 枚浊潮）
func _begin_barrage() -> void:
	_reset_state("ring_aim")
	if _core_mat != null:
		_core_mat.emission_energy_multiplier = 0.25
	_show_ring(Vector3(global_position.x, ground_y + 0.08, 0.0), 3.2)
	Game.play_sfx("tide", -9.0, 1.0)


func _fire_ring() -> void:
	var c := Vector3(global_position.x, ground_y + 2.1, 0.0)
	for i in RING_BULLETS:
		var a := TAU * float(i) / float(RING_BULLETS)
		var muddy := (i % 3) == 2
		var spd := RING_SPEED_MUDDY if muddy else RING_SPEED
		var dir := Vector3(cos(a), sin(a), 0.0)
		_spawn_orb(c + dir * 1.5, dir * spd, DMG_RING_MUDDY if muddy else DMG_RING, muddy, 2.8)
	Game.play_sfx("tide_volley", -4.0, 0.85)
	Game.shake(0.3)


# ================================================================ 招式：潮心脉冲
func _begin_pulse() -> void:
	_reset_state("pulse_aim")
	_pulse_cd = PULSE_CD
	_show_ring(Vector3(global_position.x, ground_y + 0.08, 0.0), 3.6)
	Game.play_sfx("tide", -7.0, 0.6)


func _spawn_pulse() -> void:
	var par := get_parent()
	if par == null:
		return
	var pulse := TidePulse.new()
	par.add_child(pulse)
	pulse.setup_pulse(self, Vector3(global_position.x, ground_y, 0.0), DMG_PULSE, PULSE_RADIUS, PULSE_HEIGHT, PULSE_EXPAND)
	Game.shake(0.6)
	Game.play_sfx("nova", -4.0, 0.7)
	Game.burst(par, Vector3(global_position.x, ground_y + 0.3, 0.0), C_JADE_LIT, 26, 9.0, 0.1, 0.6)


# ================================================================ 召唤
func _begin_summon(n: int) -> void:
	_reset_state("summon")
	_summon_n = n
	_show_ring(Vector3(global_position.x, ground_y + 0.08, 0.0), 4.2)
	Game.play_sfx("tide_pull", -8.0, 0.8)


func _do_summon(n: int) -> void:
	var lv := get_parent()
	if lv != null and _level_has_spawnling(lv):
		for i in n:
			var t := (float(i) + 0.5) / float(n)
			var x: float = lerpf(arena_min_x + 3.5, arena_max_x - 3.5, t)
			lv.call("_spawn_spawnling", x, ground_y, arena_min_x + 1.5, arena_max_x - 1.5)
		_tip("潮生涌出")
	else:
		# 关卡没提供 _spawn_spawnling 时走 level_base 的 summon_unit 通道
		summon_requested.emit(n)


func _level_has_spawnling(lv: Object) -> bool:
	for m in lv.get_method_list():
		if String(m.get("name", "")) == "_spawn_spawnling":
			var args: Array = m.get("args", [])
			return args.size() == 4
	return false


func _tip(text: String) -> void:
	var lv := get_parent()
	if lv == null:
		return
	var hud: Variant = lv.get("hud")
	if hud != null and hud.has_method("show_message"):
		hud.call("show_message", text, 1.6, 30)


# ================================================================ 受击
func take_damage_at(zone: String, dmg: float, dir: float, heavy: bool, at: Vector3) -> void:
	## 受击点入口。同一个物理帧只认第一刀：躯干/潮心/逆鳞的包围球会重叠，
	## 不拦一下同一次挥击会打出双倍。
	if not active or dead:
		return
	var fr := Engine.get_physics_frames()
	if fr == _last_hit_frame:
		return
	_last_hit_frame = fr
	if _invuln_t > 0.0:
		Game.spawn_dmg_text(get_parent(), at + Vector3(0.0, 0.6, 0.0), "免", Color(0.6, 0.95, 0.85))
		return
	var mul := _zone_mult(zone)
	if mul <= 0.0:
		return
	if zone == "scale":
		# 逆鳞：反弹 ×1.5 已由玩家侧 reflect 的伤害体现，这里只放大"打中弱点"的收益
		mul = 1.5
	_apply_damage(dmg * mul, dir, heavy, at, zone)


func _zone_mult(zone: String) -> float:
	if zone == "head":
		if phase <= 1:
			return 1.15
		if phase == 2:
			return 0.55
		return 1.0
	if zone == "body":
		if phase <= 1:
			return 0.55
		if phase == 2:
			return 0.40
		return 0.50
	if zone == "scale":
		return 1.5
	if zone == "core":
		return 1.5
	return 1.0


func take_damage(dmg: float, dir: float, heavy := false) -> void:
	## 本体没有碰撞体（collision_layer = 0）。这个入口专门给"非指向伤害"用：
	## on_parried 的反震 30 点、以及未来任何按 EnemyBase 契约直接打到 Boss 身上的伤害。
	if not active or dead:
		return
	var fr := Engine.get_physics_frames()
	if fr == _last_hit_frame:
		return
	_last_hit_frame = fr
	if _invuln_t > 0.0:
		return
	_apply_damage(dmg, dir, heavy, global_position + Vector3(_face * 1.6, 2.4, 0.0), "parry")


func _apply_damage(d: float, _dir: float, heavy: bool, at: Vector3, zone: String) -> void:
	hp = maxf(hp - d, 0.0)
	hurt_t = 0.22
	_hit_flash()
	Game.spawn_dmg_text(get_parent(), at + Vector3(0.0, 0.5, 0.0), str(int(round(d))),
			C_WEAK if (zone == "core" or zone == "scale") else C_DMG,
			d >= 20.0 or zone == "core" or zone == "scale")
	Game.burst(get_parent(), at, C_HIT, 6, 3.0, 0.06, 0.28)
	boss_hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		die()
		return
	if phase == 1 and hp <= max_hp * PHASE2_AT:
		_enter_phase(2)
	elif phase == 2 and hp <= max_hp * PHASE3_AT:
		_enter_phase(3)


func _hit_flash() -> void:
	## 0.14s 内不叠第二次闪红：Game.flash_meshes 会把"当时"的材质当底板，
	## 连续两次会把红材质固化成常驻底色。
	if _flash_lock > 0.0:
		return
	_flash_lock = 0.2
	Game.flash_meshes(gfx, C_HIT, 0.07)


func _update_contact() -> void:
	if _contact_cd > 0.0 or not player_alive():
		return
	var p := player.global_position
	if absf(p.x - global_position.x) < TOUCH_R and absf(p.y - ground_y) < 3.2:
		_contact_cd = TOUCH_CD
		player.take_damage(TOUCH_DMG, global_position.x)


func _open_parry(dur: float) -> void:
	## 可弹招式：起手红光 + 吸气音由 EnemyBase.open_parry_window 统一给
	_flash_lock = 0.2
	open_parry_window(dur)


func _melee_hit(dmg: float) -> void:
	## 「谁打人谁问」：先问玩家能不能架住，架住就由玩家侧结算反震/僵直
	if not player_alive():
		return
	if parry_window_open() and player.has_method("try_parry_melee") \
			and bool(player.call("try_parry_melee", self)):
		return
	player.take_damage(dmg, global_position.x)


# ================================================================ 阶段
func _enter_phase(p: int) -> void:
	phase = p
	state = "phase_shift"
	state_t = 0.0
	_hit_done = false
	_invuln_t = SHIFT_INVULN
	velocity = Vector3.ZERO
	_clear_telegraph()
	_clear_pillars()
	_clear_shots()
	if gfx != null:
		gfx.scale = Vector3.ONE
	if p == 2:
		set_rim_color(Color(0.95, 0.84, 0.50, 0.95))
		Game.play_sfx("roar", 2.0, 0.8)
		Game.shake(1.0)
		Game.hitstop(0.28, 0.1)
		Game.spawn_dmg_text(get_parent(), global_position + Vector3(0.0, 4.6, 0.0), "腾 潮", Color(1.0, 0.88, 0.55), true)
		_water_curtain()
	else:
		set_rim_color(Color(0.50, 1.0, 0.88, 0.98))
		_core_open(true)
		Game.play_sfx("abyss", 1.0, 0.7)
		Game.shake(1.2)
		Game.hitstop(0.3, 0.1)
		Game.spawn_dmg_text(get_parent(), global_position + Vector3(0.0, 4.6, 0.0), "潮 心 显 形", Color(0.55, 1.0, 0.85), true)
		_light_column()
	Game.burst(get_parent(), global_position + Vector3(0.0, 2.4, 0.0), C_JADE_LIT, 40, 9.0, 0.13, 1.0)
	_cam_punch(0.12)


func _core_open(on: bool) -> void:
	if core_mi != null:
		core_mi.visible = on
	if _ucore != null:
		_ucore.set_active(on)


func _set_hurtpoints_phase(_p: int) -> void:
	if _ubody != null:
		_ubody.set_active(true)
	if _uhead != null:
		_uhead.set_active(true)
	if _uscale != null:
		_uscale.set_active(false)
	if _ucore != null:
		_ucore.set_active(phase >= 3)


func _water_curtain() -> void:
	## P1→P2：一圈水幕从脚下推开
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.2
	torus.outer_radius = 5.4
	torus.ring_segments = 40
	torus.rings = 6
	mi.mesh = torus
	var mat: StandardMaterial3D = Game.std_mat(Color(0.45, 0.95, 0.88, 0.6), Color(0.5, 1.0, 0.92), 2.4, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3(global_position.x, ground_y + 1.1, 0.0)
	mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	mi.scale = Vector3(0.4, 1.0, 0.4)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.35, 1.0, 1.35), 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.finished.connect(mi.queue_free)
	_extra_fx.append(mi)


func _light_column() -> void:
	## P2→P3：一道光柱打下来，潮心外露
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 1.35
	cyl.height = 12.0
	cyl.radial_segments = 14
	cyl.rings = 1
	mi.mesh = cyl
	var mat: StandardMaterial3D = Game.std_mat(Color(0.6, 1.0, 0.9, 0.0), Color(0.55, 1.0, 0.9), 2.4, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = Vector3(global_position.x, ground_y + 6.0, 0.0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.55, 0.18)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9).set_delay(0.45)
	tw.finished.connect(mi.queue_free)
	_extra_fx.append(mi)


func _cam_punch(amount: float) -> void:
	var lv := get_parent()
	if lv == null:
		return
	var cam: Variant = lv.get("cam")
	if cam != null and cam.has_method("punch"):
		cam.call("punch", amount)


# ================================================================ 弹幕
func _spawn_orb(pos: Vector3, vel: Vector3, dmg: float, muddy: bool, life: float) -> Projectile:
	var par := get_parent()
	if par == null:
		return null
	var proj := Projectile.new()
	proj.team = Projectile.TEAM_ENEMY
	proj.dmg = dmg
	proj.life = life
	proj.vel = vel
	proj.tint = Color(0.80, 0.18, 0.13) if muddy else Color(0.45, 0.95, 0.85)
	proj.is_muddy = muddy
	proj.parryable = not muddy
	par.add_child(proj)
	proj.global_position = pos
	_shots.append(proj)
	return proj


func _mouth_pos() -> Vector3:
	if gfx == null:
		return global_position + Vector3(_face * 3.6, 2.3, 0.0)
	return gfx.global_transform * Vector3(4.05, 2.28, 0.0)


func _prune_shots() -> void:
	var i := _shots.size() - 1
	while i >= 0:
		if not is_instance_valid(_shots[i]):
			_shots.remove_at(i)
		i -= 1


func _clear_shots() -> void:
	for p in _shots:
		if is_instance_valid(p):
			p.queue_free()
	_shots.clear()
	# 兜底：场上还挂着、属于敌方且在 Boss 场范围里的弹幕一起清掉（重生后不会一落地就中弹）
	var par := get_parent()
	if par == null:
		return
	for n in par.get_children():
		if n is Projectile and (n as Projectile).team == Projectile.TEAM_ENEMY:
			var px: float = (n as Node3D).global_position.x
			if px >= arena_min_x - 2.0 and px <= arena_max_x + 2.0:
				n.queue_free()


# ================================================================ 预警环
func _show_ring(pos: Vector3, radius: float) -> void:
	_clear_telegraph()
	var par := get_parent()
	if par == null:
		return
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.86
	torus.outer_radius = radius
	torus.ring_segments = 40
	torus.rings = 8
	mi.mesh = torus
	mi.scale = Vector3(1.0, 0.14, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	mi.global_position = pos
	var mat: StandardMaterial3D = Game.style_warning_ring(mi, radius)
	var tw := mi.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 1.8, 0.16)
	tw.tween_property(mat, "emission_energy_multiplier", 0.9, 0.16)
	_telegraph = mi
	_telegraph_mat = mat


func _clear_telegraph() -> void:
	if _telegraph != null and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null
	_telegraph_mat = null


# ================================================================ 死亡 / 复位
func die() -> void:
	if dead:
		return
	dead = true
	is_dead = true
	active = false
	hp = 0.0
	_invuln_t = 0.0
	state = "dead"
	state_t = 0.0
	velocity = Vector3.ZERO
	_clear_all()
	if _ubody != null:
		_ubody.set_active(false)
	if _uhead != null:
		_uhead.set_active(false)
	if _uscale != null:
		_uscale.set_active(false)
	if _ucore != null:
		_ucore.set_active(false)
	boss_hp_changed.emit(0.0, max_hp)
	Game.play_sfx("boss_die", 2.0, 0.9)
	Game.shake(1.5)
	Game.hitstop(0.5, 0.12)
	var par := get_parent()
	Game.burst(par, global_position + Vector3(0.0, 2.0, 0.0), C_JADE_LIT, 40, 9.0, 0.14, 1.1)
	Game.burst(par, global_position + Vector3(0.0, 2.8, 0.0), C_CORE, 30, 6.0, 0.12, 1.3)
	Game.burst(par, global_position + Vector3(_face * 2.0, 1.4, 0.0), C_BONE, 24, 5.0, 0.1, 1.4)
	boss_defeated.emit()
	# 螭吻垂首、潮水倒卷：沉下去而不是缩小
	if gfx != null:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(gfx, "rotation:z", deg_to_rad(-14.0), 2.2)
		tw.tween_property(gfx, "scale", Vector3(1.0, 0.82, 1.0), 2.2)
		tw.tween_property(self, "global_position:y", ground_y - 2.6, 2.2) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()


func reset_fight() -> void:
	## 玩家死亡重生后由 level_base._reset_boss_fight 调用；不报错、不留尾巴
	if dead:
		return
	active = false
	is_dead = false
	hp = max_hp
	phase = 1
	state = "dormant"
	state_t = 0.0
	attack_cd = 2.0
	_t = 0.0
	_invuln_t = 0.0
	_contact_cd = 0.0
	_pulse_cd = PULSE_CD
	_hit_done = false
	_flash_lock = 0.0
	_last_hit_frame = -1
	_inhale_t = 0.0
	_sub_i = 0
	_sub_t = 0.0
	_summoned = [false, false]
	_turned_back = false
	_face = -1.0
	velocity = Vector3.ZERO
	_clear_all()
	_sync_arena()
	# 本体不贴地：没有重力时 y 完全由关卡摆放决定（ground_y 只用于地面特效与判定）
	global_position = home_pos
	if gfx != null:
		gfx.position = Vector3.ZERO
		gfx.rotation = Vector3.ZERO
		gfx.scale = Vector3.ONE
	if _hurt_root != null:
		_hurt_root.rotation.y = 0.0
	if jaw_mi != null:
		jaw_mi.set_meta("open", 0.0)
		jaw_mi.rotation_degrees.z = 0.0
		jaw_mi.position.y = 2.05
	if tail_mi != null:
		tail_mi.rotation_degrees.z = 0.0
	if tail_fin_mi != null:
		tail_fin_mi.rotation_degrees.z = 30.0
	if mouth_mi != null:
		mouth_mi.visible = false
		mouth_mi.scale = Vector3.ONE
	if _mouth_mat != null:
		_mouth_mat.emission_energy_multiplier = 0.3
	if _scale_mat != null:
		_scale_mat.emission_energy_multiplier = 0.25
	if _core_mat != null:
		_core_mat.emission_energy_multiplier = 1.5
	_core_open(false)
	_set_hurtpoints_phase(1)
	set_rim_color(Color(0.45, 1.0, 0.86, 0.95))
	boss_hp_changed.emit(hp, max_hp)


func _clear_all() -> void:
	_clear_telegraph()
	_clear_pillars()
	_clear_shots()
	for fx in _extra_fx:
		if is_instance_valid(fx):
			fx.queue_free()
	_extra_fx.clear()
	if mouth_mi != null:
		mouth_mi.visible = false
	if _mouth_mat != null:
		_mouth_mat.emission_energy_multiplier = 0.3
	if _scale_mat != null:
		_scale_mat.emission_energy_multiplier = 0.25


# ================================================================ 内部类
class HitPoint extends StaticBody3D:
	## 受击点：必须是 PhysicsBody3D —— 反射回来的 Projectile 走 body_entered（mask 1|4），
	## 用 Area3D 的话反弹弹永远打不到 Boss。collision_layer=4 正好是玩家挥击的 mask。
	var boss = null   # 用 Variant 存：内层类里要动态调 take_damage_at
	var zone := "body"

	func setup_hit(b, z: String, radius: float, height: float, at: Vector3) -> void:
		boss = b
		zone = z
		collision_layer = 4
		collision_mask = 0
		position = at
		var cs := CollisionShape3D.new()
		if height > 0.0:
			var cap := CapsuleShape3D.new()
			cap.radius = radius
			cap.height = maxf(height, radius * 2.0 + 0.2)
			cs.shape = cap
		else:
			var sp := SphereShape3D.new()
			sp.radius = radius
			cs.shape = sp
		add_child(cs)

	func set_active(on: bool) -> void:
		collision_layer = 4 if on else 0

	func hit_key() -> Object:
		## 一次攻击只能命中 Boss 一次：把 4 个受击点归并到同一个 key。
		## 乾坤圈是"逐帧扫过"的，原先 _last_hit_frame 只能拦同帧，去程会连打
		## 躯干 + 头 + 逆鳞，伤害直接翻 2~3 倍。
		return boss

	func hit_priority() -> int:
		## 同一次攻击同时罩住多个受击点时，按收益最高的部位结算
		return {"core": 4, "scale": 3, "head": 2, "body": 1}.get(zone, 1)

	func take_damage(dmg: float, dir: float, heavy := false) -> void:
		if boss != null and is_instance_valid(boss):
			boss.take_damage_at(zone, dmg, dir, heavy, global_position)


class TidePulse extends Node3D:
	## 潮心脉冲：从中心向外扩的水墙。贴着地面扫，跳起来能躲过。
	var boss = null   # Variant：要读 boss.player
	var dmg := 22.0
	var max_radius := 9.0
	var height := 2.4
	var expand := 0.7
	var center := Vector3.ZERO
	var _t := 0.0
	var _r := 0.5
	var _hit := false
	var _mi: MeshInstance3D = null
	var _mat: StandardMaterial3D = null

	func setup_pulse(b, c: Vector3, dmg_: float, radius: float, h: float, expand_: float) -> void:
		boss = b
		center = c
		global_position = c
		dmg = dmg_
		max_radius = radius
		height = h
		expand = maxf(expand_, 0.05)

	func _ready() -> void:
		_mi = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.88
		torus.outer_radius = 1.0
		torus.ring_segments = 40
		torus.rings = 6
		_mi.mesh = torus
		_mat = Game.std_mat(Color(0.5, 1.0, 0.9, 0.8), Color(0.55, 1.0, 0.92), 2.4, 0.25)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mi.material_override = _mat
		_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mi.position = Vector3(0.0, 0.35, 0.0)
		_mi.scale = Vector3(0.5, 1.0, 0.5)
		add_child(_mi)

	func _physics_process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / expand, 0.0, 1.0)
		_r = lerpf(0.5, max_radius, k)
		if _mi != null:
			_mi.scale = Vector3(_r, 1.0, _r)
		if _mat != null:
			_mat.albedo_color.a = lerpf(0.8, 0.0, k)
		if not _hit and boss != null and is_instance_valid(boss):
			var p: Variant = boss.player
			if p != null and p.act != "dead":
				var pp: Vector3 = p.global_position + Vector3(0.0, 0.9, 0.0)
				if absf(pp.x - center.x) <= _r and (pp.y - center.y) <= height and (pp.y - center.y) > -0.8:
					_hit = true
					p.take_damage(dmg, center.x)
		if _t >= expand + 0.25:
			queue_free()

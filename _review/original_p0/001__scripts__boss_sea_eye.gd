class_name BossSeaEye
extends EnemyBase
## 归墟海眼 · 第三章 Boss（三核封印 → 巨瞳）
## ------------------------------------------------------------------
## 一阶段「三核」：
##   本体悬浮在场地中央（不可直接受击：根节点不挂 layer4 碰撞体、不 add_hitbox）。
##   三枚「封印之瞳」是可击破 Area3D（collision_layer=4），玩家普攻 / 真火 /
##   乾坤圈都能打中，位置按关卡约定：
##     core0  center-6, ground+1.5   站地普攻可中
##     core1  center,   ground+2.1   站地 / 轻跳可中
##     core2  center+6, ground+2.8   需要跳起来
##   存活核心轮流出招（0.6~0.8s 预警），每破一核出招间隔 ×0.8、剩余核心转速提升：
##     · 水弹扇   —— 该核心向玩家扇形射 3 发水弹（复用 Projectile），单发 10
##     · 潮涌环   —— 贴地扩散环形水墙，单次判定 14，跳起可躲
##     · 海眼引力井 —— 场地中心 2s 吸力（9 m/s²），另一核心同时补一轮弹幕
## 二阶段「巨瞳」：
##   三核全破后残骸合并成巨瞳（大球 + 追随玩家的瞳孔 + 3 层旋转符文环），
##   招式按固定循环（规则变化，不只是数值）：潮涌环 → 水弹扇 → 海眼脉冲 → 水弹扇
##     · 潮涌环   0.75s 预警，贴地水墙单次判定 16，单跳 / 摆荡可躲
##     · 海眼脉冲 0.9s 预警 + 1.2s 扩散的紫色全场冲击波，判定 20；
##                玩家 y < ground_y+2.6 才被扫到 —— 单跳（2.18）不够高，
##                必须二段跳或借两端 SwingAnchor 摆荡甩到高处
##     · 水弹扇   5 发扇形水弹，单发 10
## ------------------------------------------------------------------
## 血量约定：总 540 = 三核 180×3。一阶段每碎一核总血掉 180，三核全破时见底；
## 残骸合并成巨瞳时把最后的 1/3（180）作为二阶段血量，继续掉到 0 才结束，
## 因此 HUD 的 Boss 血条在转阶段时会从空条回到 1/3（巨瞳重凝）。
## ------------------------------------------------------------------
## 契约与 BossMaw / BossWarden 完全一致：信号 boss_hp_changed /
## summon_requested（本 Boss 不召唤，空实现）/ boss_defeated，
## 方法 activate() / reset_fight() / take_damage(dmg, dir, heavy) / die()。
## 全文程序化网格（珍珠青白球 + 符文 TorusMesh + 粒子），不复用第一章 boss.glb。
## 所有外观引用在 reset_fight 时都可能为 null / 已被释放，逐项判空。

signal boss_hp_changed(hp: float, max_hp: float)
signal summon_requested(count: int)
signal boss_defeated

const TOTAL_HP := 540.0
const CORE_MAX_HP := 180.0
const P2_HP := 180.0            # 二阶段起始血 = 总血 1/3（巨瞳重凝）
const ROOT_HOVER_H := 2.2       # 关卡约定：根节点 y = ground_y + 2.2
const ARENA_HALF_FALLBACK := 9.0
const CORE_GAP := 6.0           # 三核相对场地中心的 x 间距
const CORE_RADIUS := 0.75       # 碰撞球半径

const ATTACK_INTERVAL := 2.2
const TELE_FAN := 0.6
const TELE_RING := 0.7
const TELE_WELL := 0.75
const WELL_TIME := 2.0
const WELL_STRENGTH := 15.0     # 引力井加速度（m/s²）：要明显干扰走位，冲刺可脱身

const TELE_P2_RING := 0.75
const TELE_P2_FAN := 0.6
const TELE_P2_PULSE := 0.9
const P2_IDLE_CD := 1.4
const PULSE_EXPAND := 1.2
const PULSE_HEIGHT := 2.6       # 冲击波判定高度：单跳(2.18)不够，必须二段跳/摆荡
const P2_CONTACT_DMG := 8.0
const P2_CONTACT_CD := 1.2
const INTRO_TIME := 0.5

# 珍珠青白（一阶段）/ 幽紫（二阶段）
const C_PEARL := Color(0.55, 0.9, 1.0, 0.9)
const C_DEEP := Color(0.38, 0.84, 1.0)
const C_WHITE := Color(0.78, 0.98, 1.0)
const C_PULSE := Color(0.72, 0.38, 1.0)
const C_RIM_P2 := Color(0.72, 0.42, 1.0, 0.95)

var active := false
var arena_min_x := 0.0
var arena_max_x := 0.0
var ground_y := 0.0
var home_pos := Vector3.ZERO

var state := "dormant"
var state_t := 0.0
var attack_cd := 2.2
var phase := 1

var _t := 0.0
var _intro_t := 0.0
var _broken_count := 0
var _cast_core := -1
var _cast_kind := ""
var _last_kind := ""
var _tele_time := 0.7
var _recover_time := 0.4
var _p2_seq_i := 0
var _p2_glow := 0.0
var _contact_cd := 0.0
var _well_t := 0.0
var _well_fan_t := 0.0
var _well_fans := 0
var _telegraph: MeshInstance3D = null
var _well_node: Node3D = null
var _well_rings: Array = []

var _cores: Array = []          # Sealoore
var _rings: Array = []          # TideRing
var _projectiles: Array = []    # Projectile

# 外观引用（模型 / 程序化两种模式下都可能为 null，读写前必须判空）
var _core_root: Node3D = null
var _p1_root: Node3D = null
var _p1_ring: MeshInstance3D = null
var _p1_eye_mat: StandardMaterial3D = null
var _p1_light: OmniLight3D = null
var _p2_root: Node3D = null
var _eye_mat: StandardMaterial3D = null
var _iris_mat: StandardMaterial3D = null
var _pupil: MeshInstance3D = null
var _p2_rings: Array = []
var _p2_light: OmniLight3D = null
var _p2_particles: GPUParticles3D = null
var _hurtbox = null


# ================================================================ 基类钩子

func _setup() -> void:
	max_hp = TOTAL_HP
	hp = max_hp
	uses_gravity = false
	collision_mask = 0
	collision_layer = 0     # 本体不可被玩家 hitbox 打到，真正可打的是三核 / 二阶段 hurtbox
	touch_damage = 0.0
	knock_resist = 1.0
	rim_color = C_PEARL
	if home_pos.is_zero_approx():
		home_pos = global_position
	_sync_arena()
	_build_cores()
	_layout_cores()


# ================================================================ 场地 / 摆位

func _sync_arena() -> void:
	## level_3 把 arena 参数交给了 _setup_boss()，不一定回写给 Boss 本体的字段；
	## 这里按关卡约定兜底自算：根节点位于 (场地中心, ground_y + 2.2)，半宽 ±9。
	if arena_max_x <= arena_min_x + 0.5:
		arena_min_x = home_pos.x - ARENA_HALF_FALLBACK
		arena_max_x = home_pos.x + ARENA_HALF_FALLBACK
	if absf(ground_y) < 0.001:
		var derived := home_pos.y - ROOT_HOVER_H
		if absf(derived) > 0.01:
			ground_y = derived


func _arena_center_x() -> float:
	return (arena_min_x + arena_max_x) * 0.5


func _layout_cores() -> void:
	## 三核按【真实场地中心】摆位（不是根节点位置）：即使关卡把本体放偏也能对。
	if _core_root == null or not is_instance_valid(_core_root):
		return
	var cx := _arena_center_x() - global_position.x
	# 中间那颗核不能和 Boss 本体（场地中心 y≈2.2 的大球）叠在一起，
	# 否则看起来像"场地中间有两个 Boss"。第三颗核放高一点，成为明显的高位目标。
	var specs := [
		Vector3(cx - CORE_GAP, ground_y + 1.5 - global_position.y, 0.0),
		Vector3(cx, ground_y + 4.6 - global_position.y, 0.0),
		Vector3(cx + CORE_GAP, ground_y + 2.8 - global_position.y, 0.0),
	]
	for i in _cores.size():
		var c = _cores[i]
		if c == null or not is_instance_valid(c):
			continue
		c.base_local = specs[i]
		c.position = specs[i]


# ================================================================ 外观（全程序化）

func _build_gfx() -> void:
	_build_p1_visual()
	_build_p2_visual()
	# 二阶段巨瞳的可受击球（一阶段关闭层）
	_hurtbox = EyeHurtbox.new()
	_hurtbox.setup_hurtbox(self, 1.9)
	add_child(_hurtbox)


func _build_p1_visual() -> void:
	## 一阶段本体：被封印的「海眼」，深青珍珠壳 + 内瞳 + 一圈缓慢反旋的封印环
	_p1_root = Node3D.new()
	_p1_root.name = "SeaEyeBody"
	gfx.add_child(_p1_root)

	var shell := SphereMesh.new()
	shell.radius = 0.9
	shell.height = 1.8
	shell.radial_segments = 24
	shell.rings = 14
	var shell_mat := Game.std_mat(Color(0.16, 0.33, 0.42),
		Color(0.16, 0.5, 0.66), 0.55, 0.32, 0.15)
	Game.add_mesh(_p1_root, shell, shell_mat, Vector3.ZERO)

	_p1_eye_mat = Game.std_mat(Color(0.62, 0.88, 0.97),
		Color(0.42, 0.85, 0.95), 0.9, 0.18)
	var inner := SphereMesh.new()
	inner.radius = 0.42
	inner.height = 0.84
	inner.radial_segments = 18
	inner.rings = 10
	Game.add_mesh(_p1_root, inner, _p1_eye_mat, Vector3(0, 0, 0.42))

	# 封印环（水平绕本体一圈，二阶段会随本体消失）
	var torus := TorusMesh.new()
	torus.inner_radius = 1.02
	torus.outer_radius = 1.2
	torus.ring_segments = 40
	torus.rings = 8
	var ring_mat := Game.std_mat(Color(0.42, 0.85, 0.95, 0.8),
		Color(0.32, 0.80, 0.95), 0.9, 0.25)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_p1_ring = Game.add_mesh(_p1_root, torus, ring_mat, Vector3.ZERO)

	# 珍珠内涌的灵光
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.85
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.4, 0)
	pm.color = Color(0.5, 0.92, 1.0, 0.45)
	p.process_material = pm
	p.draw_pass_1 = _make_dot_mesh(Color(0.75, 1.0, 1.0, 0.6))
	_p1_root.add_child(p)

	_p1_light = OmniLight3D.new()
	_p1_light.light_color = Color(0.4, 0.85, 1.0)
	_p1_light.light_energy = 1.3
	_p1_light.omni_range = 9.0
	_p1_light.shadow_enabled = false
	_p1_root.add_child(_p1_light)


func _build_p2_visual() -> void:
	## 二阶段巨瞳：珍珠紫白大球 + 黑瞳（追随玩家）+ 虹膜环 + 3 层旋转符文环
	_p2_root = Node3D.new()
	_p2_root.name = "GiantEye"
	_p2_root.visible = false
	gfx.add_child(_p2_root)

	_eye_mat = Game.std_mat(Color(0.68, 0.9, 1.0),
		Color(0.6, 0.42, 1.0), 1.2, 0.2)
	var eye := SphereMesh.new()
	eye.radius = 1.8
	eye.height = 3.6
	eye.radial_segments = 32
	eye.rings = 20
	Game.add_mesh(_p2_root, eye, _eye_mat, Vector3.ZERO)

	# 外层水膜（加法透明，勾出巨瞳轮廓）
	var membrane := SphereMesh.new()
	membrane.radius = 2.05
	membrane.height = 4.1
	membrane.radial_segments = 28
	membrane.rings = 18
	var mem_mat := Game.std_mat(Color(0.55, 0.82, 1.0, 0.1),
		Color(0.55, 0.45, 1.0), 0.7, 0.2)
	mem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mem_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mem_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	Game.add_mesh(_p2_root, membrane, mem_mat, Vector3.ZERO)

	# 黑瞳（在球体前表面，z 正方向朝镜头），位置随玩家移动
	var pupil_mesh := SphereMesh.new()
	pupil_mesh.radius = 0.55
	pupil_mesh.height = 1.1
	pupil_mesh.radial_segments = 20
	pupil_mesh.rings = 12
	var pupil_mat := Game.std_mat(Color(0.03, 0.01, 0.06),
		Color(0.22, 0.1, 0.35), 0.7, 0.4)
	_pupil = Game.add_mesh(_p2_root, pupil_mesh, pupil_mat,
		Vector3(0, 0, 1.45))

	# 虹膜（面向镜头的环）
	_iris_mat = Game.std_mat(Color(0.68, 0.6, 1.0, 0.9),
		Color(0.65, 0.5, 1.0), 1.8, 0.22)
	_iris_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_iris_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var iris := TorusMesh.new()
	iris.inner_radius = 0.64
	iris.outer_radius = 0.86
	iris.ring_segments = 40
	iris.rings = 8
	Game.add_mesh(_p2_root, iris, _iris_mat, Vector3(0, 0, 1.62),
		Vector3(90, 0, 0))

	# 3 层符文环（每层轴向不同，各自旋转）
	var ring_radii := [2.05, 2.35, 2.65]
	var ring_thick := [0.06, 0.05, 0.045]
	var ring_cols := [Color(0.55, 0.9, 1.0), Color(0.7, 0.45, 1.0),
		Color(0.5, 0.8, 1.0)]
	var ring_rots := [Vector3(80, 0, 20), Vector3(15, 70, 40),
		Vector3(35, 25, 85)]
	_p2_rings = []
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = float(ring_radii[i]) - float(ring_thick[i])
		torus.outer_radius = float(ring_radii[i])
		torus.ring_segments = 48
		torus.rings = 8
		var col: Color = ring_cols[i]
		var rot: Vector3 = ring_rots[i]
		var m := Game.std_mat(Color(col.r, col.g, col.b, 0.75), col, 2.2, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := Game.add_mesh(_p2_root, torus, m, Vector3.ZERO, rot)
		_p2_rings.append(mi)

	# 环绕雾气
	_p2_particles = GPUParticles3D.new()
	_p2_particles.amount = 30
	_p2_particles.lifetime = 2.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.2
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.35, 0)
	pm.color = Color(0.6, 0.42, 1.0, 0.4)
	_p2_particles.process_material = pm
	_p2_particles.draw_pass_1 = _make_dot_mesh(Color(0.75, 0.6, 1.0, 0.6))
	_p2_particles.emitting = false
	_p2_root.add_child(_p2_particles)

	_p2_light = OmniLight3D.new()
	_p2_light.light_color = Color(0.6, 0.42, 1.0)
	_p2_light.light_energy = 1.5
	_p2_light.omni_range = 14.0
	_p2_light.shadow_enabled = false
	_p2_light.light_volumetric_fog_energy = 0.25
	_p2_root.add_child(_p2_light)


func _make_dot_mesh(col: Color) -> SphereMesh:
	var dm := SphereMesh.new()
	dm.radius = 0.06
	dm.height = 0.12
	dm.radial_segments = 5
	dm.rings = 3
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = col
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.vertex_color_use_as_albedo = true
	dm.material = dmat
	return dm


# ================================================================ 三核构建

func _build_cores() -> void:
	_core_root = Node3D.new()
	_core_root.name = "Sealoores"
	add_child(_core_root)
	for i in 3:
		var c = Sealoore.new()
		c.name = "Sealoore%d" % i
		# 先 setup（建子节点），再入树，避免 _ready 时引用还没准备好
		c.setup_core(self, i, float(i) * 2.1)
		_core_root.add_child(c)
		_cores.append(c)


func _core_world_pos(idx: int) -> Vector3:
	if idx >= 0 and idx < _cores.size():
		var c = _cores[idx]
		if c != null and is_instance_valid(c):
			return c.global_position
	return Vector3(_arena_center_x(), ground_y + 2.0, 0.0)


func _pick_next_core() -> int:
	## 存活核心轮流出招
	var n := _cores.size()
	for step in n:
		var idx := (_cast_core + 1 + step) % n
		var c = _cores[idx]
		if c != null and is_instance_valid(c) and not c.broken:
			return idx
	return -1


func _pick_other_core(exclude: int) -> int:
	var n := _cores.size()
	for step in n:
		var idx := (exclude + 1 + step) % n
		var c = _cores[idx]
		if c != null and is_instance_valid(c) and not c.broken:
			return idx
	return -1


func _set_core_glow(idx: int, c: float) -> void:
	if idx < 0 or idx >= _cores.size():
		return
	var core = _cores[idx]
	if core == null or not is_instance_valid(core) or core.broken:
		return
	core.set_glow(c)


func _clear_core_glow() -> void:
	for core in _cores:
		if core == null or not is_instance_valid(core):
			continue
		core.set_glow(0.0)


# ================================================================ 激活

func activate() -> void:
	if active or dead:
		return
	active = true
	phase = 1
	hp = max_hp
	state = "idle"
	state_t = 0.0
	attack_cd = ATTACK_INTERVAL
	_intro_t = INTRO_TIME
	_broken_count = 0
	_p2_seq_i = 0
	_cast_core = -1
	_cast_kind = ""
	_last_kind = ""
	_contact_cd = 0.0
	_well_t = 0.0
	_well_fan_t = 0.0
	# 若关卡在 add_child 之后才回写 arena / home_pos，这里再对齐一次
	_sync_arena()
	_layout_cores()
	if gfx:
		gfx.scale = Vector3(0.6, 0.6, 0.6)
	Game.play_sfx("abyss", 0.0, 0.85)
	Game.play_sfx("roar", -3.0, 0.8)
	Game.shake(0.9)
	var parent := get_parent()
	if parent:
		Game.burst(parent, global_position, C_PEARL, 40, 8.0, 0.13, 0.9)
		Game.burst(parent, global_position, C_DEEP, 24, 5.0, 0.1, 0.6)
	if _p1_light:
		_p1_light.light_energy = 3.0
	boss_hp_changed.emit(hp, max_hp)


# ================================================================ 行为主循环

func _behave(delta: float) -> void:
	_t += delta
	state_t += delta
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	if gfx == null:
		return
	# 悬浮呼吸（只动 gfx，不动根节点：三核按世界坐标摆位，不能被带着漂）
	gfx.position.y = sin(_t * 0.85) * (0.12 if phase == 1 else 0.16)
	if _p1_ring and is_instance_valid(_p1_ring):
		_p1_ring.rotation.y += delta * (0.7 if phase == 1 else 1.6)
	if not active:
		velocity = Vector3.ZERO
		return
	# 入场膨胀
	if _intro_t > 0.0:
		_intro_t = maxf(_intro_t - delta, 0.0)
		var k := 1.0 - _intro_t / INTRO_TIME
		var s := lerpf(0.6, 1.0, k * k * (3.0 - 2.0 * k))
		gfx.scale = Vector3.ONE * s
		if _intro_t <= 0.0 and _p1_light:
			_p1_light.light_energy = 1.3
	velocity = Vector3.ZERO
	if phase == 1:
		_p1_behave(delta)
	else:
		_p2_behave(delta)


# ---------------------------------------------------------------- 一阶段

func _p1_behave(delta: float) -> void:
	match state:
		"idle":
			attack_cd -= delta
			if attack_cd <= 0.0 and player_alive():
				_begin_p1_attack()
		"tele":
			var k := clampf(state_t / maxf(_tele_time, 0.01), 0.0, 1.0)
			_set_core_glow(_cast_core, k)
			if state_t >= _tele_time:
				_fire_p1_attack()
		"well":
			_well_t += delta
			_update_well_visual(delta)
			_pull_player(delta)
			# 引力井期间持续打弹幕：否则玩家只看到"前摇 + 一个像盾的环"，以为 Boss 没出招
			if _well_fans < 3:
				_well_fan_t -= delta
				if _well_fan_t <= 0.0:
					_well_fans += 1
					_well_fan_t = 0.7
					var idx := _pick_other_core(_cast_core)
					_fire_fan(_core_world_pos(idx), 3, 10.0, 7.0, 22.0)
			if state_t >= WELL_TIME:
				_clear_well()
				_begin_recover(0.45)
		"recover":
			if state_t >= _recover_time:
				state = "idle"
				state_t = 0.0
				attack_cd = _p1_interval()
		_:
			state = "idle"
			state_t = 0.0


func _p1_interval() -> float:
	## 每破一核出招间隔 ×0.8
	return maxf(0.7, ATTACK_INTERVAL * pow(0.8, float(_broken_count)))


func _begin_p1_attack() -> void:
	_cast_core = _pick_next_core()
	if _cast_core < 0:
		# 兜底：核心都没了还没进二阶段（正常不会发生）
		_enter_phase2()
		return
	_cast_kind = _roll_p1_kind()
	match _cast_kind:
		"fan":
			_tele_time = TELE_FAN
		"ring":
			_tele_time = TELE_RING
		_:
			_tele_time = TELE_WELL
	_last_kind = _cast_kind
	state = "tele"
	state_t = 0.0
	_set_core_glow(_cast_core, 0.0)
	# 预警：环 / 井在地面画水纹，扇弹靠核心自发光
	var c := Vector3(_arena_center_x(), ground_y + 0.1, 0)
	if _cast_kind == "ring":
		_show_telegraph(c, 2.3, C_DEEP)
	elif _cast_kind == "well":
		_show_telegraph(c, 3.0, C_DEEP)
	Game.play_sfx("abyss", -9.0, 1.3)


func _roll_p1_kind() -> String:
	## 引力井只做「偶尔出现」：本招不重复、且整体权重最低
	var r := randf()
	var kind := "fan"
	if r < 0.45:
		kind = "fan"
	elif r < 0.8:
		kind = "ring"
	else:
		kind = "well"
	if kind == "well" and _last_kind == "well":
		kind = "ring"
	return kind


func _fire_p1_attack() -> void:
	_clear_telegraph()
	_clear_core_glow()
	if _cast_kind == "fan":
		_fire_fan(_core_world_pos(_cast_core), 3, 10.0, 7.0, 22.0)
		_begin_recover(0.35)
	elif _cast_kind == "ring":
		_spawn_ring(Vector3(_arena_center_x(), ground_y, 0.0),
			14.0, 1.25, 13.5, 0.7, C_DEEP, false)
		Game.play_sfx("tide", -2.0, 1.0)
		Game.shake(0.35)
		_begin_recover(0.45)
	else:
		_start_well()


func _begin_recover(t: float) -> void:
	state = "recover"
	state_t = 0.0
	_recover_time = t
	_clear_telegraph()
	_clear_core_glow()


# ---------------------------------------------------------------- 引力井

func _start_well() -> void:
	state = "well"
	state_t = 0.0
	_well_t = 0.0
	_well_fan_t = 0.35
	_well_fans = 0
	_cast_kind = "well"
	_clear_telegraph()
	var c := Vector3(_arena_center_x(), ground_y + 0.2, 0.0)
	_spawn_well_visual(c)
	Game.play_sfx("abyss", -1.0, 1.1)
	Game.shake(0.45)
	_tip("海眼引力 · 冲刺或混天绫可挣脱")


func _spawn_well_visual(c: Vector3) -> void:
	_clear_well()
	var parent := get_parent()
	if parent == null:
		return
	_well_node = Node3D.new()
	_well_node.name = "GravityWell"
	parent.add_child(_well_node)
	_well_node.global_position = c
	_well_rings = []
	# 引力井做成"地面漩涡"，而不是竖着套在 Boss 身上的环：
	# 之前竖环 + 圆心和 Boss 本体重叠，看起来像 Boss 给自己加了个盾。
	for i in 2:
		var torus := TorusMesh.new()
		torus.inner_radius = 3.4 - i * 0.8
		torus.outer_radius = 3.7 - i * 0.8
		torus.ring_segments = 48
		torus.rings = 8
		var m := Game.std_mat(Color(0.4, 0.85, 1.0, 0.65),
			Color(0.32, 0.8, 1.0), 2.0, 0.25)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := Game.add_mesh(_well_node, torus, m, Vector3(0, 0.12, 0),
			Vector3.ZERO)
		_well_rings.append(mi)
	var core := SphereMesh.new()
	core.radius = 0.32
	core.height = 0.64
	core.radial_segments = 16
	core.rings = 10
	Game.add_mesh(_well_node, core,
		Game.std_mat(Color(0.55, 0.95, 1.0), Color(0.45, 0.92, 1.0), 2.2, 0.2),
		Vector3(0, 0.45, 0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 0.85, 1.0)
	light.light_energy = 2.2
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.8, 0)
	_well_node.add_child(light)
	# 引力井是"吸力"不是"护盾"：加向内流动的粒子 + 文字标签，避免被误读成 Boss 加盾
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 1.1
	p.position = Vector3(0, 1.4, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 3.2
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.1
	pm.gravity = Vector3.ZERO
	pm.radial_accel_min = -7.0
	pm.radial_accel_max = -12.0
	pm.color = Color(0.5, 0.85, 1.0, 0.7)
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.05
	dm.height = 0.1
	dm.radial_segments = 4
	dm.rings = 2
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.6, 0.9, 1.0, 0.85)
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.material = dmat
	p.draw_pass_1 = dm
	_well_node.add_child(p)
	var lbl := Label3D.new()
	lbl.text = "海眼引力"
	lbl.font_size = 54
	lbl.pixel_size = 0.011
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 2.0, 0)
	lbl.modulate = Color(0.65, 0.92, 1.0)
	lbl.outline_size = 10
	lbl.outline_modulate = Color(0.02, 0.05, 0.1)
	_well_node.add_child(lbl)
	Game.burst(parent, c + Vector3(0, 1.2, 0), C_DEEP, 20, 6.0, 0.1, 0.6)


func _tip(text: String) -> void:
	## 轻量提示：通过关卡的 HUD 显示一句机制说明（Boss 自身不持有 HUD）
	var lv := get_parent()
	if lv == null:
		return
	var h = lv.get("hud")
	if h and h.has_method("show_message"):
		h.call("show_message", text, 1.6, 34)


func _update_well_visual(delta: float) -> void:
	if _well_node == null or not is_instance_valid(_well_node):
		return
	var k := clampf(state_t / WELL_TIME, 0.0, 1.0)
	_well_node.scale = Vector3.ONE * (0.7 + 0.45 * sin(k * PI))
	for i in _well_rings.size():
		var r: MeshInstance3D = _well_rings[i]
		if r == null or not is_instance_valid(r):
			continue
		# 地面漩涡：只绕 Y 轴转。绕 Z 会把水平环转成竖环，
		# 从侧面看就成了一条横贯屏幕的"光柱"，完全没有漩涡感。
		r.rotation.y += delta * (1.6 + i * 0.8)


func _pull_player(delta: float) -> void:
	## 场地中心吸力：直接用外部力接口（player.gd 里专门给海眼引力井留的钩子）
	if not player_alive():
		return
	var center := Vector3(_arena_center_x(), ground_y + 1.2, 0.0)
	var d := center - player.global_position
	var flat := Vector2(d.x, d.y)
	if flat.length() < 0.7:
		return
	var pull := Vector3(d.x, d.y * 0.7, 0.0).normalized() \
		* WELL_STRENGTH * delta
	if player.has_method("apply_external_force"):
		player.apply_external_force(pull)
	else:
		player.velocity += pull
	if player.has_method("apply_slow"):
		player.apply_slow(0.35, 0.1)


func _clear_well() -> void:
	if _well_node and is_instance_valid(_well_node):
		_well_node.queue_free()
	_well_node = null
	_well_rings = []
	_well_t = 0.0
	_well_fan_t = 0.0


# ---------------------------------------------------------------- 二阶段

func _enter_phase2() -> void:
	phase = 2
	hp = P2_HP
	state = "p2_idle"
	state_t = 0.0
	attack_cd = 1.2
	_p2_seq_i = 0
	_p2_glow = 0.0
	_cast_core = -1
	_cast_kind = ""
	_broken_count = 3
	_contact_cd = 0.0
	_clear_telegraph()
	_clear_well()
	_clear_core_glow()
	# 一阶段外观退场 / 二阶段巨瞳登场
	if _core_root and is_instance_valid(_core_root):
		_core_root.visible = false
	for core in _cores:
		if core == null or not is_instance_valid(core):
			continue
		core.collision_layer = 0
		core.visible = false
		core.set_process(false)
	if _p1_root and is_instance_valid(_p1_root):
		_p1_root.visible = false
	if _p2_root and is_instance_valid(_p2_root):
		_p2_root.visible = true
	if _hurtbox and is_instance_valid(_hurtbox):
		_hurtbox.set_active(true)
	if _p2_particles:
		_p2_particles.emitting = true
	if _eye_mat:
		_eye_mat.albedo_color = Color(0.7, 0.86, 1.0)
		_eye_mat.emission = Color(0.66, 0.36, 1.0)
		_eye_mat.emission_energy_multiplier = 2.2
	if _iris_mat:
		_iris_mat.emission = Color(0.72, 0.52, 1.0)
	set_rim_color(C_RIM_P2)
	if _p2_light:
		_p2_light.light_color = Color(0.62, 0.4, 1.0)
		_p2_light.light_energy = 2.0
	Game.play_sfx("roar", 2.0, 0.75)
	Game.play_sfx("abyss", 0.0, 0.9)
	Game.shake(1.2)
	Game.hitstop(0.32, 0.1)
	var parent := get_parent()
	if parent:
		Game.burst(parent, global_position, Color(0.7, 0.45, 1.0), 60, 12.0,
			0.15, 1.1)
		Game.burst(parent, global_position, C_WHITE, 40, 9.0, 0.12, 0.9)
		Game.spawn_dmg_text(parent, global_position + Vector3(0, 3.2, 0),
			"海眼开阖", Color(0.8, 0.62, 1.0), true)
	_tip("海眼重凝 · 击破巨瞳")
	boss_hp_changed.emit(hp, max_hp)


func _p2_behave(delta: float) -> void:
	_update_p2_visual(delta)
	# 巨瞳本体的接触压迫（别贴脸站桩）
	if player_alive() and _contact_cd <= 0.0:
		var d := player.global_position - global_position
		if absf(d.x) < 2.1 and d.y > -3.2 and d.y < 2.2:
			_contact_cd = P2_CONTACT_CD
			player.take_damage(P2_CONTACT_DMG, global_position.x)
	match state:
		"p2_idle":
			attack_cd -= delta
			if attack_cd <= 0.0 and player_alive():
				_begin_p2_attack()
		"p2_tele":
			_p2_glow = clampf(state_t / maxf(_tele_time, 0.01), 0.0, 1.0)
			if state_t >= _tele_time:
				_fire_p2_attack()
		"p2_recover":
			if state_t >= _recover_time:
				state = "p2_idle"
				state_t = 0.0
				attack_cd = P2_IDLE_CD
		_:
			state = "p2_idle"
			state_t = 0.0


func _update_p2_visual(delta: float) -> void:
	if _p2_root == null or not is_instance_valid(_p2_root):
		return
	# 呼吸
	var s := 1.0 + sin(_t * 1.4) * 0.02
	_p2_root.scale = Vector3.ONE * s
	# 瞳孔追随玩家（2.5D 侧视：y 分量压低，避免翻白眼）
	if player_alive() and _pupil and is_instance_valid(_pupil):
		var d := player.global_position + Vector3(0, 1.0, 0) - global_position
		var target := Vector3(clampf(d.x * 0.12, -0.8, 0.8),
			clampf(d.y * 0.1, -0.5, 0.5), 1.45)
		_pupil.position = _pupil.position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	# 三层符环旋转
	for i in _p2_rings.size():
		var r: MeshInstance3D = _p2_rings[i]
		if r == null or not is_instance_valid(r):
			continue
		r.rotation.y += delta * (0.7 + 0.4 * float(i))
		r.rotation.x += delta * (0.3 + 0.22 * float(i))
	# 预警：瞳孔 / 巨瞳自发光升高
	if _eye_mat:
		_eye_mat.emission_energy_multiplier = 1.4 + _p2_glow * 2.2
	if _iris_mat:
		_iris_mat.emission_energy_multiplier = 2.0 + _p2_glow * 2.5
	if _p2_light:
		_p2_light.light_energy = 1.8 + _p2_glow * 2.2


func _begin_p2_attack() -> void:
	## 二阶段固定循环：潮涌环 → 水弹扇 → 海眼脉冲 → 水弹扇
	var seq := ["ring", "fan", "pulse", "fan"]
	_cast_kind = seq[_p2_seq_i % seq.size()]
	_p2_seq_i += 1
	match _cast_kind:
		"ring":
			_tele_time = TELE_P2_RING
		"fan":
			_tele_time = TELE_P2_FAN
		_:
			_tele_time = TELE_P2_PULSE
	state = "p2_tele"
	state_t = 0.0
	_p2_glow = 0.0
	var c := Vector3(_arena_center_x(), ground_y + 0.1, 0.0)
	if _cast_kind == "ring":
		_show_telegraph(c, 2.4, C_DEEP)
		Game.play_sfx("tide", -6.0, 0.85)
	elif _cast_kind == "pulse":
		_show_telegraph(c, 2.8, C_PULSE)
		Game.play_sfx("abyss", -4.0, 1.15)
	else:
		Game.play_sfx("shoot", -9.0, 0.7)


func _fire_p2_attack() -> void:
	_clear_telegraph()
	var c := Vector3(_arena_center_x(), ground_y, 0.0)
	match _cast_kind:
		"ring":
			# 潮涌环：贴地水墙，单次判定 16，单跳 / 摆荡可躲
			_spawn_ring(c, 16.0, 1.25, 15.0, 0.8, C_DEEP, false)
			Game.play_sfx("tide", 0.0, 1.05)
			Game.shake(0.6)
			_begin_p2_recover(0.5)
		"pulse":
			# 海眼脉冲：紫色全场冲击波，判定高度 2.6 → 必须二段跳 / 摆荡
			_spawn_ring(c, 20.0, PULSE_HEIGHT, 26.0, PULSE_EXPAND,
				C_PULSE, true)
			Game.play_sfx("abyss", 2.0, 0.9)
			Game.play_sfx("tide", -3.0, 0.7)
			Game.shake(0.95)
			_begin_p2_recover(0.7)
		_:
			_fire_fan(global_position + Vector3(0, 0.3, 0), 5, 10.0, 7.6, 40.0)
			_begin_p2_recover(0.5)
	_p2_glow = 0.0


func _begin_p2_recover(t: float) -> void:
	state = "p2_recover"
	state_t = 0.0
	_recover_time = t
	_clear_telegraph()


# ================================================================ 招式实现

func _fire_fan(origin: Vector3, n: int, dmg: float, spd: float,
		spread_deg: float) -> void:
	## 扇形水弹：复用 Projectile，全部朝玩家方向散开
	var parent := get_parent()
	if parent == null or not player_alive():
		return
	Game.play_sfx("shoot", -5.0, 0.8)
	var to_p := (player.global_position + Vector3(0, 1.0, 0) - origin)
	if to_p.length() < 0.1:
		to_p = Vector3(1, 0, 0)
	to_p = to_p.normalized()
	var base_a := atan2(to_p.y, to_p.x)
	for i in n:
		var a := base_a + deg_to_rad(-spread_deg + 2.0 * spread_deg *
			float(i) / maxf(float(n - 1), 1.0))
		var proj := Projectile.new()
		proj.dmg = dmg
		proj.tint = C_DEEP
		proj.life = 4.0
		proj.vel = Vector3(cos(a), sin(a), 0.0) * spd
		parent.add_child(proj)
		proj.global_position = origin + proj.vel.normalized() * 1.1
		_projectiles.append(proj)


func _spawn_ring(center: Vector3, dmg: float, height: float,
		max_radius: float, expand_time: float, col: Color,
		with_disc: bool) -> void:
	## 潮涌环 / 海眼脉冲：自定义 Area3D 水墙，半径随时间放大，单次判定
	var parent := get_parent()
	if parent == null:
		return
	if _rings.size() > 12:
		_prune_rings()
	var r = TideRing.new()
	r.setup_ring(center, dmg, height, max_radius, expand_time, col, with_disc)
	parent.add_child(r)
	r.global_position = center
	_rings.append(r)


func _prune_rings() -> void:
	var alive: Array = []
	for r in _rings:
		if r != null and is_instance_valid(r):
			alive.append(r)
	_rings = alive


func _clear_rings() -> void:
	for r in _rings:
		if r != null and is_instance_valid(r):
			r.queue_free()
	_rings = []


func _clear_projectiles() -> void:
	for p in _projectiles:
		if p != null and is_instance_valid(p):
			p.queue_free()
	_projectiles = []


func _show_telegraph(pos: Vector3, radius: float, col: Color) -> void:
	## 地面水纹预警：贴地 TorusMesh 呼吸发光
	_clear_telegraph()
	var parent := get_parent()
	if parent == null:
		return
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.86
	torus.outer_radius = radius
	torus.ring_segments = 40
	torus.rings = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.42)
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph = MeshInstance3D.new()
	_telegraph.mesh = torus
	_telegraph.material_override = mat
	_telegraph.position = pos
	_telegraph.scale = Vector3(1.0, 0.16, 1.0)
	parent.add_child(_telegraph)
	var tw := _telegraph.create_tween()
	tw.set_loops()
	tw.tween_property(mat, "emission_energy_multiplier", 4.8, 0.16)
	tw.tween_property(mat, "emission_energy_multiplier", 1.5, 0.16)


func _clear_telegraph() -> void:
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


# ================================================================ 破核 / 阶段切换

func take_damage_on_core(index: int, dmg: float, dir: float,
		heavy := false) -> void:
	## 三核受击转发：扣总血 + 飘字 + 通知 HUD；破核由 Sealoore 自己负责
	if not active or dead or phase != 1:
		return
	hp = maxf(hp - dmg, 0.0)
	var parent := get_parent()
	if parent:
		Game.spawn_dmg_text(parent, _core_world_pos(index) + Vector3(0, 1.1, 0),
			str(int(dmg)),
			Color(1.0, 0.85, 0.4) if heavy else Color(0.62, 0.95, 1.0),
			heavy)
	boss_hp_changed.emit(hp, max_hp)
	# 三核伤害总和 = 总血 540，所以「最后一核碎」时 hp 恰好归零，
	# 这是阶段切换信号而不是死亡：紧接着 on_core_broken → _enter_phase2 会重凝。


func on_core_broken(index: int, world_pos: Vector3) -> void:
	if phase != 1:
		return
	_broken_count += 1
	_cast_core = -1
	state = "recover"
	state_t = 0.0
	_recover_time = 0.8
	_clear_telegraph()
	_clear_well()
	Game.shake(0.7)
	Game.hitstop(0.16, 0.12)
	Game.play_sfx("abyss", -1.0, 1.05)
	var parent := get_parent()
	if parent:
		Game.spawn_dmg_text(parent, world_pos + Vector3(0, 1.4, 0),
			"封印 %d/3 破" % _broken_count, C_DEEP, true)
	# 剩余核心转速提升
	for core in _cores:
		if core == null or not is_instance_valid(core):
			continue
		if not core.broken:
			core.spin = 1.0 + 0.5 * float(_broken_count)
	if _broken_count >= 3:
		_enter_phase2()
	elif hp <= 0.0:
		# 数值兜底（正常路径打不出来）：还有核心没碎却先 0 血时留一半，别卡死
		hp = CORE_MAX_HP * 0.5
		boss_hp_changed.emit(hp, max_hp)


# ================================================================ 生死 / 重置

func take_damage(dmg: float, dir: float, heavy := false) -> void:
	## 一阶段本体不可击破（只做视觉反馈）；二阶段巨瞳 hurtbox 打到才真正扣血
	if dead or not active:
		return
	if phase == 1:
		if _p1_root and is_instance_valid(_p1_root):
			Game.flash_meshes(_p1_root, Color(0.7, 0.95, 1.0), 0.05)
		return
	hp = maxf(hp - dmg, 0.0)
	hurt_t = 0.22
	Game.flash_meshes(gfx, Color(1.0, 0.92, 1.0))
	var parent := get_parent()
	if parent:
		Game.spawn_dmg_text(parent, global_position + Vector3(0, 2.4, 0),
			str(int(dmg)),
			Color(1.0, 0.6, 0.15) if heavy else Color(1.0, 0.85, 0.4), heavy)
	boss_hp_changed.emit(hp, max_hp)
	if hp <= 0.0:
		die()


func die() -> void:
	## 不走 EnemyBase.die()（那是小怪掉落逻辑）：爆发 + 缩小消散
	if dead:
		return
	dead = true
	active = false
	hp = 0.0
	_clear_telegraph()
	_clear_well()
	_clear_rings()
	_clear_projectiles()
	if _hurtbox and is_instance_valid(_hurtbox):
		_hurtbox.set_active(false)
	for core in _cores:
		if core == null or not is_instance_valid(core):
			continue
		core.collision_layer = 0
	boss_hp_changed.emit(0.0, max_hp)
	Game.play_sfx("boss_die", 2.0)
	Game.play_sfx("abyss", 1.0, 0.7)
	Game.shake(1.6)
	Game.hitstop(0.5, 0.12)
	var center := global_position
	var parent := get_parent()
	if parent:
		for i in 5:
			Game.burst(parent, center + Vector3(randf_range(-1.6, 1.6),
				randf_range(-1.2, 1.6), 0), Color(0.7, 0.45, 1.0),
				40, 11.0, 0.15, 1.2)
		Game.burst(parent, center, Color(1.0, 0.92, 0.7), 60, 13.0, 0.12, 1.4)
	boss_defeated.emit()
	if gfx:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(gfx, "scale", Vector3(0.05, 0.05, 0.05), 1.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(self, "global_position:y", ground_y + 0.6, 1.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(queue_free)
	else:
		queue_free()


func reset_fight() -> void:
	## 玩家阵亡后完整重置：回满 540、三核复活、二阶段状态清空、清掉所有弹幕/水环/预警
	if dead:
		return
	active = false
	hp = max_hp
	phase = 1
	state = "dormant"
	state_t = 0.0
	attack_cd = ATTACK_INTERVAL
	_intro_t = 0.0
	_broken_count = 0
	_cast_core = -1
	_cast_kind = ""
	_last_kind = ""
	_p2_seq_i = 0
	_p2_glow = 0.0
	_tele_time = 0.7
	_recover_time = 0.4
	_contact_cd = 0.0
	_well_t = 0.0
	_well_fan_t = 0.0
	_clear_telegraph()
	_clear_well()
	_clear_rings()
	_clear_projectiles()
	global_position = home_pos
	velocity = Vector3.ZERO
	if gfx:
		gfx.position = Vector3.ZERO
		gfx.rotation = Vector3.ZERO
		gfx.scale = Vector3.ONE
	# 外观复位（所有引用逐个判空）
	if _p1_root and is_instance_valid(_p1_root):
		_p1_root.visible = true
	if _p2_root and is_instance_valid(_p2_root):
		_p2_root.visible = false
	if _p1_ring and is_instance_valid(_p1_ring):
		_p1_ring.rotation = Vector3.ZERO
	if _p1_light:
		_p1_light.light_color = Color(0.4, 0.85, 1.0)
		_p1_light.light_energy = 1.3
	if _eye_mat:
		_eye_mat.albedo_color = Color(0.68, 0.9, 1.0)
		_eye_mat.emission = Color(0.6, 0.42, 1.0)
		_eye_mat.emission_energy_multiplier = 1.2
	if _iris_mat:
		_iris_mat.emission = Color(0.65, 0.5, 1.0)
		_iris_mat.emission_energy_multiplier = 2.0
	if _pupil and is_instance_valid(_pupil):
		_pupil.position = Vector3(0, 0, 1.45)
	for mi in _p2_rings:
		if mi != null and is_instance_valid(mi):
			mi.rotation = Vector3.ZERO
	if _p2_light:
		_p2_light.light_color = Color(0.6, 0.42, 1.0)
		_p2_light.light_energy = 1.5
	if _hurtbox and is_instance_valid(_hurtbox):
		_hurtbox.set_active(false)
	if _p2_particles:
		_p2_particles.emitting = false
	if _core_root and is_instance_valid(_core_root):
		_core_root.visible = true
	for core in _cores:
		if core == null or not is_instance_valid(core):
			continue
		core.reset_core()
	_sync_arena()
	_layout_cores()
	set_rim_color(C_PEARL)
	boss_hp_changed.emit(hp, max_hp)


# ================================================================ 内部类：封印之瞳

class Sealoore extends Area3D:
	## 一阶段可受击目标：珍珠青白发光球 + 反旋符文环 + 碰撞球
	## 受击把伤害转发给 Boss（boss.take_damage_on_core），血量归零后自己爆裂隐藏。
	var boss = null                 # BossSeaEye（不强类型，避免自引用问题）
	var index := 0
	var max_hp := 180.0
	var hp := 180.0
	var broken := false
	var base_local := Vector3.ZERO
	var spin := 1.0
	var bob_phase := 0.0

	var mat: StandardMaterial3D = null
	var rune_mat: StandardMaterial3D = null
	var light: OmniLight3D = null
	var _core_inner: MeshInstance3D = null
	var _shell_holder: Node3D = null
	var _rune_holder: Node3D = null
	var _rune_a: MeshInstance3D = null
	var _rune_b: MeshInstance3D = null
	var _t := 0.0
	var _glow := 0.0


	func setup_core(b, idx: int, yaw_off: float) -> void:
		boss = b
		index = idx
		hp = max_hp
		bob_phase = yaw_off
		collision_layer = 4
		collision_mask = 0
		monitorable = true

		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.75       # 约等于 BossSeaEye.CORE_RADIUS
		cs.shape = sph
		add_child(cs)

		# 珍珠青白主球
		mat = Game.std_mat(Color(0.42, 0.78, 0.90), Color(0.30, 0.72, 0.90), 0.9, 0.16)
		var body := SphereMesh.new()
		body.radius = 0.55
		body.height = 1.1
		body.radial_segments = 22
		body.rings = 12
		Game.add_mesh(self, body, mat, Vector3.ZERO)

		# 内芯（朝镜头，受击时最亮）
		var inner := SphereMesh.new()
		inner.radius = 0.24
		inner.height = 0.48
		inner.radial_segments = 16
		inner.rings = 10
		_core_inner = Game.add_mesh(self, inner,
			Game.std_mat(Color(0.80, 0.97, 1.0), Color(0.55, 0.9, 1.0), 1.3, 0.2),
			Vector3(0, 0, 0.24))

		# 绕自身 Y 轴转的符文片（球体本身对称，用几片符文体现自转）
		_shell_holder = Node3D.new()
		add_child(_shell_holder)
		var shard := BoxMesh.new()
		shard.size = Vector3(0.1, 0.3, 0.05)
		var shard_mat := Game.std_mat(Color(0.8, 0.98, 1.0),
			Color(0.45, 0.85, 1.0), 0.7, 0.3)
		for i in 3:
			var a := TAU * float(i) / 3.0
			Game.add_mesh(_shell_holder, shard, shard_mat,
				Vector3(cos(a) * 0.58, sin(a) * 0.12, 0.34),
				Vector3(0, 0, rad_to_deg(a)))

		# 反向旋转的符文环
		_rune_holder = Node3D.new()
		add_child(_rune_holder)
		rune_mat = Game.std_mat(Color(0.36, 0.74, 0.92), Color(0.24, 0.64, 0.90),
			0.7, 0.22)
		rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rune_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		rune_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var torus := TorusMesh.new()
		torus.inner_radius = 0.82
		torus.outer_radius = 0.98
		torus.ring_segments = 36
		torus.rings = 8
		_rune_a = Game.add_mesh(_rune_holder, torus, rune_mat, Vector3.ZERO,
			Vector3(90, 0, 0))
		_rune_b = Game.add_mesh(_rune_holder, torus, rune_mat, Vector3.ZERO,
			Vector3(90, 0, 60))

		light = OmniLight3D.new()
		light.light_color = Color(0.45, 0.9, 1.0)
		light.light_energy = 1.4
		light.omni_range = 5.0
		light.shadow_enabled = false
		add_child(light)
		set_process(true)


	func _process(delta: float) -> void:
		_t += delta
		if broken:
			return
		# 上下浮动 ±0.15
		position = base_local + Vector3(0, sin(_t * 1.1 + bob_phase) * 0.15, 0)
		# 自转 / 符环反旋（破核越多转越快，由 boss 调 spin）
		if _shell_holder and is_instance_valid(_shell_holder):
			_shell_holder.rotation.y += delta * 0.9 * spin
		if _rune_holder and is_instance_valid(_rune_holder):
			_rune_holder.rotation.y -= delta * 1.5 * spin
		if _rune_a and is_instance_valid(_rune_a):
			_rune_a.rotation.z -= delta * 1.9 * spin
		if _rune_b and is_instance_valid(_rune_b):
			_rune_b.rotation.z += delta * 1.4 * spin
		if _core_inner and is_instance_valid(_core_inner):
			var s := 1.0 + sin(_t * 2.4) * 0.06
			_core_inner.scale = Vector3.ONE * s


	func set_glow(c: float) -> void:
		## 蓄力预警：破核前核心越来越亮
		_glow = clampf(c, 0.0, 1.2)
		if mat:
			mat.emission_energy_multiplier = 2.2 + _glow * 5.0
		if rune_mat:
			rune_mat.emission_energy_multiplier = 3.2 + _glow * 4.0
		if light:
			light.light_energy = 1.4 + _glow * 4.0


	func take_damage(dmg: float, dir: float, heavy := false) -> void:
		## 玩家 hitbox 命中入口（layer4 被 intersect_shape 找到，必须叫这个名字）
		if broken or hp <= 0.0:
			return
		if boss == null or not is_instance_valid(boss):
			return
		if not bool(boss.active) or bool(boss.dead) or int(boss.phase) != 1:
			return
		var actual: float = minf(dmg, hp)
		if actual <= 0.0:
			return
		hp -= actual
		boss.take_damage_on_core(index, actual, dir, heavy)
		Game.flash_meshes(self, Color(1.0, 1.0, 1.0), 0.07)
		Game.play_sfx("hit", -7.0, 1.35)
		if hp <= 0.0:
			_shatter()


	func _shatter() -> void:
		if broken:
			return
		broken = true
		hp = 0.0
		collision_layer = 0     # 碎裂后不再被玩家攻击命中
		set_glow(0.0)
		var fx_parent: Node = null
		if boss and is_instance_valid(boss):
			fx_parent = boss.get_parent()
		if fx_parent and is_instance_valid(fx_parent):
			Game.burst(fx_parent, global_position, Color(0.78, 0.98, 1.0),
				46, 9.0, 0.13, 0.9)
			Game.burst(fx_parent, global_position, Color(0.38, 0.84, 1.0),
				26, 5.5, 0.1, 0.6)
		Game.play_sfx("tide", -2.0, 1.1)
		Game.play_sfx("heavy", -6.0, 1.35)
		if boss and is_instance_valid(boss):
			boss.on_core_broken(index, global_position)
		visible = false


	func reset_core() -> void:
		broken = false
		hp = max_hp
		visible = true
		collision_layer = 4
		monitorable = true
		_t = 0.0
		spin = 1.0
		position = base_local
		rotation = Vector3.ZERO
		if _shell_holder and is_instance_valid(_shell_holder):
			_shell_holder.rotation = Vector3.ZERO
		if _rune_holder and is_instance_valid(_rune_holder):
			_rune_holder.rotation = Vector3.ZERO
		if _rune_a and is_instance_valid(_rune_a):
			_rune_a.rotation = Vector3(deg_to_rad(90), 0, 0)
		if _rune_b and is_instance_valid(_rune_b):
			_rune_b.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(60))
		set_glow(0.0)
		set_process(true)


# ================================================================ 内部类：巨瞳受击球

class EyeHurtbox extends Area3D:
	## 二阶段巨瞳的可受击球：一阶段 layer=0 完全不可打
	var boss = null


	func setup_hurtbox(b, radius: float) -> void:
		boss = b
		collision_layer = 0
		collision_mask = 0
		monitorable = true
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = radius
		cs.shape = sph
		add_child(cs)


	func set_active(on: bool) -> void:
		collision_layer = 4 if on else 0


	func take_damage(dmg: float, dir: float, heavy := false) -> void:
		if boss == null or not is_instance_valid(boss):
			return
		boss.take_damage(dmg, dir, heavy)


# ================================================================ 内部类：潮涌环 / 海眼脉冲

class TideRing extends Area3D:
	## 自定义 Area3D 环形水墙：圆环 mesh 放大 + 判定一次
	## 贴地环 height≈1.25（单跳可躲）；海眼脉冲 height=2.6（必须二段跳 / 摆荡）
	var dmg := 14.0
	var height := 1.25
	var max_radius := 14.0
	var expand_time := 0.75
	var ring_color := Color(0.4, 0.9, 1.0)
	var center := Vector3.ZERO
	var with_disc := false

	var _radius := 0.35
	var _t := 0.0
	var _hit := false
	var _cyl: CylinderShape3D = null
	var _ring: MeshInstance3D = null
	var _disc: MeshInstance3D = null
	var _mat: StandardMaterial3D = null


	func setup_ring(c: Vector3, dmg_v: float, h: float, r_max: float,
			t_exp: float, col: Color, disc: bool) -> void:
		center = c
		dmg = dmg_v
		height = h
		max_radius = r_max
		expand_time = maxf(t_exp, 0.1)
		ring_color = col
		with_disc = disc
		collision_layer = 0
		collision_mask = 2       # 只找玩家
		monitoring = true
		monitorable = true

		# 碰撞体：从地面长到 height 的圆柱，半径随时间放大
		var cs := CollisionShape3D.new()
		_cyl = CylinderShape3D.new()
		_cyl.radius = 0.35
		_cyl.height = maxf(height, 0.2)
		cs.shape = _cyl
		cs.position.y = maxf(height, 0.2) * 0.5
		add_child(cs)

		_mat = Game.std_mat(Color(ring_color.r, ring_color.g, ring_color.b, 0.85),
			ring_color, 2.6, 0.25)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var torus := TorusMesh.new()
		torus.inner_radius = 0.94
		torus.outer_radius = 1.0
		torus.ring_segments = 48
		torus.rings = 8
		_ring = Game.add_mesh(self, torus, _mat, Vector3(0, 0, 0))
		if with_disc:
			var d := CylinderMesh.new()
			d.top_radius = 1.0
			d.bottom_radius = 1.0
			d.height = 0.04
			d.radial_segments = 40
			_disc = Game.add_mesh(self, d, _mat, Vector3(0, 0.02, 0))


	func _physics_process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / expand_time, 0.0, 1.0)
		_radius = lerpf(0.35, max_radius, k)
		if _cyl:
			_cyl.radius = _radius
		if _ring:
			# 环带横向放大到 _radius，纵向拉成"水墙"
			var y_scale := maxf(height, 0.2) * 30.0
			_ring.scale = Vector3(_radius, y_scale, _radius)
			_ring.position.y = height * 0.5
		if _disc:
			_disc.scale = Vector3(_radius, 1.0, _radius)
		# 单次判定：环形水墙扫到玩家（没跳够高才吃伤害）
		if not _hit:
			for b in get_overlapping_bodies():
				if b is Player:
					var p := (b as Node3D).global_position
					if p.y < center.y + height:
						_hit = true
						var pl := b as Player
						pl.take_damage(dmg, center.x)
						Game.burst(get_parent(),
							p + Vector3(0, 1.0, 0), ring_color, 16, 4.5,
							0.08, 0.45)
					break
		# 扩散结束后淡出
		if _t >= expand_time:
			var fade_k := clampf((_t - expand_time) / 0.4, 0.0, 1.0)
			if _mat:
				_mat.albedo_color.a = 0.85 * (1.0 - fade_k)
				_mat.emission_energy_multiplier = 2.6 * (1.0 - fade_k)
			if fade_k >= 1.0:
				queue_free()

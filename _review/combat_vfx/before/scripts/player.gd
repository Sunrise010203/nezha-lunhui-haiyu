class_name Player
extends CharacterBody3D
## 哪吒：移动 / 二段跳 / 冲刺（无敌帧）/ 三连击 / 重击 / 三昧真火

signal hp_changed(hp: float, max_hp: float)
signal energy_changed(energy: float, max_energy: float)
signal hit_landed(count: int)
signal died
signal runes_changed(v: float, max_v: float)

const CharLook := preload("res://scripts/char_look.gd")
const NezhaMotion := preload("res://scripts/nezha_motion.gd")

const L_WORLD := 1
const L_ENEMY := 4

const MAX_HP := 100.0
const MAX_ENERGY := 100.0
const SPEED := 7.2
const ACCEL_GROUND := 48.0
const ACCEL_AIR := 28.0
const JUMP_V := 11.8
const GRAVITY := 32.0
const DASH_SPEED := 17.0
const DASH_TIME := 0.18
const DASH_CD := 0.75
const SKILL_COST := 50.0
const SKILL2_COST := 25.0
const SKILL3_COST := 60.0
const WHEEL_TIME := 5.0        # 腾空后强化下砸的窗口（落地即结束）
const RING_CHARGE_MAX := 1.0   # 乾坤圈蓄力上限（秒）
const RING_CHARGE_DMG := 9.0   # 蓄满额外伤害：dmg = 基础 + 蓄力秒数 * 9

# ---------------------------------------------------------------- 第四章：定潮
const TIDE_PARRY_WINDOW := 0.30   # 按下后总防护窗口（原 0.20，实机弹反成功率太低）
const TIDE_PERFECT := 0.10        # 命中前 0.10s 内的"提前量"才算完美
const TIDE_CD := 0.40             # 空挥冷却
const TIDE_REUSE_LOCK := 0.20     # 成功弹反后不可再弹
const TIDE_MOVE_LOCK := 0.10      # 收招硬直（不可移动）
const TIDE_RUNE_MAX := 3.0        # 潮纹上限
const TIDE_HOLD_FOR_PULL := 0.20  # 按住超过此时长 → 进入引潮
const TIDE_PULL_RADIUS := 8.0
const TIDE_PULL_COS := 0.5        # cos(60°)：正面 120° 锥角
const TIDE_GUARD_COS := 0.2588    # cos(75°)：水膜拦截锥角（比引潮宽）
const TIDE_GUARD_RADIUS := 3.4    # 水膜拦截半径（原 2.6）
const TIDE_PULL_TIME := 1.2
const TIDE_PULL_MAX := 6
const TIDE_PULL_COST := 20.0      # 灵力
const TIDE_PULL_HOVER := 2.2
const REFLECT_DMG := 20.0
const REFLECT_DMG_PERFECT := 30.0
const VOLLEY_DMG := 14.0
const VOLLEY_SPEED := 22.0
const PARRY_BREAK_TIME := 2.0     # 完美「架」出的破绽窗口（期间受伤 ×1.6）
# 潮纹收入（只由攻击命中赚）
const RUNE_LIGHT := 0.15
const RUNE_HEAVY := 0.35
const RUNE_SLAM := 0.30
const RUNE_SKILL := 0.20
const RUNE_SWING_CAP := 0.30      # 单次挥击最多攒多少
const RUNE_CAST_CAP := 0.60       # 单次施法最多攒多少
# Standard Y-up glTF, with Mixamo motions retargeted to the ARP deform skeleton.
const MODEL_PATH := "res://art/models/nezha_arp.glb"
# The new model has no baked foot wheel; its soles rest at y=0.
const MODEL_LIFT := 0.0
# 圈再相对模型额外下压（一般保持 0：轮子的下移量已经在 Blender 里烘焙好了）
const RING_DROP := 0.0

var hp := MAX_HP
var energy := 30.0
var facing := 1.0
var act := "free"   # free / ... / swing / pull / charge_ring
var wheel_t := 0.0          # 风火轮强化窗口剩余时间
var _wheel_airborne := false
var _wheel_trail_t := 0.0
var _wheel_hold: Node3D
var _wheel_fx: Array[MeshInstance3D] = []
var _ring_charge := 0.0     # 乾坤圈蓄力秒数
var _ring_charging := false
var _ring_charge_fx := 0.0
var _slow_amount := 0.0     # 海眼引力井减速（关卡写入，逐渐恢复）
var _slow_t := 0.0
var _ring_out := false
var _pd_done := false      # 本次冲刺是否已触发完美闪身
var _foot_ring: Node3D = null  # 旧方案拆出的脚环网格；现在模型里没有这个节点，留作兼容
var _foot_ring_base := Vector3.ZERO
var _ghost_t := 0.0
var act_t := 0.0
var act_hit_done := false
var attack_queued := false
var combo_cd := 0.0

# ---- 混天绫（第三章新机制）
const SWING_RANGE := 10.0        # 锚点搜索半径
const SWING_MIN_LEN := 3.5
const SWING_MAX_LEN := 8.0
const SWING_MAX_TIME := 4.0
const SWING_INPUT_ACCEL := 5.2   # 左右键给的角加速度
const GRAPPLE_ENEMY_RANGE := 6.0
const GRAPPLE_COST_BIG := 15.0
const GRAPPLE_COST_SMALL := 20.0
const GRAPPLE_CD := 2.0
var _swing_pivot := Vector3.ZERO
var _swing_len := 6.0
var _swing_omega := 0.0
var _swing_t := 0.0
var _swing_cd := 0.0
var _swing_drop_pending := false   # 松开 F 后延迟脱手：给"再按一次 F 换锚点"留窗口
var _swing_drop_t := 0.0
var _grapple_cd := 0.0
var _pull_dir := 1.0
var _tether_t := 0.0
var _tether_to := Vector3.ZERO
var _tether_follow: Node3D = null
var _tether_mesh: ImmediateMesh
var tether: MeshInstance3D
var _external_vel := Vector3.ZERO   # 关卡外力（海眼引力井等），每帧末清空

var coyote := 0.0
var jump_buffer := 0.0
var air_jumps := 1
var dash_t := 0.0
var dash_cd_t := 0.0
var air_dash_used := false
var invuln := 0.0
var was_airborne := false

# ---- 第四章：定潮状态 ----
var tide_runes := 3.0          # 潮纹（0~3），只靠攻击命中赚
var _tide_hold_t := 0.0        # 本次按住的时长
var _tide_guard_t := 0.0       # 剩余防护窗口
var _tide_cd_t := 0.0
var _tide_reuse_t := 0.0
var _tide_move_lock_t := 0.0
var _guard_blend := 0.0        # 0~1 叠加层权重
var _guard_mode := "neutral"   # neutral / front / cross
var _guard_mode_t := 0.0
var _pulling := false
var _pull_t := 0.0
var _pull_list: Array = []
var _rune_swing_gain := 0.0
var _rune_cast_gain := 0.0
var _tide_fx: Array[MeshInstance3D] = []
var _tide_fx_root: Node3D = null
var _parry_flash_t := 0.0
var _pull_player: AudioStreamPlayer = null

var gfx: Node3D
var spear: Node3D
var ring: MeshInstance3D
var ribbon_l: MeshInstance3D
var ribbon_r: MeshInstance3D
var wheel_f: MeshInstance3D
var wheel_b: MeshInstance3D
var wheel_glow: GPUParticles3D
var _anim_time := 0.0
var _target_yaw := 0.0
# AI 3D 模型 / 立绘精灵模式
var model: Node3D = null
var skel: Skeleton3D = null
var _motion: RefCounted
var _bones := {}          # 骨骼名 -> 索引
var _pose_cur := {}       # 骨骼名 -> 当前欧拉角（平滑过渡用）
var use_sprites := false
var sprite: Sprite3D
var _tex_idle: Texture2D
var _tex_run: Texture2D
var _tex_attack: Texture2D
var _tex_jump: Texture2D
const SPRITE_H := 2.0

const C_FIRE := Color(1.0, 0.55, 0.15)
const C_GOLD := Color(0.95, 0.75, 0.3)


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = L_WORLD
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.5
	col.shape = cap
	col.position.y = 0.85
	add_child(col)
	_build_gfx()
	_build_tether()
	_build_wheel()
	# 引潮的吸气声是循环资源：play_sfx 的固定池拿不到句柄停不下来，所以给专用播放器
	if ResourceLoader.exists("res://audio/sfx_tide_pull.res"):
		_pull_player = AudioStreamPlayer.new()
		_pull_player.stream = load("res://audio/sfx_tide_pull.res")
		_pull_player.volume_db = -9.0
		add_child(_pull_player)
	Game.attach_blob_shadow(self, 0.8, 0.60)


# ---------------------------------------------------------------- 外观

func _build_gfx() -> void:
	gfx = Node3D.new()
	add_child(gfx)

	# 优先级：AI 3D 模型 > AI 立绘精灵 > 程序化网格
	model = Game.load_model(MODEL_PATH, 2.2, 90.0, 0.0, 0.0, true, false)
	if model:
		gfx.add_child(model)
		# 整体上浮：脚不再插进乾坤圈里，视觉上"踩在/悬在圈上"
		model.position.y += MODEL_LIFT
		_build_model_equipment()
		_motion = NezhaMotion.new(model)
		# Keep the new model's own UVs and brightened PBR textures.
		CharLook.attach_lights(gfx)
		(gfx.get_node("CharKey") as OmniLight3D).light_energy = 1.6
		(gfx.get_node("CharRim") as OmniLight3D).light_energy = 0.8
		return
	_tex_idle = Game.tex("res://art/sprites/nezha_idle.png")
	if _tex_idle:
		_build_sprite_gfx()
		return

	var skin := Game.std_mat(Color(0.92, 0.74, 0.58), Color.BLACK, 1.0, 0.65)
	var red := Game.std_mat(Color(0.78, 0.13, 0.13), Color(0.5, 0.05, 0.05), 0.25, 0.55)
	var dark_hair := Game.std_mat(Color(0.07, 0.07, 0.09), Color.BLACK, 1.0, 0.4)
	var gold := Game.std_mat(C_GOLD, C_GOLD, 0.9, 0.25, 0.9)
	var fire_mat := Game.std_mat(C_FIRE, C_FIRE, 2.2, 0.4)
	var ribbon_mat := Game.std_mat(Color(0.9, 0.2, 0.15), Color(0.9, 0.25, 0.1), 0.9, 0.5)

	# 躯干（红衣）
	var body := CapsuleMesh.new()
	body.radius = 0.3
	body.height = 0.95
	Game.add_mesh(gfx, body, red, Vector3(0, 0.85, 0))
	# 腰带
	var belt := TorusMesh.new()
	belt.inner_radius = 0.26
	belt.outer_radius = 0.34
	Game.add_mesh(gfx, belt, gold, Vector3(0, 0.72, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	# 头
	var head := SphereMesh.new()
	head.radius = 0.26
	head.height = 0.52
	Game.add_mesh(gfx, head, skin, Vector3(0, 1.42, 0))
	# 后脑头发
	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.24
	hair_cap.height = 0.48
	Game.add_mesh(gfx, hair_cap, dark_hair, Vector3(-0.09, 1.47, 0))
	# 发髻 x2
	var bun := SphereMesh.new()
	bun.radius = 0.105
	bun.height = 0.21
	Game.add_mesh(gfx, bun, dark_hair, Vector3(-0.11, 1.66, -0.06))
	Game.add_mesh(gfx, bun, dark_hair, Vector3(0.06, 1.68, 0.1))
	# 发带小球
	var tie := SphereMesh.new()
	tie.radius = 0.04
	tie.height = 0.08
	Game.add_mesh(gfx, tie, ribbon_mat, Vector3(-0.11, 1.76, -0.06))
	Game.add_mesh(gfx, tie, ribbon_mat, Vector3(0.06, 1.78, 0.1))
	# 面部（朝向 +x 行进方向）：双眼 + 眉心红印
	var eye := SphereMesh.new()
	eye.radius = 0.034
	eye.height = 0.068
	var eye_mat := Game.std_mat(Color(0.06, 0.06, 0.08), Color(0.2, 0.5, 0.55), 0.6, 0.2)
	Game.add_mesh(gfx, eye, eye_mat, Vector3(0.2, 1.47, 0.1))
	Game.add_mesh(gfx, eye, eye_mat, Vector3(0.2, 1.47, -0.1))
	var mark := SphereMesh.new()
	mark.radius = 0.028
	mark.height = 0.056
	Game.add_mesh(gfx, mark, fire_mat, Vector3(0.235, 1.56, 0))
	# 肩甲
	var pauldron := SphereMesh.new()
	pauldron.radius = 0.13
	pauldron.height = 0.26
	Game.add_mesh(gfx, pauldron, gold, Vector3(0, 1.18, 0.3))
	Game.add_mesh(gfx, pauldron, gold, Vector3(0, 1.18, -0.3))

	# 乾坤圈：环绕周身缓转
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.52
	ring_mesh.outer_radius = 0.58
	ring = Game.add_mesh(gfx, ring_mesh, gold, Vector3(0, 1.0, 0),
		Vector3(12, 0, 8))

	# 混天绫：两条飘带
	var ribbon := BoxMesh.new()
	ribbon.size = Vector3(1.3, 0.05, 0.16)
	ribbon_l = Game.add_mesh(gfx, ribbon, ribbon_mat,
		Vector3(-0.75, 1.35, 0.18), Vector3(0, 0, 28))
	ribbon_r = Game.add_mesh(gfx, ribbon, ribbon_mat,
		Vector3(-0.75, 1.25, -0.18), Vector3(0, 0, 12))

	# 火尖枪
	_build_spear(Vector3(0.3, 0.95, 0.06))

	# 风火轮 x2
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.13
	wheel.outer_radius = 0.2
	wheel_f = Game.add_mesh(gfx, wheel, fire_mat, Vector3(0, 0.16, 0.14),
		Vector3(0, 90, 0))
	wheel_b = Game.add_mesh(gfx, wheel, fire_mat, Vector3(0, 0.16, -0.14),
		Vector3(0, 90, 0))
	wheel_glow = _make_flame(Vector3(0, 0.1, 0), 0.8, 16)
	gfx.add_child(wheel_glow)

	# 周身火光
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.position = Vector3(0, 0.9, 0.6)
	light.shadow_enabled = false
	gfx.add_child(light)
	Game.tune_light(light, 0.75, 4.2, 0.15)


func _build_spear(at: Vector3) -> void:
	spear = Node3D.new()
	spear.name = "FireTipSpear"
	spear.position = at
	spear.rotation_degrees = Vector3(0, 0, -18)
	gfx.add_child(spear)
	var visual := (load("res://art/models/huojianqiang.glb") as PackedScene).instantiate() as Node3D
	visual.name = "HuojianqiangModel"
	spear.add_child(visual)
	spear.add_child(_make_flame(Vector3(0, 1.15, 0), 0.35, 6))


func _build_model_equipment() -> void:
	## 3D 模型的装备动画层：手持火尖枪 + 背挂乾坤圈 + 风火轮烈焰 + 火光
	var gold := Game.std_mat(C_GOLD, C_GOLD, 0.9, 0.25, 0.9)

	# 骨骼（程序化动作驱动 + 武器跟手）
	for sk: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		skel = sk
		for i in sk.get_bone_count():
			_bones[sk.get_bone_name(i)] = i
		break

	# 乾坤圈：小金环斜挂在背后
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.30
	ring_mesh.outer_radius = 0.335
	ring = Game.add_mesh(gfx, ring_mesh, gold, Vector3(-0.24, 1.18, 0),
		Vector3(0, 0, 78))
	var back := BoneAttachment3D.new()
	back.name = "BackRingSocket"
	back.bone_name = "spine_02.x"
	skel.add_child(back)
	ring.reparent(back, false)
	var ring_rest := Transform3D(Basis.from_euler(Vector3(PI / 2.0, 0.0, 0.0)), Vector3(0.0, 1.10, -0.13))
	ring.transform = skel.get_bone_global_rest(_bones["spine_02.x"]).affine_inverse() * ring_rest

	# 火尖枪（平时跟随右手，攻击时突刺/横扫）
	_build_spear(Vector3(0.3, 0.95, 0.3))

	# 风火轮烈焰（脚下，偏向镜头侧更醒目）
	wheel_glow = _make_flame(Vector3(0, 0.15, 0.18), 1.0, 22)
	gfx.add_child(wheel_glow)

	# 周身火光
	var mlight := OmniLight3D.new()
	mlight.light_color = Color(1.0, 0.6, 0.3)
	mlight.light_energy = 1.8
	mlight.omni_range = 5.5
	mlight.position = Vector3(0, 0.9, 0.6)
	mlight.shadow_enabled = false
	gfx.add_child(mlight)
	Game.tune_light(mlight, 0.80, 4.2, 0.15)

	# 脚下乾坤圈（Blender 里从主体拆出的独立网格，不蒙皮）：拿来做自转与浮动
	_foot_ring = model.find_child("nezha_ring", true, false) as Node3D
	if _foot_ring:
		_foot_ring_base = _foot_ring.position


func _build_sprite_gfx() -> void:
	## AI 立绘精灵 + 程序化动效（粒子火焰 / 火光 / 起伏倾斜）
	use_sprites = true
	_tex_run = Game.tex("res://art/sprites/nezha_run.png")
	_tex_attack = Game.tex("res://art/sprites/nezha_attack.png")
	_tex_jump = Game.tex("res://art/sprites/nezha_jump.png")
	if _tex_run == null:
		_tex_run = _tex_idle
	if _tex_attack == null:
		_tex_attack = _tex_idle
	if _tex_jump == null:
		_tex_jump = _tex_run

	sprite = Sprite3D.new()
	_set_sprite_tex(_tex_idle)
	sprite.position.y = SPRITE_H * 0.5
	sprite.shaded = false
	gfx.add_child(sprite)

	# 脚下风火轮残焰
	wheel_glow = _make_flame(Vector3(0, 0.12, 0), 0.7, 14)
	gfx.add_child(wheel_glow)

	# 周身火光
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.6
	light.omni_range = 5.0
	light.position = Vector3(0, 0.9, 0.6)
	light.shadow_enabled = false
	gfx.add_child(light)
	Game.tune_light(light, 0.75, 4.2, 0.15)


func _set_sprite_tex(tex: Texture2D) -> void:
	if sprite.texture == tex:
		return
	sprite.texture = tex
	sprite.pixel_size = SPRITE_H / float(tex.get_height())


func _make_flame(pos: Vector3, scale_v: float, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.45
	p.position = pos
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 25.0
	mat.initial_velocity_min = 0.8 * scale_v
	mat.initial_velocity_max = 1.8 * scale_v
	mat.gravity = Vector3(0, 2.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.12 * scale_v
	var grad := Gradient.new()
	grad.add_point(0.5, Color(1.0, 0.4, 0.05, 0.8))
	grad.set_color(0, Color(1.0, 0.85, 0.3, 0.9))
	grad.set_color(grad.get_point_count() - 1, Color(0.7, 0.1, 0.05, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var m := SphereMesh.new()
	m.radius = 0.07 * scale_v
	m.height = 0.14 * scale_v
	m.radial_segments = 6
	m.rings = 3
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(1, 1, 1)
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.5, 0.1)
	sm.emission_energy_multiplier = 2.0
	m.material = sm
	p.draw_pass_1 = m
	return p


# ---------------------------------------------------------------- 主循环

func _physics_process(delta: float) -> void:
	if act == "dead":
		if _motion:
			_motion.update(self, delta)
			_update_spear_follow()
		return
	_anim_time += delta
	coyote = maxf(coyote - delta, 0.0)
	jump_buffer = maxf(jump_buffer - delta, 0.0)
	dash_cd_t = maxf(dash_cd_t - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	combo_cd = maxf(combo_cd - delta, 0.0)
	_swing_cd = maxf(_swing_cd - delta, 0.0)
	_grapple_cd = maxf(_grapple_cd - delta, 0.0)
	_tether_t = maxf(_tether_t - delta, 0.0)
	_update_tether(delta)
	# 海眼引力井减速：离开后逐渐恢复
	_slow_t = maxf(_slow_t - delta, 0.0)
	if _slow_t <= 0.0:
		_slow_amount = move_toward(_slow_amount, 0.0, 1.6 * delta)
	_update_wheel(delta)
	_tide_tick(delta)

	var axis := Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.13

	# ---- 混天绫摆荡中（独立于普通移动/重力）
	if act == "swing":
		_process_swing(delta, axis)
		_update_anim(delta, axis)
		return

	# ---- 乾坤圈蓄力中：人物定格（空中也不下落），松手/蓄满后掷出
	if act == "charge_ring":
		_process_ring_charge(delta)
		_update_anim(delta, axis)
		return
	if _ring_charging and act != "charge_ring":
		# 被击中/打断时取消蓄力，不消耗灵力
		_ring_charging = false
		_ring_charge = 0.0
		if ring:
			ring.scale = Vector3.ONE

	# ---- 冲刺中
	if dash_t > 0.0:
		dash_t -= delta
		velocity.x = facing * DASH_SPEED
		velocity.y = 0.0
		move_and_slide()
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.045
			_spawn_ghost()
		_update_anim(delta, axis)
		return

	# ---- 动作状态推进
	if act != "free":
		act_t += delta
		_process_action()

	# ---- 重力
	if not is_on_floor():
		var g := GRAVITY * (1.35 if velocity.y < 0.0 else 1.0)
		velocity.y -= g * delta
		velocity.y = maxf(velocity.y, -28.0)
	else:
		if was_airborne:
			_on_land()
		coyote = 0.12
		air_jumps = 1
		air_dash_used = false
	was_airborne = not is_on_floor()

	# ---- 水平移动
	var control := 1.0
	if act == "hurt":
		control = 0.0
	elif act in ["atk1", "atk2", "atk3", "heavy", "skill", "pull"]:
		control = 0.15
	# 定潮：起手/收招期间减速或定身
	if _pulling:
		control = 0.55
	elif _tide_guard_t > 0.0:
		control = 0.35
	if _tide_move_lock_t > 0.0:
		control = 0.0
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	# 海眼引力井减速（风火轮已改为腾空强化下砸，不再加速跑动）
	var spd := SPEED
	spd *= (1.0 - _slow_amount)
	velocity.x = move_toward(velocity.x, axis * spd * control, accel * delta)

	if absf(axis) > 0.1 and act == "free":
		facing = signf(axis)

	# ---- 跳跃
	if jump_buffer > 0.0 and act in ["free", "atk1", "atk2", "atk3"]:
		if coyote > 0.0:
			_do_jump()
		elif air_jumps > 0:
			air_jumps -= 1
			_do_jump(true)
	if Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5

	# ---- 输入：冲刺 / 攻击 / 重击 / 技能 / 定潮
	_tide_input(delta)
	if act in ["free", "atk1", "atk2", "atk3"]:
		if Input.is_action_just_pressed("dash") and dash_cd_t <= 0.0 \
				and (is_on_floor() or not air_dash_used):
			_do_dash(axis)
		elif _tide_busy():
			pass   # 定潮进行中：攻击/技能/摆荡全部让位（冲刺仍然优先）
		elif Input.is_action_just_pressed("attack"):
			_try_attack(axis)
		elif Input.is_action_just_pressed("heavy") and act == "free" and combo_cd <= 0.0:
			if is_on_floor():
				_start_action("heavy")
				Game.play_sfx("swing", -4.0, 0.7)
			else:
				_start_action("plunge")
		elif Input.is_action_just_pressed("grapple") and act == "free":
			_do_grapple()
		elif Input.is_action_just_pressed("skill") and act == "free":
			if not Game.has_skill("Q"):
				Game.play_sfx("ui", -12.0, 0.7)
			elif energy >= SKILL_COST:
				energy -= SKILL_COST
				energy_changed.emit(energy, MAX_ENERGY)
				_start_action("skill")
			else:
				Game.play_sfx("ui", -10.0, 0.6)
		elif Input.is_action_just_pressed("skill2") and act == "free":
			if not Game.has_skill("E"):
				Game.play_sfx("ui", -12.0, 0.7)
			elif energy >= SKILL2_COST and not _ring_out:
				# 按住蓄力（最长 1 秒）：蓄力越久，乾坤圈飞得越远、伤害越高
				_start_ring_charge()
			else:
				Game.play_sfx("ui", -10.0, 0.6)
		elif Input.is_action_just_pressed("skill3") and act == "free":
			_cast_wheel()

	# 关卡外力（引力井等）最后一次叠加，然后统一移动
	velocity += _external_vel
	_external_vel = Vector3.ZERO
	move_and_slide()
	# 锁定 Z 轴（2.5D 平面）
	global_position.z = 0.0
	_guard_sweep()
	_update_tide_fx(delta)
	_update_anim(delta, axis)


func apply_external_force(v: Vector3) -> void:
	## 关卡机制（海眼引力井等）给玩家的持续外力；下一帧生效一次
	_external_vel += v


# ---------------------------------------------------------------- 混天绫（第三章）

func _build_tether() -> void:
	## 混天绫索：一条用 ImmediateMesh 每帧重画的红色绸带（不新建对象）
	_tether_mesh = ImmediateMesh.new()
	tether = MeshInstance3D.new()
	tether.mesh = _tether_mesh
	tether.top_level = true            # 顶点用世界坐标
	tether.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := Game.std_mat(Color(0.82, 0.12, 0.10), Color(1.0, 0.25, 0.12),
		1.7, 0.4)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	tether.material_override = m
	add_child(tether)
	tether.visible = false


func _draw_tether(a: Vector3, b: Vector3) -> void:
	_tether_mesh.clear_surfaces()
	var n := 12
	var half := 0.045
	_tether_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in n:
		var t := float(i) / float(n - 1)
		# 中点下垂，像布带而不是钢筋
		var p := a.lerp(b, t) + Vector3(0, -sin(PI * t) * 0.28, 0)
		var w := Vector3(0, half * (1.0 - 0.35 * t), 0)
		_tether_mesh.surface_add_vertex(p + w)
		_tether_mesh.surface_add_vertex(p - w)
	_tether_mesh.surface_end()
	tether.visible = true


func _update_tether(_delta: float) -> void:
	if tether == null:
		return
	var active := false
	var b := Vector3.ZERO
	if act == "swing":
		active = true
		b = _swing_pivot
	elif _tether_t > 0.0:
		active = true
		if _tether_follow and is_instance_valid(_tether_follow):
			_tether_to = _tether_follow.global_position + Vector3(0, 0.7, 0)
		b = _tether_to
	if not active:
		tether.visible = false
		return
	_draw_tether(global_position + Vector3(0, 1.25, 0), b)


# ---------------------------------------------------------------- 风火轮（技能 3）

func _build_wheel() -> void:
	## 风火轮：双脚位置两只旋转火轮（默认隐藏）
	_wheel_hold = Node3D.new()
	_wheel_hold.top_level = false
	add_child(_wheel_hold)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.48
	torus.ring_segments = 24
	torus.rings = 8
	var mat := Game.std_mat(Color(1.0, 0.45, 0.12), Color(1.0, 0.28, 0.05),
		1.8, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 2:
		var mi := Game.add_mesh(_wheel_hold, torus, mat,
			Vector3(-0.32 + i * 0.64, 0.32, 0.18), Vector3(90, 0, 0))
		_wheel_fx.append(mi)
	_wheel_hold.visible = false


func _cast_wheel() -> void:
	## 风火轮：借轮腾空到很高的高度，落地前按 K 下砸可造成双倍伤害
	if not Game.has_skill("V"):
		Game.play_sfx("ui", -12.0, 0.7)
		return
	if wheel_t > 0.0:
		return                    # 腾空窗口内不重复施放
	if energy < SKILL3_COST:
		Game.play_sfx("ui", -10.0, 0.6)
		return
	energy -= SKILL3_COST
	energy_changed.emit(energy, MAX_ENERGY)
	wheel_t = WHEEL_TIME
	_wheel_airborne = false
	_wheel_trail_t = 0.0
	# 向上腾空：初速 23 ≈ 二段跳高度的两倍（不会再飞出屏幕）
	velocity.y = 23.0
	velocity.x *= 0.35
	act = "free"
	act_t = 0.0
	dash_t = 0.0
	Game.play_sfx("fire", -2.0, 0.85)
	Game.play_sfx("dash", -6.0, 1.1)
	Game.shake(0.3)
	Game.burst(get_parent(), global_position + Vector3(0, 0.3, 0),
		Color(1.0, 0.5, 0.12), 26, 6.0, 0.1, 0.55)


func _update_wheel(delta: float) -> void:
	if _wheel_hold == null:
		return
	wheel_t = maxf(wheel_t - delta, 0.0)
	# 腾空窗口：离地后才算进入空中；落地后结束。
	# 注意：落地那一帧 act 仍是 "plunge"（下砸判定在动作推进里），不能提前清掉窗口，
	# 否则强化下砸永远吃不到加成。
	if wheel_t > 0.0:
		if not _wheel_airborne and not is_on_floor():
			_wheel_airborne = true
		elif _wheel_airborne and is_on_floor() and act != "plunge":
			wheel_t = 0.0
	var on := wheel_t > 0.0
	_wheel_hold.visible = on
	if not on:
		return
	_wheel_hold.rotation.y += delta * 18.0
	var bob := 0.26 + sin(_anim_time * 17.0) * 0.07
	for i in _wheel_fx.size():
		var mi := _wheel_fx[i]
		mi.position.y = bob
		mi.rotation.z += delta * (10.0 if i == 0 else -10.0)
	# 上升尾焰（腾空阶段）
	if velocity.y > 4.0:
		_wheel_trail_t -= delta
		if _wheel_trail_t <= 0.0:
			_wheel_trail_t = 0.05
			Game.burst(get_parent(), global_position + Vector3(0, 0.15, 0),
				Color(1.0, 0.5, 0.12), 3, 2.2, 0.05, 0.28)


func apply_slow(amount: float, dur: float) -> void:
	## 关卡机制（海眼引力井）减速：冲刺/荡索可以强行脱身
	_slow_amount = maxf(_slow_amount, clampf(amount, 0.0, 0.9))
	_slow_t = maxf(_slow_t, dur)


func _do_grapple() -> void:
	## F：优先抓铜环摆荡；附近没有锚点就改为缠敌人
	if _swing_cd > 0.0:
		return
	var anchor := _find_anchor()
	if anchor != null:
		_start_swing(anchor)
		return
	if _grapple_cd > 0.0:
		return
	var enemy := _find_grapple_enemy()
	if enemy != null:
		_grapple_enemy(enemy)
	else:
		Game.play_sfx("ui", -12.0, 0.8)


func _find_anchor() -> Node3D:
	var best: Node3D = null
	var best_d := SWING_RANGE + 0.001
	for n in get_tree().get_nodes_in_group("swing_anchor"):
		if not (n is Node3D):
			continue
		var d: Vector3 = (n as Node3D).global_position - global_position
		var dist := d.length()
		if dist < 1.2 or dist > SWING_RANGE:
			continue
		if d.y < -3.0 or d.y > 9.0:
			continue
		if d.x * facing < -1.0:        # 基本要在面朝方向
			continue
		if dist < best_d:
			best_d = dist
			best = n as Node3D
	return best


func _start_swing(anchor: Node3D) -> void:
	var d: Vector3 = global_position - anchor.global_position
	_swing_pivot = anchor.global_position
	_swing_len = clampf(Vector2(d.x, d.y).length(), SWING_MIN_LEN, SWING_MAX_LEN)
	var theta := atan2(d.y, d.x)
	# 继承一点当前动量，摆荡更连贯
	var tangent := Vector3(-sin(theta), cos(theta), 0)
	_swing_omega = clampf(velocity.dot(tangent) / maxf(_swing_len, 0.1), -3.0, 3.0)
	_swing_t = 0.0
	_swing_drop_pending = false
	_swing_drop_t = 0.0
	act = "swing"
	act_t = 0.0
	dash_t = 0.0
	velocity = Vector3.ZERO
	Game.play_sfx("swing", -3.0, 1.35)
	var ring: Node3D = anchor
	if ring.has_method("pulse"):
		ring.call("pulse")
	Game.burst(get_parent(), _swing_pivot, C_FIRE, 8, 2.5, 0.05, 0.3)


func _process_swing(delta: float, axis: float) -> void:
	# 换锚点：松手后 0.35s 内再按 F 视为"换绳"（而不是脱手落地）。
	# 之前是"一松开 F 立刻脱手"，玩家根本来不及按第二次 → 长悬崖连不起来。
	if Input.is_action_just_pressed("grapple"):
		_try_chain_swing()
	if Input.is_action_just_released("grapple"):
		_swing_drop_pending = true
		_swing_drop_t = 0.35
	if _swing_drop_pending:
		_swing_drop_t -= delta
	_swing_t += delta
	var d: Vector3 = global_position - _swing_pivot
	var theta := atan2(d.y, d.x)
	# 重力沿切向、玩家输入、阻尼
	_swing_omega += (-GRAVITY / maxf(_swing_len, 0.1)) * cos(theta) * delta
	_swing_omega += axis * SWING_INPUT_ACCEL * delta
	_swing_omega *= (1.0 - 0.6 * delta)
	_swing_omega = clampf(_swing_omega, -6.5, 6.5)
	theta += _swing_omega * delta

	var desired := _swing_pivot + Vector3(cos(theta), sin(theta), 0) * _swing_len
	velocity = (desired - global_position) / maxf(delta, 0.0001)
	move_and_slide()
	# 碰撞后重新投影回圆弧，保持绳长
	var to_p := global_position - _swing_pivot
	if to_p.length() > 0.01:
		global_position = _swing_pivot + to_p.normalized() * _swing_len
	global_position.z = 0.0
	if absf(cos(theta)) > 0.15:
		facing = 1.0 if cos(theta) > 0.0 else -1.0

	# 从地面起手时给 0.35s 缓冲，否则第一帧就会被 is_on_floor 判掉
	if (_swing_drop_pending and _swing_drop_t <= 0.0) \
			or _swing_t >= SWING_MAX_TIME \
			or (_swing_t > 0.35 and is_on_floor()):
		_release_swing(theta)


func _release_swing(theta: float) -> void:
	## 脱手：把摆荡速度加成抛物线初速，接普通空中状态
	var tangent := Vector3(-sin(theta), cos(theta), 0) * (_swing_omega * _swing_len)
	velocity = tangent * 1.25 + Vector3(0, 2.0, 0)
	act = "free"
	act_t = 0.0
	_swing_cd = 0.15
	_swing_drop_pending = false
	_swing_drop_t = 0.0
	tether.visible = false
	Game.play_sfx("dash", -7.0, 1.25)
	Game.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(1.0, 0.55, 0.2), 10, 3.5, 0.06, 0.35)


func _try_chain_swing() -> bool:
	## 摆荡中换锚点：从当前位置找下一个更靠前的铜环，把速度投影到新圆弧切向。
	## 成功返回 true；失败（附近没有可用锚点）返回 false，继续原摆荡。
	var best: Node3D = null
	var best_score := -1.0e9
	for n in get_tree().get_nodes_in_group("swing_anchor"):
		if not (n is Node3D):
			continue
		var p: Vector3 = (n as Node3D).global_position
		if p.distance_to(_swing_pivot) < 1.0:
			continue                      # 跳过当前锚点
		var d: Vector3 = p - global_position
		var dist := d.length()
		if dist < 2.0 or dist > 12.5:
			continue
		if d.y < -2.5 or d.y > 10.0:
			continue
		# 不做方向硬过滤：摆荡时玩家可能还没荡起来（速度接近 0），
		# 用 facing 判断会误杀前方锚点；改为"取最近 + 前方加权"。
		var score := -dist + maxf(0.0, d.x) * 0.3
		if score > best_score:
			best_score = score
			best = n as Node3D
	if best == null:
		return false
	var nd: Vector3 = global_position - best.global_position
	var new_len := clampf(Vector2(nd.x, nd.y).length(), SWING_MIN_LEN,
		SWING_MAX_LEN)
	var new_theta := atan2(nd.y, nd.x)
	var tangent := Vector3(-sin(new_theta), cos(new_theta), 0)
	# 保留切向动量：换绳不掉速
	var momentum := velocity.dot(tangent) / maxf(new_len, 0.1)
	_swing_pivot = best.global_position
	_swing_len = new_len
	_swing_omega = clampf(momentum, -6.0, 6.0)
	_swing_t = 0.0
	_swing_drop_pending = false
	_swing_drop_t = 0.0
	Game.play_sfx("swing", -3.5, 1.45)
	if best.has_method("pulse"):
		best.call("pulse")
	Game.burst(get_parent(), _swing_pivot, Color(1.0, 0.65, 0.3),
		10, 3.0, 0.05, 0.3)
	return true


func _find_grapple_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := GRAPPLE_ENEMY_RANGE + 0.001
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D) or not e.has_method("take_damage"):
			continue
		var d: Vector3 = (e as Node3D).global_position - global_position
		var dist := d.length()
		if dist > GRAPPLE_ENEMY_RANGE or dist < 0.6:
			continue
		if d.x * facing < -0.6:
			continue
		if dist < best_d:
			best_d = dist
			best = e as Node3D
	return best


func _grapple_enemy(e: Node3D) -> void:
	var is_big := e.has_method("reset_fight") \
		or float(e.get("max_hp") if e.get("max_hp") != null else 0.0) >= 150.0
	var cost := GRAPPLE_COST_BIG if is_big else GRAPPLE_COST_SMALL
	if energy < cost:
		Game.play_sfx("ui", -10.0, 0.6)
		return
	energy -= cost
	energy_changed.emit(energy, MAX_ENERGY)
	_grapple_cd = GRAPPLE_CD
	_tether_follow = e
	_tether_t = 0.3
	Game.play_sfx("swing", -4.0, 1.1)
	if is_big:
		# 大型目标：把自己拽向它，当作位移 + 小伤害
		var dir := (e.global_position - global_position).normalized()
		_pull_dir = signf(dir.x) if absf(dir.x) > 0.01 else facing
		act = "pull"
		act_t = 0.0
		velocity = dir * 17.0 + Vector3(0, 1.5, 0)
		e.call("take_damage", 15.0, facing, false)
		Game.burst(get_parent(), e.global_position + Vector3(0, 1.0, 0),
			Color(1.0, 0.5, 0.2), 14, 4.0, 0.07, 0.4)
	else:
		# 小型目标：拉到自己面前并定身
		if e.has_method("stun"):
			e.call("stun", 0.8)
		e.call("take_damage", 6.0, facing, false)
		var tw := e.create_tween()
		tw.tween_property(e, "global_position",
			global_position + Vector3(facing * 1.5, 0.5, 0), 0.16) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		Game.burst(get_parent(), global_position + Vector3(facing * 2.0, 1.0, 0),
			C_FIRE, 12, 3.5, 0.06, 0.35)


func _do_jump(double := false) -> void:
	if _motion:
		_motion.trigger("jump")
	velocity.y = JUMP_V * (0.92 if double else 1.0)
	jump_buffer = 0.0
	coyote = 0.0
	Game.play_sfx("jump", -8.0, 1.15 if double else 1.0)
	Game.burst(get_parent(), global_position + Vector3(0, 0.15, 0),
		C_FIRE, 10, 3.0, 0.06, 0.4)


func _do_dash(axis: float) -> void:
	if _motion:
		_motion.trigger("dash")
	if absf(axis) > 0.1:
		facing = signf(axis)
	dash_t = DASH_TIME
	dash_cd_t = DASH_CD
	invuln = maxf(invuln, DASH_TIME + 0.06)
	_pd_done = false
	_ghost_t = 0.0
	# 冲刺打断定潮（冲刺优先级最高）
	_tide_cancel()
	if not is_on_floor():
		air_dash_used = true
	act = "free"
	attack_queued = false
	Game.play_sfx("dash", -6.0)
	Game.burst(get_parent(), global_position + Vector3(0, 0.8, 0),
		Color(1.0, 0.7, 0.3), 16, 4.0, 0.07, 0.35)


func _on_land() -> void:
	Game.burst(get_parent(), global_position + Vector3(0, 0.1, 0),
		Color(0.5, 0.8, 0.8, 0.6), 8, 2.5, 0.05, 0.3)
	if _motion:
		_motion.trigger("land")
		return
	var tw := gfx.create_tween()
	gfx.scale = Vector3(1.15, 0.82, 1.15)
	tw.tween_property(gfx, "scale", Vector3.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 攻击

func _try_attack(axis: float) -> void:
	if act == "free":
		if combo_cd > 0.0:
			return
		if absf(axis) > 0.1:
			facing = signf(axis)
		_start_action("atk1")
	elif act in ["atk1", "atk2"] and act_t > 0.08:
		attack_queued = true


func _start_action(new_act: String) -> void:
	if _motion:
		_motion.trigger(new_act)
	act = new_act
	act_t = 0.0
	act_hit_done = false
	if new_act in ["atk1", "atk2", "atk3", "heavy", "plunge"]:
		_rune_swing_gain = 0.0
	if new_act == "skill":
		_rune_cast_gain = 0.0
	match new_act:
		"atk1", "atk2":
			Game.play_sfx("swing", -6.0)
			_anim_thrust(0.55, 0.13)
			velocity.x = facing * 4.5
			Game.burst(get_parent(), global_position +
				Vector3(facing * 1.0, 1.0, 0.2), C_FIRE, 8, 3.0, 0.05, 0.3)
		"atk3":
			Game.play_sfx("swing", -3.0, 0.85)
			_anim_thrust(0.85, 0.18)
			velocity.x = facing * 6.5
			Game.burst(get_parent(), global_position +
				Vector3(facing * 1.2, 1.0, 0.2), C_FIRE, 14, 4.5, 0.06, 0.35)
		"heavy":
			velocity.x = -facing * 2.0
			_anim_heavy()
		"plunge":
			velocity.y = -22.0
			velocity.x *= 0.35
			# 下砸起手给极短无敌：避免落下瞬间先被敌人接触伤害打断，导致砸不出来
			invuln = maxf(invuln, 0.3)
			Game.play_sfx("dash", -6.0, 0.7)
		"skill":
			Game.play_sfx("nova", -2.0)
			velocity.x = 0.0


func _process_action() -> void:
	match act:
		"atk1", "atk2":
			if not act_hit_done and act_t >= 0.1:
				act_hit_done = true
				_strike(10.0, Vector3(2.4, 1.8, 2.0), Vector3(1.25, 0.95, 0), 4.0)
			if act_t >= 0.3:
				if attack_queued:
					attack_queued = false
					_start_action("atk2" if act == "atk1" else "atk3")
				else:
					act = "free"
					combo_cd = 0.12
		"atk3":
			if not act_hit_done and act_t >= 0.15:
				act_hit_done = true
				if _strike(18.0, Vector3(2.8, 2.0, 2.2), Vector3(1.4, 0.95, 0), 7.5):
					Game.hitstop(0.08, 0.05)
			if act_t >= 0.42:
				act = "free"
				combo_cd = 0.28
		"heavy":
			if not act_hit_done and act_t >= 0.32:
				act_hit_done = true
				if _strike(30.0, Vector3(3.4, 2.4, 2.6), Vector3(1.5, 1.0, 0),
						11.0, true):
					Game.hitstop(0.1, 0.04)
					Game.shake(0.45)
				Game.play_sfx("heavy", -3.0)
				velocity.x = facing * 8.0
				Game.burst(get_parent(), global_position +
					Vector3(facing * 1.4, 1.1, 0.2), Color(1.0, 0.7, 0.2),
					20, 6.0, 0.08, 0.4)
			if act_t >= 0.6:
				act = "free"
				combo_cd = 0.3
		"plunge":
			velocity.y = minf(velocity.y, -20.0)
			if is_on_floor():
				var boosted := wheel_t > 0.0
				var pdmg := 24.0 * (2.0 if boosted else 1.0)
				if boosted:
					wheel_t = 0.0
				if _strike(pdmg,
						Vector3(5.8, 2.8, 3.0) if boosted else Vector3(4.6, 2.4, 2.6),
						Vector3(0.0, 0.7, 0), 13.0 if boosted else 9.0, true,
						RUNE_SLAM):
					Game.hitstop(0.1 if boosted else 0.08, 0.05)
				Game.play_sfx("heavy", -3.0, 0.8 if boosted else 1.0)
				Game.shake(0.9 if boosted else 0.5)
				Game.burst(get_parent(), global_position + Vector3(0, 0.25, 0),
					Color(1.0, 0.55, 0.12) if boosted else C_FIRE,
					46 if boosted else 26, 10.0 if boosted else 7.0, 0.12, 0.75)
				_slash_fx(Vector3(0.0, 0.3, 0), 2.2 if boosted else 1.6)
				act = "free"
				combo_cd = 0.25
		"skill":
			if not act_hit_done and act_t >= 0.16:
				act_hit_done = true
				_do_nova()
			if act_t >= 0.55:
				act = "free"
		"hurt":
			if act_t >= 0.32:
				act = "free"
		"pull":
			# 混天绫拽向大型目标：短暂锁定方向，随后回到自由
			velocity.x = _pull_dir * 16.0
			if act_t >= 0.16:
				act = "free"
				combo_cd = 0.1


func _strike(dmg: float, size: Vector3, offset: Vector3, knock: float,
		heavy := false, rune := -1.0) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	q.shape = shape
	q.transform = Transform3D(Basis(),
		global_position + Vector3(offset.x * facing, offset.y, 0))
	q.collision_mask = L_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var hits := space.intersect_shape(q, 16)
	# 多受击点 Boss（躯干/头/逆鳞/潮心）在空间上互相重叠：同一次挥击只能算一次，
	# 并且按收益最高的部位结算（否则躯干先被遍历到，打头反而按躯干 0.55 倍算）。
	var best := {}
	for h in hits:
		var c: Object = h.collider
		if c == null or not c.has_method("take_damage"):
			continue
		var key: Object = c
		if c.has_method("hit_key"):
			key = c.call("hit_key")
		var pri := int(c.call("hit_priority")) if c.has_method("hit_priority") else 0
		if not best.has(key) or pri > int(best[key][1]):
			best[key] = [c, pri]
	var any := false
	for key in best:
		var c: Object = best[key][0]
		# 范围攻击（offset.x 为 0）时按敌人方位决定击退方向
		var kdir := facing
		if offset.x == 0.0 and c is Node3D:
			kdir = signf((c as Node3D).global_position.x - global_position.x)
			if kdir == 0.0:
				kdir = facing
		c.take_damage(dmg, kdir, heavy)
		any = true
	if any:
		add_energy(18.0 if heavy else 10.0)
		hit_landed.emit(best.size())
		_gain_swing_rune(rune if rune >= 0.0 else (RUNE_HEAVY if heavy else RUNE_LIGHT))
		Game.play_sfx("hit", -4.0)
		Game.shake(0.18 if not heavy else 0.4)
		_slash_fx(offset, 1.0 if not heavy else 1.5)
	return any


func register_hit(count: int) -> void:
	## 供乾坤圈等独立投射物上报命中（驱动连击计数）
	hit_landed.emit(count)


func _spawn_ghost() -> void:
	## 冲刺火焰残影
	var g := Node3D.new()
	get_parent().add_child(g)
	g.global_position = global_position
	g.rotation.y = gfx.rotation.y
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.18, 0.4)
	mat.emission_enabled = true
	mat.emission = C_FIRE
	mat.emission_energy_multiplier = 1.3
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = 0.95
	Game.add_mesh(g, cap, mat, Vector3(0, 0.85, 0))
	var head := SphereMesh.new()
	head.radius = 0.24
	head.height = 0.48
	Game.add_mesh(g, head, mat, Vector3(0, 1.42, 0))
	var tw := g.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.26)
	tw.tween_callback(g.queue_free)


func _slash_fx(offset: Vector3, scale_v: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.55
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.7, 0.25, 0.85)
	mat.emission_enabled = true
	mat.emission = C_FIRE
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = mat
	mi.position = global_position + Vector3(offset.x * facing, offset.y, 0.3)
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.scale = Vector3(0.3, 0.3, 0.3) * scale_v
	get_parent().add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.4, 1.4, 1.4) * scale_v, 0.22) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)


func _do_nova() -> void:
	## 三昧真火：烈焰新星
	var origin := global_position + Vector3(0, 0.9, 0)
	Game.burst(get_parent(), origin, Color(1.0, 0.5, 0.1), 60, 11.0, 0.13, 0.8)
	Game.burst(get_parent(), origin, Color(1.0, 0.85, 0.3), 30, 7.0, 0.1, 0.6)
	Game.shake(0.6)
	Game.hitstop(0.09, 0.08)
	# 扩散火环
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.55, 0.15, 0.9)
	mat.emission_enabled = true
	mat.emission = C_FIRE
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = mat
	mi.position = global_position + Vector3(0, 0.25, 0)
	mi.scale = Vector3(0.2, 0.6, 0.2)
	get_parent().add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(4.8, 1.2, 4.8), 0.5) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)
	# 闪光
	var light := OmniLight3D.new()
	light.light_color = C_FIRE
	light.light_energy = 8.0
	light.omni_range = 10.0
	light.position = origin
	get_parent().add_child(light)
	Game.tune_light(light, 4.0, 6.0, 0.0)
	var lt := light.create_tween()
	lt.tween_property(light, "light_energy", 0.0, 0.5)
	lt.tween_callback(light.queue_free)
	# 范围伤害 + 灼烧
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 4.6
	q.shape = shape
	q.transform = Transform3D(Basis(), origin)
	q.collision_mask = L_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = true
	var nova_best := {}
	for h in space.intersect_shape(q, 16):
		var c: Object = h.collider
		if c == null or not c.has_method("take_damage"):
			continue
		var key: Object = c
		if c.has_method("hit_key"):
			key = c.call("hit_key")
		var pri := int(c.call("hit_priority")) if c.has_method("hit_priority") else 0
		if not nova_best.has(key) or pri > int(nova_best[key][1]):
			nova_best[key] = [c, pri]
	var nova_hits := 0
	for key in nova_best:
		var c: Object = nova_best[key][0]
		var dir := 1.0
		if c is Node3D:
			dir = signf((c as Node3D).global_position.x - global_position.x)
			if dir == 0.0:
				dir = facing
		c.take_damage(40.0, dir, true)
		if c.has_method("apply_burn"):
			c.apply_burn(15.0)
		nova_hits += 1
	if nova_hits > 0:
		hit_landed.emit(nova_hits)
		var gain := minf(RUNE_SKILL * float(nova_hits), RUNE_CAST_CAP - _rune_cast_gain)
		if gain > 0.0:
			_rune_cast_gain += gain
			_gain_rune(gain)


func _start_ring_charge() -> void:
	## 乾坤圈蓄力起手：按住 E 蓄力（上限 1 秒），期间人物定格（空中悬停）
	act = "charge_ring"
	act_t = 0.0
	_ring_charge = 0.0
	_ring_charging = true
	_ring_charge_fx = 0.0
	velocity = Vector3.ZERO
	Game.play_sfx("orb", -8.0, 1.2)
	if ring:
		ring.visible = true


func _process_ring_charge(delta: float) -> void:
	_ring_charge = minf(_ring_charge + delta, RING_CHARGE_MAX)
	# 定格：清速度且本帧跳过重力（空中会停在原地）
	velocity = Vector3.ZERO
	var k := _ring_charge / RING_CHARGE_MAX
	if ring:
		ring.scale = Vector3.ONE * (1.0 + 0.6 * k)
		ring.rotation.z += delta * (6.0 + 20.0 * k)
	_ring_charge_fx -= delta
	if _ring_charge_fx <= 0.0:
		_ring_charge_fx = 0.06
		Game.burst(get_parent(), global_position + Vector3(0, 1.0, 0),
			Color(1.0, 0.85, 0.35), 3, 2.0 + 3.0 * k, 0.05, 0.3)
	if Input.is_action_just_released("skill2") or _ring_charge >= RING_CHARGE_MAX:
		_ring_charging = false
		energy = maxf(energy - SKILL2_COST, 0.0)
		energy_changed.emit(energy, MAX_ENERGY)
		act = "free"
		act_t = 0.0
		var c := _ring_charge
		if c < 0.08:
			c = 0.0            # 点按：与原版完全一致
		_ring_charge = 0.0
		if ring:
			ring.scale = Vector3.ONE
		_throw_ring(c)


func _throw_ring(charge := 0.0) -> void:
	## 乾坤圈：掷出回旋金环。charge（0~1s）影响飞行距离与伤害
	var c := clampf(charge, 0.0, RING_CHARGE_MAX)
	_ring_out = true
	if ring:
		ring.visible = false
	var rt := RingThrow.new()
	rt.owner_player = self
	rt.dir = facing
	rt.dmg = 16.0 + c * RING_CHARGE_DMG
	rt.max_dist = 8.5 + c * 8.0
	rt.position = global_position + Vector3(facing * 0.7, 1.1, 0)
	get_parent().add_child(rt)
	Game.play_sfx("swing", -4.0, 1.4 - 0.3 * c)
	if c > 0.3:
		Game.shake(0.15 + 0.2 * c)


func ring_returned() -> void:
	_ring_out = false
	if ring:
		ring.visible = true


# ---------------------------------------------------------------- 动画

func _pose_target() -> Dictionary:
	## 按当前动作状态计算各骨骼目标欧拉角（骨骼局部空间，单位：弧度）
	## 骨架空间：角色面向 -Y(局部)，X 为左右；手臂/腿骨骼 Y 轴沿骨骼向下
	var t := _anim_time
	var p := {}
	match act:
		"atk1", "atk2", "atk3":
			# 刺枪：右臂前抬伸直，左臂后摆，身体前倾拧腰
			var a := clampf(act_t / 0.1, 0.0, 1.0)
			if act_t > 0.3:
				a = maxf(1.0 - (act_t - 0.3) / 0.15, 0.0)
			p["upper_arm.R"] = Vector3(-1.5 * a, 0, 0)
			p["forearm.R"] = Vector3(-0.2 * a, 0, 0)
			p["upper_arm.L"] = Vector3(0.7 * a, 0, 0)
			p["chest"] = Vector3(-0.18 * a, 0, 0.25 * a)
			p["thigh.L"] = Vector3(-0.4 * a, 0, 0)
			p["thigh.R"] = Vector3(0.3 * a, 0, 0)
			p["shin.R"] = Vector3(0.5 * a, 0, 0)
		"heavy":
			# 重击：先举枪蓄力再下劈
			if act_t < 0.32:
				var a := clampf(act_t / 0.25, 0.0, 1.0)
				p["upper_arm.R"] = Vector3(2.4 * a, 0, 0.3 * a)
				p["forearm.R"] = Vector3(-0.6 * a, 0, 0)
				p["chest"] = Vector3(0.22 * a, 0, -0.2 * a)
			else:
				var a := clampf((act_t - 0.32) / 0.08, 0.0, 1.0)
				p["upper_arm.R"] = Vector3(2.4 - 3.9 * a, 0, 0.3 - 0.3 * a)
				p["forearm.R"] = Vector3(-0.6 + 0.4 * a, 0, 0)
				p["upper_arm.L"] = Vector3(0.8 * a, 0, 0)
				p["chest"] = Vector3(0.22 - 0.5 * a, 0, -0.2 + 0.45 * a)
				p["thigh.L"] = Vector3(-0.5 * a, 0, 0)
				p["shin.L"] = Vector3(0.7 * a, 0, 0)
		"plunge":
			# 下坠突刺：双臂上扬、双腿收拢
			p["upper_arm.L"] = Vector3(2.2, 0, -0.4)
			p["upper_arm.R"] = Vector3(2.2, 0, 0.4)
			p["thigh.L"] = Vector3(-0.9, 0, 0)
			p["shin.L"] = Vector3(1.4, 0, 0)
			p["thigh.R"] = Vector3(-0.9, 0, 0)
			p["shin.R"] = Vector3(1.4, 0, 0)
			p["chest"] = Vector3(-0.3, 0, 0)
		"skill":
			# 三昧真火：双臂张开上举仰天
			var a := clampf(act_t / 0.14, 0.0, 1.0)
			p["upper_arm.L"] = Vector3(2.6 * a, 0, -0.9 * a)
			p["upper_arm.R"] = Vector3(2.6 * a, 0, 0.9 * a)
			p["head"] = Vector3(0.35 * a, 0, 0)
			p["chest"] = Vector3(0.15 * a, 0, 0)
		"hurt":
			p["chest"] = Vector3(0.35, 0, 0)
			p["head"] = Vector3(0.3, 0, 0)
			p["upper_arm.L"] = Vector3(0.5, 0, -0.5)
			p["upper_arm.R"] = Vector3(0.5, 0, 0.5)
		"charge_ring":
			# 蓄力：侧身、右手举环，随蓄力抬得更高
			var ck := clampf(_ring_charge / RING_CHARGE_MAX, 0.0, 1.0)
			p["upper_arm.R"] = Vector3(-1.2 - 0.6 * ck, 0, 0.2)
			p["forearm.R"] = Vector3(-0.5 - 0.4 * ck, 0, 0)
			p["upper_arm.L"] = Vector3(0.4, 0, -0.4)
			p["chest"] = Vector3(-0.1 - 0.15 * ck, 0, 0.15)
			p["thigh.L"] = Vector3(-0.25, 0, 0)
			p["thigh.R"] = Vector3(0.15, 0, 0)
			p["shin.L"] = Vector3(0.3, 0, 0)
		"swing":
			# 摆荡：双手上举抓绫、双腿后收
			var sw := sin(_anim_time * 6.0) * 0.08
			p["upper_arm.L"] = Vector3(2.5 + sw, 0, -0.5)
			p["upper_arm.R"] = Vector3(2.5 - sw, 0, 0.5)
			p["forearm.L"] = Vector3(-0.5, 0, 0)
			p["forearm.R"] = Vector3(-0.5, 0, 0)
			p["chest"] = Vector3(-0.2, 0, 0.1)
			p["thigh.L"] = Vector3(-0.7, 0, 0)
			p["shin.L"] = Vector3(1.0, 0, 0)
			p["thigh.R"] = Vector3(-0.3, 0, 0)
			p["shin.R"] = Vector3(0.7, 0, 0)
		"pull":
			p["chest"] = Vector3(-0.25, 0, 0)
			p["upper_arm.R"] = Vector3(1.8, 0, 0.2)
			p["upper_arm.L"] = Vector3(0.4, 0, -0.4)
		_:
			if dash_t > 0.0:
				# 闪避冲刺：低姿猛扑——上身压平、双臂后掠、前腿弓后腿绷
				p["hips"] = Vector3(0.5, 0, 0)
				p["chest"] = Vector3(0.6, 0, 0)
				p["head"] = Vector3(-0.75, 0, 0)
				p["upper_arm.L"] = Vector3(1.1, 0, -0.35)
				p["upper_arm.R"] = Vector3(1.1, 0, 0.35)
				p["forearm.L"] = Vector3(-0.4, 0, 0)
				p["forearm.R"] = Vector3(-0.4, 0, 0)
				p["thigh.L"] = Vector3(-1.15, 0, 0)
				p["shin.L"] = Vector3(1.3, 0, 0)
				p["thigh.R"] = Vector3(0.25, 0, 0)
				p["shin.R"] = Vector3(0.35, 0, 0)
			elif not is_on_floor():
				# 空中：屈膝展臂
				var up := velocity.y > 0.0
				p["thigh.L"] = Vector3(-0.55, 0, 0)
				p["shin.L"] = Vector3(0.95, 0, 0)
				p["thigh.R"] = Vector3(-0.25, 0, 0)
				p["shin.R"] = Vector3(0.5, 0, 0)
				p["upper_arm.L"] = Vector3(0.5 if up else 1.1, 0, -0.5)
				p["upper_arm.R"] = Vector3(0.5 if up else 1.1, 0, 0.5)
				p["chest"] = Vector3(-0.12, 0, 0)
			elif absf(velocity.x) > 0.5:
				# 奔跑：上身前倾 + 摆臂迈腿（反相）+ 肩部反拧
				var w := sin(t * 11.0) * 0.85
				# 上身随步伐摆动：肩部反拧（偏航）+ 左右侧倾（滚转）+ 步频起伏（俯仰）
				var bob := absf(sin(t * 11.0)) * 0.08
				p["hips"] = Vector3(0.18, -w * 0.10, w * 0.05)
				p["chest"] = Vector3(0.38 + bob, w * 0.28, w * 0.13)
				p["head"] = Vector3(-0.34 - bob * 0.6, -w * 0.20, -w * 0.10)
				p["upper_arm.L"] = Vector3(w, 0, -0.15)
				p["upper_arm.R"] = Vector3(-w, 0, 0.15)
				p["forearm.L"] = Vector3(-0.7 - 0.3 * w, 0, 0)
				p["forearm.R"] = Vector3(-0.7 + 0.3 * w, 0, 0)
				p["thigh.L"] = Vector3(-0.18 - w * 1.35, 0, 0)
				p["thigh.R"] = Vector3(-0.18 + w * 1.35, 0, 0)
				p["shin.L"] = Vector3(maxf(w, 0.0) * 1.55 + 0.25, 0, 0)
				p["shin.R"] = Vector3(maxf(-w, 0.0) * 1.55 + 0.25, 0, 0)
				p["foot.L"] = Vector3(-maxf(w, 0.0) * 0.5, 0, 0)
				p["foot.R"] = Vector3(-maxf(-w, 0.0) * 0.5, 0, 0)
			else:
				# 待机：呼吸起伏 + 手臂微摆
				var b := sin(t * 2.2) * 0.04
				p["chest"] = Vector3(b, 0, 0)
				p["head"] = Vector3(-b * 0.6, 0, 0)
				p["upper_arm.L"] = Vector3(0.08 + b, 0, -0.06)
				p["upper_arm.R"] = Vector3(0.08 + b, 0, 0.06)
				p["forearm.L"] = Vector3(-0.15, 0, 0)
				p["forearm.R"] = Vector3(-0.15, 0, 0)
	# 混天绫：rib.L/R.1~3 三段骨骼，分「待机 / 奔跑 / 腾空」三种形态：
	# 待机只有呼吸般的轻摆；跑动时幅度加大、频率变快，并且整条绸带往身后掠；
	# 腾空时后掠更夸张，像被风兜住。左右两侧相位错开 1.5 rad，避免同步摆动显得僵硬。
	var spd := absf(velocity.x)
	var k_move := clampf(spd / 8.0, 0.0, 1.0)
	var air := not is_on_floor()
	var freq := 2.1 + 3.4 * k_move
	var amp := 0.085 + 0.20 * k_move
	var trail := 0.10 + 0.55 * k_move
	for side: String in ["L", "R"]:
		var sgn := 1.0 if side == "L" else -1.0
		var side_ph := 0.0 if side == "L" else 1.5
		for k in range(1, 4):
			var fk := float(k)
			var ph := t * freq - fk * 0.7 + side_ph
			var sway := sin(ph) * amp * fk
			var curl := cos(ph * 0.83) * amp * 0.75 * fk * sgn
			# 越靠近末端后掠越明显；腾空时再放大一些
			var back := trail * fk * (1.45 if air else 1.0)
			p["rib.%s.%d" % [side, k]] = Vector3(sway + back, 0.0, curl)
	if _guard_blend > 0.01:
		p = _guard_pose(p, _guard_blend)
	return p


func _update_model_pose(delta: float) -> void:
	## 平滑过渡到目标姿势并应用到骨骼
	var target := _pose_target()
	# 闪避只有 0.18s，用更快的过渡速率保证姿势立刻到位
	var blend := minf(delta * (26.0 if dash_t > 0.0 else 14.0), 1.0)
	for bname: String in _bones:
		var goal: Vector3 = target.get(bname, Vector3.ZERO)
		var cur: Vector3 = _pose_cur.get(bname, Vector3.ZERO)
		cur = cur.lerp(goal, blend)
		_pose_cur[bname] = cur
		var i: int = _bones[bname]
		var rest := skel.get_bone_rest(i).basis.get_rotation_quaternion()
		skel.set_bone_pose_rotation(i, rest * Quaternion.from_euler(cur))


func _update_spear_follow() -> void:
	if _motion and spear:
		var hand_index: int = _bones["hand.r"]
		var hand_transform := skel.global_transform * skel.get_bone_global_pose(hand_index)
		var grip_basis := Basis(Quaternion(Vector3.UP, _motion.weapon_axis()))
		var grip := Transform3D(grip_basis, NezhaMotion.GRIP)
		grip.origin += grip_basis.y * 0.25
		spear.transform = gfx.global_transform.affine_inverse() * hand_transform * grip
		return
	## 非攻击状态下火尖枪握于右手：枪杆穿过手掌，握点在杆的下三分之一。
	## 只跟随"手的位置 + 固定倾角"，不跟手骨自身旋转（否则枪会乱甩）；
	## 攻击动作期间由 Tween 接管突刺/横扫。
	if spear == null or act in ["atk1", "atk2", "atk3", "heavy"]:
		return
	var hi: int = _bones.get("hand.R", -1)
	if hi < 0:
		return
	var hand_world: Transform3D = skel.global_transform * skel.get_bone_global_pose(hi)
	var hand_local: Vector3 = gfx.global_transform.affine_inverse() * hand_world.origin
	# 倾角：待机斜握约 -16°，跑动时更平（枪身往后掠）
	var lean := clampf(absf(velocity.x) * 1.2, 0.0, 12.0)
	var tilt := deg_to_rad(-16.0 - lean)
	var up := Basis.from_euler(Vector3(0.0, 0.0, tilt)).y
	# 枪长 1.9m、手位约 0.7m：把杆中心抬到手心上方 0.25m，
	# 这样握点落在杆下 1/3，枪尾离地约 5cm，不会插进地里
	var want_pos: Vector3 = hand_local + up * 0.25
	spear.position = spear.position.lerp(want_pos, 0.55)
	spear.rotation_degrees = Vector3(0.0, 0.0, rad_to_deg(tilt))


func _anim_thrust(reach: float, dur: float) -> void:
	if spear == null or _motion:
		return
	var tw := spear.create_tween()
	tw.tween_property(spear, "rotation_degrees", Vector3(0, 0, -90), dur * 0.5)
	tw.parallel().tween_property(spear, "position",
		Vector3(0.45 + reach, 1.0, 0.06), dur)
	tw.tween_interval(0.06)
	tw.tween_property(spear, "position", Vector3(0.3, 0.95, 0.06), 0.12)
	tw.parallel().tween_property(spear, "rotation_degrees",
		Vector3(0, 0, -18), 0.12)


func _anim_heavy() -> void:
	if spear == null or _motion:
		return
	var tw := spear.create_tween()
	tw.tween_property(spear, "rotation_degrees", Vector3(0, 0, 50), 0.3)
	tw.parallel().tween_property(spear, "position", Vector3(-0.1, 1.1, 0.06), 0.3)
	tw.tween_property(spear, "rotation_degrees", Vector3(0, 0, -100), 0.1) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(spear, "position", Vector3(1.3, 1.0, 0.06), 0.1)
	tw.tween_interval(0.08)
	tw.tween_property(spear, "rotation_degrees", Vector3(0, 0, -18), 0.15)
	tw.parallel().tween_property(spear, "position", Vector3(0.3, 0.95, 0.06), 0.15)


func _update_anim(delta: float, axis: float) -> void:
	if use_sprites:
		# 立绘姿态切换 + 镜像
		sprite.flip_h = facing < 0.0
		if act in ["atk1", "atk2", "atk3", "heavy", "skill", "plunge"]:
			_set_sprite_tex(_tex_attack)
		elif not is_on_floor():
			_set_sprite_tex(_tex_jump)
		elif absf(velocity.x) > 0.5:
			_set_sprite_tex(_tex_run)
		else:
			_set_sprite_tex(_tex_idle)
	elif model:
		# 3D 模型：转身朝向 + 骨骼动作 + 武器跟手
		_target_yaw = 0.0 if facing > 0.0 else PI
		gfx.rotation.y = lerp_angle(gfx.rotation.y, _target_yaw, 14.0 * delta)
		if skel:
			if _motion:
				_motion.update(self, delta)
			else:
				_update_model_pose(delta)
			_update_spear_follow()
		# 脚下乾坤圈自转 + 轻微上下浮动（像踩着转轮悬浮）
		if _foot_ring:
			var spin := 3.0 + absf(velocity.x) * 1.8
			_foot_ring.rotation.y += delta * spin
			# 注意：模型是 Z-up 资产，圈节点的"本地 Y"并不是世界竖直方向，
			# 直接用 Vector3(0,-d,0) 会把它往侧面推。这里把世界"下"换算到父节点空间。
			var fparent := _foot_ring.get_parent() as Node3D
			var local_down := Vector3.DOWN
			if fparent:
				local_down = (fparent.global_transform.basis.inverse() * Vector3.DOWN).normalized()
			var bob := sin(_anim_time * 3.1) * 0.015
			_foot_ring.position = _foot_ring_base + local_down * (RING_DROP - bob)
		if _motion:
			gfx.scale = Vector3.ONE
		elif not is_on_floor():
			gfx.scale = gfx.scale.lerp(Vector3(0.97, 1.04, 0.97), 8.0 * delta)
		else:
			gfx.scale = gfx.scale.lerp(Vector3.ONE, 8.0 * delta)
	else:
		# 朝向
		_target_yaw = 0.0 if facing > 0.0 else PI
		gfx.rotation.y = lerp_angle(gfx.rotation.y, _target_yaw, 14.0 * delta)
		# 乾坤圈旋转
		ring.rotation.y += delta * 1.5
		# 风火轮旋转（速度随移动）
		var spin := 4.0 + absf(velocity.x) * 2.0
		wheel_f.rotation.x += delta * spin
		wheel_b.rotation.x += delta * spin
		# 混天绫飘动
		var wv := _anim_time * 5.0
		ribbon_l.rotation.z = deg_to_rad(28.0 + sin(wv) * 14.0
			- velocity.x * facing * 1.2)
		ribbon_r.rotation.z = deg_to_rad(12.0 + sin(wv + 1.7) * 12.0
			- velocity.x * facing * 1.2)
		ribbon_l.position.y = 1.35 + sin(wv * 0.8) * 0.05
		ribbon_r.position.y = 1.25 + sin(wv * 0.8 + 2.0) * 0.05
	# 奔跑前倾 + 浮动
	if _motion:
		gfx.rotation.z = 0.0
		gfx.position.y = 0.0
	else:
		var lean := clampf(velocity.x * facing * 0.022, -0.05, 0.18)
		gfx.rotation.z = lerpf(gfx.rotation.z,
			-lean * (facing if use_sprites else 1.0), 10.0 * delta)
		if is_on_floor() and absf(velocity.x) > 0.5:
			gfx.position.y = absf(sin(_anim_time * 9.0)) * 0.06
		else:
			gfx.position.y = lerpf(gfx.position.y, 0.03 + sin(_anim_time * 2.0) * 0.03,
				6.0 * delta)
	# 无敌帧闪烁
	if invuln > 0.0 and dash_t <= 0.0:
		gfx.visible = fmod(_anim_time, 0.14) > 0.05
	else:
		gfx.visible = true


# ---------------------------------------------------------------- 生命

func take_damage(dmg: float, from_x: float = 0.0) -> void:
	if act == "dead":
		return
	# 完美闪身：冲刺无敌帧内承受攻击 → 时缓 + 回灵
	if dash_t > 0.0:
		if not _pd_done:
			_pd_done = true
			add_energy(15.0)
			Game.play_sfx("ui", -2.0, 1.7)
			Game.hitstop(0.45, 0.25)
			Game.spawn_dmg_text(get_parent(),
				global_position + Vector3(0, 1.9, 0), "完美闪身！",
				Color(0.45, 0.95, 0.95), true)
			Game.burst(get_parent(), global_position + Vector3(0, 1, 0),
				Color(0.45, 0.95, 0.95), 20, 5.0, 0.08, 0.5)
		return
	if invuln > 0.0:
		return
	hp = maxf(hp - dmg, 0.0)
	hp_changed.emit(hp, MAX_HP)
	invuln = 0.9
	act = "hurt"
	if _motion:
		_motion.trigger("hurt")
	act_t = 0.0
	attack_queued = false
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector3(dir * 7.0, 5.0, 0)
	Game.play_sfx("hurt", -4.0)
	Game.shake(0.5)
	Game.flash_meshes(gfx, Color(1.0, 0.3, 0.3))
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 1.8, 0),
		"-%d" % int(dmg), Color(1.0, 0.35, 0.3))
	if hp <= 0.0:
		_die()


func _die() -> void:
	act = "dead"
	Game.death_count += 1
	velocity = Vector3.ZERO
	Game.play_sfx("enemy_die", -2.0, 0.6)
	Game.burst(get_parent(), global_position + Vector3(0, 1, 0),
		C_FIRE, 50, 9.0, 0.12, 1.0)
	Game.burst(get_parent(), global_position + Vector3(0, 1, 0),
		Color(0.9, 0.2, 0.2), 30, 6.0, 0.1, 0.8)
	if _motion:
		_motion.trigger("dead")
		gfx.visible = true
	else:
		gfx.visible = false
	died.emit()


func respawn(pos: Vector3) -> void:
	if _motion:
		_motion.reset()
	global_position = pos
	velocity = Vector3.ZERO
	hp = MAX_HP
	act = "free"
	act_t = 0.0
	invuln = 1.2
	gfx.visible = true
	# 定潮状态复位：潮纹不回满（本关莲台复活属于同一个"段落"），但窗口/吸附必须清掉
	_tide_cancel()
	_tide_guard_t = 0.0
	_tide_reuse_t = 0.0
	_tide_cd_t = 0.0
	_tide_move_lock_t = 0.0
	_guard_blend = 0.0
	_guard_mode = "neutral"
	_tide_hold_t = 0.0
	hp_changed.emit(hp, MAX_HP)
	Game.burst(get_parent(), pos + Vector3(0, 0.8, 0),
		Color(0.5, 0.95, 0.85), 30, 5.0, 0.09, 0.7)


func heal(v: float) -> void:
	if act == "dead":
		return
	hp = minf(hp + v, MAX_HP)
	hp_changed.emit(hp, MAX_HP)
	Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 1.8, 0),
		"+%d" % int(v), Color(0.4, 1.0, 0.55))


func add_energy(v: float) -> void:
	energy = clampf(energy + v, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)


# ================================================================ 第四章：定潮
# 一个起手、两个命中分叉：
#   短按 → 0.20s 防护窗口（前 0.18s 为完美）；窗口内撞上「可弹投射物」= 卸（反弹）
#   窗口内被「带起手的近战」命中 = 架（免伤 + 反震 + 敌人僵直）
#   按住 ≥ 0.20s → 引潮：8m / 120° 内吸附弹幕，松手齐射
# 潮纹（0~3）只由攻击命中赚；完美弹反返还 1 格。

func is_guarding() -> bool:
	return _tide_guard_t > 0.0


func guard_accepts_melee() -> bool:
	## 敌方近战命中判定前先问：现在能不能架住我？
	return _tide_guard_t > 0.0 and _tide_reuse_t <= 0.0 and act != "dead"


func _tide_busy() -> bool:
	return _tide_guard_t > 0.0 or _tide_reuse_t > 0.0 \
		or _tide_move_lock_t > 0.0 or _pulling


func _tide_tick(delta: float) -> void:
	_tide_cd_t = maxf(_tide_cd_t - delta, 0.0)
	_tide_reuse_t = maxf(_tide_reuse_t - delta, 0.0)
	_tide_move_lock_t = maxf(_tide_move_lock_t - delta, 0.0)
	_guard_mode_t = maxf(_guard_mode_t - delta, 0.0)
	_parry_flash_t = maxf(_parry_flash_t - delta, 0.0)
	if _tide_guard_t > 0.0:
		_tide_guard_t = maxf(_tide_guard_t - delta, 0.0)
	if _guard_mode_t <= 0.0 and _tide_guard_t <= 0.0:
		_guard_mode = "neutral"
	if _pulling:
		_pull_t += delta
		_pull_process(delta)
		if _pull_t >= TIDE_PULL_TIME:
			_tide_release()
	# 起手快、收招慢：0.07s 混入 / 0.12s 混出
	var want := 1.0 if (_tide_guard_t > 0.0 or _pulling or _parry_flash_t > 0.0) else 0.0
	var dur := 0.07 if want > 0.5 else 0.12
	_guard_blend = move_toward(_guard_blend, want, delta / dur)


func _tide_input(delta: float) -> void:
	if act == "dead" or dash_t > 0.0:
		return
	if not Game.tide_unlocked:
		return   # 前三章没有定潮
	if Input.is_action_just_pressed("tide") and act == "free" and not _tide_busy():
		_tide_press()
	if Input.is_action_pressed("tide") and not _pulling and _tide_guard_t > 0.0:
		_tide_hold_t += delta
		if _tide_hold_t >= TIDE_HOLD_FOR_PULL:
			_start_pull()
	if Input.is_action_just_released("tide"):
		if _pulling:
			_tide_release()
		_tide_hold_t = 0.0


func _tide_press() -> void:
	if _tide_cd_t > 0.0 or _tide_reuse_t > 0.0:
		Game.play_sfx("tide_empty", -12.0)
		return
	if tide_runes < 1.0:
		# 0 格：水膜无法成形（不消耗、不进入窗口）
		Game.play_sfx("tide_empty", -8.0, 0.85)
		Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 1.9, 0),
			"潮纹不足", Color(1.0, 0.55, 0.4))
		runes_changed.emit(tide_runes, TIDE_RUNE_MAX)
		return
	# 起手先付 1 格：空挥也照扣（这就是"不能乱按"的代价）
	tide_runes = maxf(tide_runes - 1.0, 0.0)
	runes_changed.emit(tide_runes, TIDE_RUNE_MAX)
	_tide_guard_t = TIDE_PARRY_WINDOW
	_tide_cd_t = TIDE_CD
	_tide_hold_t = 0.0
	_guard_mode = "neutral"
	_guard_mode_t = 0.0
	_build_tide_fx()
	Game.play_sfx("tide_cast", -6.0)
	Game.burst(get_parent(), global_position + Vector3(0, 1.0, 0),
		Color(0.35, 0.92, 0.88), 10, 3.0, 0.05, 0.3)


func _start_pull() -> void:
	if _pulling:
		return
	if energy < TIDE_PULL_COST:
		Game.play_sfx("tide_empty", -10.0)
		return
	energy -= TIDE_PULL_COST
	energy_changed.emit(energy, MAX_ENERGY)
	_pulling = true
	_pull_t = 0.0
	_tide_guard_t = 0.0        # 引潮期间不能弹反（吸附本身已经让弹幕无害）
	_tide_hold_t = 0.0
	if _pull_player:
		_pull_player.pitch_scale = 1.0
		_pull_player.play()
	Game.burst(get_parent(), global_position + Vector3(0, 0.9, 0),
		Color(0.35, 0.92, 0.88), 16, 3.5, 0.06, 0.35)


func _pull_process(delta: float) -> void:
	var origin := global_position + Vector3(0, 0.9, 0)
	var front := Vector3(facing, 0.0, 0.0)
	if _pull_list.size() < TIDE_PULL_MAX:
		for b in get_tree().get_nodes_in_group("projectiles"):
			if not (b is Projectile):
				continue
			var pr := b as Projectile
			if not is_instance_valid(pr) or pr.team != Projectile.TEAM_ENEMY:
				continue
			if pr.held or pr.is_muddy or not pr.parryable:
				continue
			var rel: Vector3 = pr.global_position - origin
			if rel.length() > TIDE_PULL_RADIUS:
				continue
			var flat := Vector3(rel.x, 0.0, rel.z)
			if flat.length() > 0.05 and flat.normalized().dot(front) < TIDE_PULL_COS:
				continue
			if absf(rel.y) > 3.5:
				continue
			pr.hold()
			_pull_list.append(pr)
			Game.play_sfx("tide_pull", -15.0, 1.0 + 0.07 * float(_pull_list.size()))
			if _pull_list.size() >= TIDE_PULL_MAX:
				break
	var n := _pull_list.size()
	for i in n:
		var pr: Projectile = _pull_list[i]
		if not is_instance_valid(pr) or not pr.held:
			continue
		var off := 0.0 if n <= 1 else (float(i) / float(n - 1) - 0.5) * 1.1
		var hover := origin + front * TIDE_PULL_HOVER + Vector3(0.0, off, 0.0)
		pr.global_position = pr.global_position.lerp(hover, clampf(10.0 * delta, 0.0, 1.0))


func _tide_release() -> void:
	if not _pulling:
		return
	_pulling = false
	var n := _pull_list.size()
	for i in n:
		var pr: Projectile = _pull_list[i]
		if not is_instance_valid(pr) or not (pr is Projectile):
			continue
		var ang := 0.0
		if n > 1:
			ang = deg_to_rad(lerpf(-18.0, 18.0, float(i) / float(n - 1)))
		pr.volley(facing, ang, VOLLEY_DMG)
	_pull_list.clear()
	_tide_move_lock_t = TIDE_MOVE_LOCK
	_guard_mode = "neutral"
	if _pull_player and _pull_player.playing:
		_pull_player.stop()
	if n > 0:
		Game.play_sfx("tide_volley", -4.0)
		Game.hitstop(0.03, 0.05)
		Game.shake(0.20)
		Game.burst(get_parent(), global_position + Vector3(facing * 1.6, 1.0, 0),
			Color(0.42, 0.95, 0.86), 18, 5.0, 0.07, 0.4)


func _tide_cancel() -> void:
	if _pulling:
		for pr in _pull_list:
			if is_instance_valid(pr) and pr is Projectile:
				(pr as Projectile).resume()
		_pull_list.clear()
	_pulling = false
	_tide_guard_t = 0.0
	_tide_hold_t = 0.0
	if _pull_player and _pull_player.playing:
		_pull_player.stop()


func _guard_sweep() -> void:
	## 水膜盾在命中前就拦下弹幕：2.6m、正面 120°
	if _tide_guard_t <= 0.0 or _tide_reuse_t > 0.0:
		return
	var origin := global_position + Vector3(0, 0.9, 0)
	var front := Vector3(facing, 0.0, 0.0)
	for b in get_tree().get_nodes_in_group("projectiles"):
		if not (b is Projectile):
			continue
		var pr := b as Projectile
		if not is_instance_valid(pr) or pr.team != Projectile.TEAM_ENEMY:
			continue
		if pr.held or pr.is_muddy or not pr.parryable:
			continue
		var rel: Vector3 = pr.global_position - origin
		if rel.length() > TIDE_GUARD_RADIUS:
			continue
		# 只按水平夹角判断：浮母/炮台从高处打下来的弹，垂直分量很大，
		# 用 3D 点乘会把"正上方来的弹"判成背后，这才是弹反手感玄学的来源。
		var flat := Vector3(rel.x, 0.0, rel.z)
		if flat.length() > 0.05 and flat.normalized().dot(front) < TIDE_GUARD_COS:
			continue
		if absf(rel.y) > 2.6:
			continue
		if try_parry_projectile(pr):
			return


func try_parry_projectile(pr: Projectile) -> bool:
	## 由「卸」调用：把这一枚弹回去
	if pr == null or not is_instance_valid(pr):
		return false
	if _tide_guard_t <= 0.0 or _tide_reuse_t > 0.0:
		return false
	if pr.held or pr.is_muddy or not pr.parryable or pr.team != Projectile.TEAM_ENEMY:
		return false
	var perfect := (TIDE_PARRY_WINDOW - _tide_guard_t) <= TIDE_PERFECT
	var dmg := REFLECT_DMG_PERFECT if perfect else REFLECT_DMG
	pr.reflect(facing, dmg, self)
	_guard_mode = "front"
	_guard_mode_t = 0.25
	_parry_success(perfect, "front")
	return true


func try_parry_melee(enemy: Node) -> bool:
	## 由敌方近战调用：架住这一下（免伤 + 反震 + 敌人僵直）
	if _tide_guard_t <= 0.0 or _tide_reuse_t > 0.0:
		return false
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Node3D):
		return false
	var perfect := (TIDE_PARRY_WINDOW - _tide_guard_t) <= TIDE_PERFECT
	if enemy.has_method("on_parried"):
		enemy.on_parried(global_position.x)
	if perfect and enemy.has_method("open_break"):
		enemy.open_break(PARRY_BREAK_TIME)
	_guard_mode = "cross"
	_guard_mode_t = 0.35
	# 架住的核心奖励：只给 0.1s 无敌，不进硬直，可以立刻反打
	invuln = maxf(invuln, 0.10)
	_parry_success(perfect, "cross")
	return true


func _parry_success(perfect: bool, mode: String) -> void:
	_tide_reuse_t = TIDE_REUSE_LOCK
	_tide_guard_t = 0.0
	_tide_move_lock_t = 0.0
	_parry_flash_t = 0.22
	hit_landed.emit(2 if perfect else 1)
	# 成功即返还这 1 格：空挥照扣，"弹中了"不该还倒贴资源。
	# 完美不再额外加格，避免无脑连弹把资源刷满。
	_gain_rune(1.0)
	if mode == "front":
		if perfect:
			Game.parry_moment(0.11, 0.35)   # 时间稀释：让"弹中了"这一下被看见
		else:
			Game.hitstop(0.05, 0.05)
		Game.shake(0.35 if perfect else 0.12)
		Game.play_sfx("parry", -3.0, 1.25 if perfect else 1.0)
		if perfect:
			Game.play_sfx("parry_perfect", -4.0)
		Game.burst(get_parent(), global_position + Vector3(facing * 1.2, 1.0, 0),
			Color(0.45, 0.95, 0.92) if not perfect else Color(0.95, 0.9, 0.55),
			18 if perfect else 12, 4.5, 0.07, 0.45)
		Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 2.0, 0),
			"弹!" if perfect else "卸",
			Color(0.55, 0.95, 0.9) if not perfect else Color(1.0, 0.9, 0.55), perfect)
	else:
		if perfect:
			Game.parry_moment(0.12, 0.32)
		else:
			Game.hitstop(0.07, 0.05)
		Game.shake(0.50 if perfect else 0.30)
		Game.play_sfx("parry_melee", -2.0, 1.2 if perfect else 1.0)
		if perfect:
			Game.play_sfx("parry_melee_perfect", -3.0)
			Game.spawn_dmg_text(get_parent(), global_position + Vector3(0, 2.2, 0),
				"架!", Color(1.0, 0.88, 0.5), true)
		Game.burst(get_parent(), global_position + Vector3(facing * 1.0, 1.1, 0),
			Color(0.92, 0.95, 0.88), 16, 4.0, 0.07, 0.4)
		camera_punch(0.08 if perfect else 0.05)


func camera_punch(amount: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("punch"):
		cam.punch(amount)


func _add_rune(v: float) -> void:
	_gain_rune(v)


func _gain_swing_rune(v: float) -> void:
	## 单次挥击封顶，防 AoE 一刀刷满
	var room := RUNE_SWING_CAP - _rune_swing_gain
	if room <= 0.0:
		return
	var g := minf(v, room)
	_rune_swing_gain += g
	_gain_rune(g)


func _gain_rune(v: float) -> void:
	if v <= 0.0:
		return
	var old := floorf(tide_runes)
	tide_runes = minf(tide_runes + v, TIDE_RUNE_MAX)
	if floorf(tide_runes) > old:
		Game.play_sfx("rune_gain", -12.0, 1.0 + 0.12 * old)
	runes_changed.emit(tide_runes, TIDE_RUNE_MAX)


func _build_tide_fx() -> void:
	if _tide_fx_root != null:
		return
	_tide_fx_root = Node3D.new()
	_tide_fx_root.position.y = 1.0
	add_child(_tide_fx_root)
	var mat := Game.std_mat(Color(0.32, 0.9, 0.86, 0.55),
		Color(0.35, 0.95, 0.9), 2.0, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 4
		var mi := Game.add_mesh(_tide_fx_root, torus, mat, Vector3.ZERO)
		mi.rotation_degrees.z = 90.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_tide_fx.append(mi)


func _update_tide_fx(_delta: float) -> void:
	if _tide_fx.is_empty():
		return
	var vis := _guard_blend > 0.03
	for i in _tide_fx.size():
		var mi: MeshInstance3D = _tide_fx[i]
		mi.visible = vis
		if not vis:
			continue
		var r := lerpf(0.30, 1.0, _guard_blend)
		var push := 0.30 + 0.22 * float(i)
		if _guard_mode == "front":
			r *= 1.0 + 0.9 * (1.0 - _tide_guard_t / TIDE_PARRY_WINDOW)
			push = 0.55 + 0.35 * float(i) + 0.5 * (1.0 - _tide_guard_t / TIDE_PARRY_WINDOW)
		elif _guard_mode == "cross":
			r *= 0.55
			push = 0.30
		mi.scale = Vector3.ONE * r * (1.0 + 0.06 * float(i))
		mi.position = Vector3(facing * push, 0.0, 0.0)


func _guard_pose(p: Dictionary, w: float) -> Dictionary:
	## 定潮叠加层：起手中性 → 命中后分叉（卸/架）
	var t := {}
	match _guard_mode:
		"front":
			t["upper_arm.R"] = Vector3(-1.6, 0.0, 0.16)
			t["forearm.R"] = Vector3(-0.14, 0.0, 0.0)
			t["upper_arm.L"] = Vector3(0.55, 0.0, -0.42)
			t["forearm.L"] = Vector3(-0.7, 0.0, 0.0)
			t["chest"] = Vector3(-0.16, 0.0, 0.22)
			t["head"] = Vector3(-0.10, 0.0, -0.08)
			t["hips"] = Vector3(0.08, 0.0, 0.0)
			t["thigh.L"] = Vector3(-0.22, 0.0, 0.0)
			t["shin.L"] = Vector3(0.30, 0.0, 0.0)
		"cross":
			t["upper_arm.L"] = Vector3(-1.52, 0.0, -0.52)
			t["upper_arm.R"] = Vector3(-1.52, 0.0, 0.52)
			t["forearm.L"] = Vector3(-1.30, 0.0, -0.30)
			t["forearm.R"] = Vector3(-1.30, 0.0, 0.30)
			t["chest"] = Vector3(0.22, 0.0, 0.0)
			t["head"] = Vector3(0.18, 0.0, 0.0)
			t["hips"] = Vector3(0.15, 0.0, 0.0)
			t["thigh.L"] = Vector3(-0.30, 0.0, 0.0)
			t["shin.L"] = Vector3(0.42, 0.0, 0.0)
			t["thigh.R"] = Vector3(0.16, 0.0, 0.0)
			t["shin.R"] = Vector3(0.30, 0.0, 0.0)
		_:
			# 起手「沉潮」：双手在胸前交叠、重心下沉、头略低
			t["upper_arm.L"] = Vector3(-0.92, 0.0, -0.34)
			t["upper_arm.R"] = Vector3(-0.92, 0.0, 0.34)
			t["forearm.L"] = Vector3(-1.55, 0.0, -0.12)
			t["forearm.R"] = Vector3(-1.55, 0.0, 0.12)
			t["chest"] = Vector3(-0.06, 0.0, 0.0)
			t["head"] = Vector3(-0.14, 0.0, 0.0)
			t["hips"] = Vector3(0.10, 0.0, 0.0)
			t["thigh.L"] = Vector3(-0.20, 0.0, 0.0)
			t["shin.L"] = Vector3(0.28, 0.0, 0.0)
			t["thigh.R"] = Vector3(-0.14, 0.0, 0.0)
			t["shin.R"] = Vector3(0.20, 0.0, 0.0)
	# 混天绫：起手绷成弓弦，卸向前甩成网，架在左臂上缠两圈
	for side: String in ["L", "R"]:
		for k in range(1, 4):
			var fk := float(k)
			var key := "rib.%s.%d" % [side, k]
			var v := Vector3.ZERO
			if _guard_mode == "front":
				v = Vector3(-0.55 * fk, 0.0, 0.12 * fk)
			elif _guard_mode == "cross":
				v = Vector3(-0.35 * fk, 0.0, 0.30 * fk * (1.0 if side == "L" else -1.0))
			else:
				v = Vector3(-0.28 * fk, 0.0, 0.10 * fk * (1.0 if side == "L" else -1.0))
			t[key] = v
	for k: String in t:
		var cur: Vector3 = p.get(k, Vector3.ZERO)
		p[k] = cur.lerp(t[k], w)
	return p

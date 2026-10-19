class_name AudioSynth
extends RefCounted
## 程序化音效合成器（离线烘焙用）
## ------------------------------------------------------------------
## 原本全部塞在 autoload/game.gd 的 _ready() 里逐采样计算（每次启动 ~430ms）。
## 现在拆成静态函数：tools/bake_audio.gd 离线烘成 res://audio/*.res，
## 运行时 Game 直接 load；文件缺失时 Game 仍可回退到这里实时合成。
## ------------------------------------------------------------------

const SR := 22050
const OUT_DIR := "res://audio"

## 响度基准（实测烘焙结果）：sfx_swing 峰值 0.316（-10.0 dBFS）、
## sfx_tide 峰值 0.551（-5.2 dBFS）。第四章新增音按 swing 对齐、不超过它。
const PEAK_MAIN := 0.30   # 常规命中/施法音：比 swing 低约 0.4 dB
const PEAK_LOOP := 0.20   # 循环吸附音：持续音，峰值再压一档（-4 dB）
const PEAK_SOFT := 0.14   # 空挥闷响：比 swing 低约 7 dB
const PEAK_RUNE := 0.12   # 玉磬轻响：比 swing 低约 8.4 dB

## 需要烘焙的音效清单（名字 -> 生成函数见 build_sound）
const SOUND_NAMES := [
	"ui", "jump", "dash", "swing", "hit", "heavy", "hurt", "fire", "nova",
	"pickup", "orb", "enemy_die", "checkpoint", "gate", "roar", "shoot",
	"boss_die", "tide", "abyss",
	# 第四章：定潮 / 卸 / 架 / 引潮 / 齐射 / 空挥 / 潮纹
	"tide_cast", "parry", "parry_perfect", "parry_melee", "parry_melee_perfect",
	"tide_pull", "tide_volley", "tide_empty", "rune_gain",
]


static func _wav(samples: PackedFloat32Array, looped := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _sweep(dur: float, f0: float, f1: float, vol: float, wave: int,
		decay: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / SR
		var s := 0.0
		match wave:
			0: s = sin(phase)
			1: s = signf(sin(phase)) * 0.45
			2: s = (2.0 * fposmod(phase / TAU, 1.0) - 1.0) * 0.55
		out[i] = s * vol * exp(-decay * t)
	return out


static func _noise_burst(dur: float, vol: float, decay: float,
		lp: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += lp * (randf_range(-1.0, 1.0) - y)
		out[i] = y * vol * exp(-decay * t)
	return out


static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array,
		offset_sec := 0.0) -> PackedFloat32Array:
	var off := int(offset_sec * SR)
	var need := off + src.size()
	if dst.size() < need:
		dst.resize(need)
	for i in src.size():
		dst[off + i] += src[i]
	return dst


static func _noise_band(dur: float, vol: float, decay: float, f0: float, f1: float,
		q := 1.5) -> PackedFloat32Array:
	## 带通噪声（Chamberlin 状态变量滤波器），中心频率在 f0->f1 之间扫动。
	## 用于 whoosh / 水爆 / 绫带摩擦这类需要"有频段"的噪声；
	## decay=0 时为平包络（配合 _shape_hump 做循环音）。
	## vol 与 _sweep 一致，指峰值幅度（滤波器输出会按峰值归一，便于配比）。
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	var damp := 1.0 / maxf(q, 0.5)
	for i in n:
		var t := float(i) / n
		var f := 2.0 * sin(PI * lerpf(f0, f1, t) / SR)
		low += f * band
		var high := randf_range(-1.0, 1.0) - low - damp * band
		band += f * high
		out[i] = band * exp(-decay * t)
	var m := 0.0
	for s in out:
		m = maxf(m, absf(s))
	if m > 0.0001:
		var k := vol / m
		for i in n:
			out[i] *= k
	return out


static func _shape_hump(samples: PackedFloat32Array, power := 1.0) -> PackedFloat32Array:
	## 首尾归零的隆起包络 sin(pi*t)^power：给循环音/蓄力音用，接缝不爆音。
	var n := samples.size()
	for i in n:
		samples[i] *= pow(sin(PI * float(i) / n), power)
	return samples


static func _fit(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	## 峰值对齐到 peak（线性缩放）：噪声是随机的，每次烘焙峰值会抖，
	## 这样新增音效与 sfx_swing 的响度差始终固定。
	var m := 0.0
	for s in samples:
		m = maxf(m, absf(s))
	if m > 0.0001:
		var k := peak / m
		for i in samples.size():
			samples[i] *= k
	return samples


static func _parry_body(dur: float) -> PackedFloat32Array:
	## 卸（弹幕）命中底子：1200/1800/2600Hz 正弦族 0.2s 衰减 + 短水爆
	var m := _sweep(dur, 1200.0, 1200.0, 0.32, 0, 14.0)
	m = _mix(m, _sweep(dur * 0.9, 1800.0, 1794.0, 0.21, 0, 18.0))
	m = _mix(m, _sweep(dur * 0.8, 2600.0, 2590.0, 0.14, 0, 22.0))
	return _mix(m, _noise_band(0.09, 0.16, 16.0, 1300.0, 480.0, 1.4))


static func _melee_body() -> PackedFloat32Array:
	## 架（近战）命中底子：180Hz 冲击 + 900Hz 金属 + 绫带摩擦，更闷更重
	var m := _sweep(0.18, 185.0, 90.0, 0.48, 0, 9.0)
	m = _mix(m, _sweep(0.15, 900.0, 892.0, 0.30, 0, 16.0), 0.004)
	m = _mix(m, _sweep(0.12, 1350.0, 1342.0, 0.13, 0, 20.0), 0.004)
	m = _mix(m, _noise_band(0.14, 0.26, 10.0, 650.0, 160.0, 1.1))
	return _mix(m, _noise_burst(0.08, 0.45, 20.0, 0.30), 0.002)


static func sound(name: String) -> AudioStreamWAV:
	match name:
		"ui":
			return _wav(_sweep(0.12, 880, 1300, 0.22, 0, 10.0))
		"jump":
			return _wav(_sweep(0.18, 320, 680, 0.22, 0, 9.0))
		"dash":
			return _wav(_noise_burst(0.22, 0.55, 11.0, 0.45))
		"swing":
			return _wav(_noise_burst(0.12, 0.5, 16.0, 0.7))
		"hit":
			var hit := _noise_burst(0.14, 0.6, 14.0, 0.6)
			return _wav(_mix(hit, _sweep(0.12, 200, 90, 0.5, 0, 10.0)))
		"heavy":
			var heavy := _sweep(0.3, 110, 45, 0.7, 0, 7.0)
			return _wav(_mix(heavy, _noise_burst(0.18, 0.5, 10.0, 0.4)))
		"hurt":
			return _wav(_sweep(0.25, 420, 130, 0.4, 1, 7.0))
		"fire":
			var fire := _noise_burst(0.55, 0.55, 5.0, 0.18)
			return _wav(_mix(fire, _sweep(0.5, 90, 50, 0.45, 2, 4.0)))
		"nova":
			var nova := _noise_burst(0.8, 0.7, 4.0, 0.15)
			return _wav(_mix(nova, _sweep(0.7, 130, 40, 0.6, 2, 3.5)))
		"pickup":
			var pick := _sweep(0.1, 660, 660, 0.22, 0, 6.0)
			return _wav(_mix(pick, _sweep(0.16, 990, 990, 0.22, 0, 6.0), 0.09))
		"orb":
			return _wav(_sweep(0.1, 1200, 1500, 0.16, 0, 12.0))
		"enemy_die":
			var edie := _noise_burst(0.3, 0.5, 8.0, 0.4)
			return _wav(_mix(edie, _sweep(0.35, 380, 70, 0.4, 2, 6.0)))
		"checkpoint":
			var cp := _sweep(0.4, 523, 523, 0.2, 0, 4.0)
			cp = _mix(cp, _sweep(0.4, 659, 659, 0.2, 0, 4.0), 0.13)
			cp = _mix(cp, _sweep(0.6, 784, 784, 0.22, 0, 3.0), 0.26)
			return _wav(cp)
		"gate":
			var gate := _noise_burst(0.8, 0.4, 3.0, 0.12)
			return _wav(_mix(gate, _sweep(0.8, 55, 40, 0.5, 2, 2.5)))
		"roar":
			var roar := _sweep(0.9, 75, 38, 0.55, 2, 2.2)
			roar = _mix(roar, _sweep(0.9, 113, 55, 0.35, 2, 2.2))
			return _wav(_mix(roar, _noise_burst(0.7, 0.35, 3.0, 0.2)))
		"shoot":
			return _wav(_sweep(0.13, 520, 210, 0.3, 1, 9.0))
		"boss_die":
			var bdie := _noise_burst(1.4, 0.6, 2.0, 0.2)
			return _wav(_mix(bdie, _sweep(1.3, 160, 30, 0.6, 2, 1.8)))
		"tide":
			# 水涌：宽带噪声 + 下滑的水声
			var tide := _noise_burst(0.65, 0.45, 4.0, 0.16)
			return _wav(_mix(tide, _sweep(0.65, 190, 55, 0.4, 0, 3.0)))
		"abyss":
			# 海眼低鸣：极低频 + 缓慢起伏
			var abyss := _sweep(1.4, 58, 34, 0.5, 2, 1.6)
			abyss = _mix(abyss, _sweep(1.4, 87, 51, 0.3, 2, 1.6))
			return _wav(_mix(abyss, _noise_burst(1.1, 0.22, 2.2, 0.1)))
		"tide_cast":
			# 定潮起手：0.14s 低频 whoosh（带通 200->900Hz）+ 三颗水泡
			var cast := _noise_band(0.14, 0.42, 5.0, 200.0, 900.0, 1.6)
			cast = _mix(cast, _sweep(0.045, 620.0, 1180.0, 0.28, 0, 16.0), 0.020)
			cast = _mix(cast, _sweep(0.040, 780.0, 1420.0, 0.24, 0, 18.0), 0.058)
			cast = _mix(cast, _sweep(0.036, 540.0, 1080.0, 0.19, 0, 20.0), 0.100)
			return _wav(_fit(cast, PEAK_MAIN))
		"parry":
			# 卸（弹幕）命中：金属脆响 + 短水爆
			return _wav(_fit(_parry_body(0.20), PEAK_MAIN))
		"parry_perfect":
			# 卸·完美：parry + 高八度泛音 + 0.35s 尾响
			var perfect := _parry_body(0.22)
			perfect = _mix(perfect, _sweep(0.18, 2400.0, 2400.0, 0.12, 0, 15.0), 0.010)
			perfect = _mix(perfect, _sweep(0.16, 3600.0, 3590.0, 0.08, 0, 18.0), 0.010)
			perfect = _mix(perfect, _sweep(0.35, 4800.0, 4790.0, 0.03, 0, 5.0), 0.020)
			return _wav(_fit(perfect, PEAK_MAIN))
		"parry_melee":
			# 架（近战）命中：更闷更重的低频冲击 + 闷金属 + 绫带摩擦
			return _wav(_fit(_melee_body(), PEAK_MAIN))
		"parry_melee_perfect":
			# 架·完美：parry_melee + 80Hz 低频"咚" + 升调泛音，尾响 0.3s
			var melee_p := _melee_body()
			melee_p = _mix(melee_p, _sweep(0.30, 82.0, 56.0, 0.52, 0, 6.5))
			melee_p = _mix(melee_p, _sweep(0.30, 700.0, 1600.0, 0.22, 0, 5.0), 0.010)
			melee_p = _mix(melee_p, _sweep(0.28, 2100.0, 2150.0, 0.06, 0, 6.0), 0.030)
			return _wav(_fit(melee_p, PEAK_MAIN))
		"tide_pull":
			# 引潮吸附循环：0.6s 低频吸气，首尾归零可无缝循环（音高交由代码 pitch 调）
			var pull := _noise_band(0.6, 0.50, 0.0, 120.0, 560.0, 1.2)
			pull = _mix(pull, _sweep(0.6, 88.0, 148.0, 0.40, 2, 0.0))
			pull = _mix(pull, _sweep(0.6, 176.0, 296.0, 0.20, 0, 0.0))
			return _wav(_fit(_shape_hump(pull, 1.6), PEAK_LOOP), true)
		"tide_volley":
			# 齐射：水箭簇发（噪声 + 快速下扫）+ 低音冲击
			var volley := _noise_band(0.16, 0.50, 8.0, 1800.0, 320.0, 1.5)
			volley = _mix(volley, _sweep(0.18, 950.0, 180.0, 0.35, 1, 8.0), 0.010)
			volley = _mix(volley, _sweep(0.30, 120.0, 48.0, 0.50, 0, 7.0))
			volley = _mix(volley, _noise_band(0.12, 0.32, 12.0, 2400.0, 700.0, 1.6), 0.035)
			volley = _mix(volley, _noise_band(0.10, 0.26, 14.0, 2600.0, 900.0, 1.6), 0.070)
			return _wav(_fit(volley, PEAK_MAIN))
		"tide_empty":
			# 0 格 / 空挥：0.12s 闷响
			var empty := _noise_burst(0.12, 0.50, 18.0, 0.16)
			empty = _mix(empty, _sweep(0.12, 150.0, 72.0, 0.35, 0, 12.0))
			return _wav(_fit(empty, PEAK_SOFT))
		"rune_gain":
			# 攒满一格潮纹：极轻玉磬一响（1760/2640/3520Hz 干净泛音，0.25s 衰减）
			var rune := _sweep(0.25, 1760.0, 1760.0, 0.26, 0, 8.0)
			rune = _mix(rune, _sweep(0.22, 2640.0, 2640.0, 0.13, 0, 10.0))
			rune = _mix(rune, _sweep(0.18, 3520.0, 3520.0, 0.06, 0, 12.0))
			return _wav(_fit(rune, PEAK_RUNE))
	return null


static func make_ambient() -> AudioStreamWAV:
	## 8 秒海渊环境循环：低频持续音 + 缓慢起伏的浪涌噪声
	var n := SR * 8
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var ph1 := 0.0
	var ph2 := 0.0
	var ph3 := 0.0
	for i in n:
		var t := float(i) / SR
		ph1 += TAU * 55.0 / SR
		ph2 += TAU * 82.4 / SR
		ph3 += TAU * 110.0 / SR
		var swell := 0.5 + 0.5 * sin(TAU * t / 8.0)
		y += 0.05 * (randf_range(-1.0, 1.0) - y)
		var drone := sin(ph1) * 0.16 + sin(ph2) * 0.09 + sin(ph3) * 0.05
		out[i] = drone + y * (0.25 + 0.45 * swell)
	return _wav(out, true)


static func make_theme() -> AudioStreamWAV:
	## 16 秒主题循环：五声音阶钟声漂浮在低音之上
	var n := SR * 16
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		ph += TAU * 110.0 / SR
		out[i] = sin(ph) * 0.10 * (0.6 + 0.4 * sin(TAU * float(i) / SR / 16.0))
	var notes := [220.0, 261.6, 293.7, 329.6, 392.0, 440.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 14:
		var when := rng.randf_range(0.0, 13.5)
		var f: float = notes[rng.randi_range(0, notes.size() - 1)]
		var bell := _sweep(2.2, f, f, 0.13, 0, 2.2)
		out = _mix(out, bell, when)
	out.resize(n)
	return _wav(out, true)


# ---------------------------------------------------------------- 烘焙

static func bake_all(out_dir := OUT_DIR) -> int:
	## 烘焙全部音效 + 环境音 + 主题，返回写出的文件数
	DirAccess.make_dir_recursive_absolute(out_dir)
	var n := 0
	for name in SOUND_NAMES:
		var w := sound(name)
		if w == null:
			push_warning("AudioSynth: 未知音效 " + name)
			continue
		if ResourceSaver.save(w, "%s/sfx_%s.res" % [out_dir, name]) == OK:
			n += 1
	if ResourceSaver.save(make_ambient(), "%s/ambient.res" % out_dir) == OK:
		n += 1
	if ResourceSaver.save(make_theme(), "%s/theme.res" % out_dir) == OK:
		n += 1
	return n

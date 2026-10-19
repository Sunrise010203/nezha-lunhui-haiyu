class_name GroundBlobShadow
extends MeshInstance3D
## 贴地接触阴影（P0 美学速效包）：
## - 乘算混合（blend_mul）只压暗地面，不加光、不被 glow 拾取；
## - 每帧向下射线自动贴合平台/移动浮台，按离地高度缩放并变淡；
## - 用径向 shader 而不是"贴图 × 颜色"，否则整块四边形都被压暗，出现黑方块；
## - 独立于角色骨骼（top_level），角色旋转/倾斜不会把影子转歪。

var actor: Node3D = null
var base_radius := 0.7          # 贴地时阴影半径（米）
var base_strength := 0.55       # 中心压暗强度（0=无，1=全黑）
var max_distance := 40.0        # 超过这个高度直接隐藏
var max_visible_height := 7.0   # 超过这个高度淡到 0

var _mat: ShaderMaterial
const SHADER := preload("res://shaders/blob_shadow.gdshader")


func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	rotation_degrees = Vector3(-90, 0, 0)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mesh = quad
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material_override = _mat
	visible = false


func _process(_delta: float) -> void:
	if actor == null or not is_instance_valid(actor):
		queue_free()
		return
	var from := actor.global_position + Vector3(0, 0.6, 0)
	var to := actor.global_position + Vector3(0, -max_distance, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if actor is CollisionObject3D:
		q.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		visible = false
		return
	var ground: Vector3 = hit.position
	var h := from.y - ground.y
	if h > max_visible_height:
		visible = false
		return
	visible = true
	global_position = ground + Vector3(0, 0.035, 0)
	var k := clampf(1.0 - h / max_visible_height, 0.3, 1.0)   # 越高越小越淡
	var r := base_radius * (0.7 + 0.3 * k)
	scale = Vector3(r * 2.0, r * 2.0, 1.0)
	_mat.set_shader_parameter("strength", base_strength * k)

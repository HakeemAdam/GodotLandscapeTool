@tool
extends Node

@export var speed: float = 2.0
@export var texture_size: int = 512
@export var seed_value: float = 34.93:
	set(val):
		seed_value = val
		if Engine.is_editor_hint() or is_inside_tree():
			update_noise()
			make_mesh()

var time: float = 0.0

@export_range(0.1, 5.0) var scale: float = 1.0:
	set(val):
		scale = val
		if Engine.is_editor_hint() or is_inside_tree():
			update_noise()
			make_mesh()
		
@export_range(0.1, 5.0) var detail: float = 1.0:
	set(val):
		detail= val
		if Engine.is_editor_hint() or is_inside_tree():
			update_noise()
			make_mesh()

@export var pan_direction: Vector2 = Vector2(0.5, 0.0):
	set(val):
		pan_direction = val
		if Engine.is_editor_hint() or is_inside_tree():
			update_noise()
			make_mesh()

@export var pan_speed : float = 0.0:
	set(val):
		pan_speed = val
		if Engine.is_editor_hint() or is_inside_tree():
			update_noise()
			make_mesh()

@export var manual_pan: Vector2 = Vector2(0.5, 0.0):
	set(val):
		manual_pan = val
		if Engine.is_editor_hint() or is_inside_tree():
			update_noise()
			make_mesh()
			
@export var useErosion : int = 0
@export var inertia : float = 0.05
@export var sedimentCapacityFactor : float = 4.0
@export var minSedimentCapacityFactor : float = 0.01
@export var erosionSpeed : float = 0.01
@export var depositionSpeed : float = 0.01
@export var evaporationRate : float = 0.02
@export var gravity : float = 4.0
			
var rd : RenderingDevice
var shader_rid: RID
var buffer_rid : RID
var pipeline_rid : RID
var uniform_set_rid : RID

var output_height : PackedFloat32Array
var st: SurfaceTool
var mi: MeshInstance3D

func _ready() -> void:
	mi = MeshInstance3D.new()
	add_child(mi)
	
	st = SurfaceTool.new()
	
	_create_rendering_device()
	update_noise()
	make_mesh()
	
	
func update_noise():
	if not rd:
		return
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_rid, 0)
	
	var stream := StreamPeerBuffer.new()
	stream.put_float(seed_value)
	stream.put_float(time)
	stream.put_float(pan_direction.x)
	stream.put_float(pan_direction.y)
	stream.put_float(pan_speed)
	stream.put_float(scale)
	stream.put_float(detail)
	stream.put_float(manual_pan.x)
	stream.put_float(manual_pan.y)
	
	var param_bytes: PackedByteArray = stream.data_array
	rd.compute_list_set_push_constant(compute_list, param_bytes, param_bytes.size())
	
	var work_groups_x = ceil(float(texture_size) / 16.0)
	var work_groups_y = ceil(float(texture_size) / 16.0)
	rd.compute_list_dispatch(compute_list, work_groups_x, work_groups_y, 1)
	rd.compute_list_end()
	
	rd.submit()
	rd.sync()
	
	var raw_bytes: PackedByteArray = rd.texture_get_data(buffer_rid, 0)
	if raw_bytes.size() > 0 :
		output_height = raw_bytes.to_float32_array()

func make_mesh():
	
	if st:
		st.clear()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spacing : float = 1.0
	var height_scale : float = 150.0
	
	for z in range(texture_size):
		for x in range(texture_size):
			var index = (z * texture_size) + x
			
			var vy = output_height[index] * height_scale
			var vx = float(x) * spacing
			var vz = float(z) * spacing
			
			st.set_uv(Vector2(float(x) / texture_size, float(z) / texture_size))
			st.add_vertex(Vector3(vx, vy, vz))
			
	for z in range(texture_size -1):
		for x in range(texture_size-1):
			var tl = (z * texture_size) + x
			var trv = tl + 1
			var bl = ((z + 1) * texture_size) + x
			var br = bl + 1
			
			st.add_index(tl)
			st.add_index(trv)
			st.add_index(bl)
			
			st.add_index(trv)
			st.add_index(br)
			st.add_index(bl)
			
	st.generate_normals()
	st.generate_tangents()
	
	mi.mesh = st.commit()
			
	
func _process(delta: float) -> void:
	
	#time += delta
	#update_noise()		
	#make_mesh()
	pass
	
func _create_rendering_device() -> void:
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		return
		
	var shader_file := load("res://shaders/fbm_terrain.glsl")
	var shader_spirv :RDShaderSPIRV = shader_file.get_spirv()
	shader_rid = rd.shader_create_from_spirv(shader_spirv)
	
	# Binding the buffer input
	var fmt := RDTextureFormat.new()
	fmt.width = texture_size
	fmt.height = texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT 
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	# 2. Allocate the initial byte array for the texture (4 bytes per float/pixel)
	var initial_bytes := PackedByteArray()
	initial_bytes.resize(texture_size * texture_size * 4)
	
	# 3. Create a Texture instead of a storage buffer
	buffer_rid = rd.texture_create(fmt, RDTextureView.new(), [initial_bytes])
	var uniform_h := RDUniform.new()
	uniform_h.uniform_type =  RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_h.binding = 0
	uniform_h.add_id(buffer_rid)

	uniform_set_rid = rd.uniform_set_create([uniform_h], shader_rid, 0)
	pipeline_rid = rd.compute_pipeline_create(shader_rid)
	
func _exit_tree() -> void:
	if rd:	
		rd.free_rid(pipeline_rid)
		rd.free_rid(uniform_set_rid)
		rd.free_rid(buffer_rid)
		rd.free_rid(shader_rid)
	

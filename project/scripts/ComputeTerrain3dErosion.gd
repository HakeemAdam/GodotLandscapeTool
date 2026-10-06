@tool
extends Node

var time: float = 0.0
var seed: float = 0.0
@export var speed: float = 2.0
@export var texture_size: int = 512
@export var seed_value: float = 34.93:
	set(val):
		seed_value = val
		_queue_update()
		
@export_range(0.1, 5.0) var scale: float = 1.0:
	set(val):
		scale = val
		_queue_update()
		
@export_range(0.1, 5.0) var detail: float = 1.0:
	set(val):
		detail= val
		_queue_update()

@export var pan_direction: Vector2 = Vector2(0.5, 0.0):
	set(val):
		pan_direction = val
		_queue_update()

@export var manual_pan: Vector2 = Vector2(0.5, 0.0):
	set(val):
		manual_pan = val
		_queue_update()

@export var pan_speed : float = 0.0:
	set(val):
		pan_speed = val
		_queue_update()
			
@export_group("Erosion Params")
@export var useErosion : int = 1:
	set(val):
		useErosion = val
		_queue_update()
		
@export_range(0, 100) var step : int = 30:
	set(val):
		step = val
		_queue_update()
		
@export_range(0.0, 1.0) var inertia : float = 0.05:
	set(val):
		inertia = val
		_queue_update()
		
@export_range(0.0, 10.0) var sedimentCapacityFactor : float = 4.0:
	set(val):
		sedimentCapacityFactor = val
		_queue_update()
		
@export_range(0.0, 1.0)var minSedimentCapacityFactor : float = 0.01:
	set(val):
		minSedimentCapacityFactor = val
		_queue_update()
		
@export_range(0.0, 10.0) var erosionSpeed : float = 0.01:
	set(val):
		erosionSpeed = val
		_queue_update()
		
@export_range(0.0, 1.0) var depositionSpeed : float = 0.01:
	set(val):
		depositionSpeed = val
		_queue_update()
		
@export_range(0.0, 1.0) var evaporationRate : float = 0.02:
	set(val):
		evaporationRate = val
		_queue_update()
		
@export_range(0.0, 10.0) var gravity : float = 4.0:
	set(val):
		gravity = val
		_queue_update()
			
var rd : RenderingDevice

# Shaders
var gen_shader_rid : RID
var gen_pipeline_rid : RID
var gen_uniform_set_rid : RID

var erosion_shader_rid : RID
var erosion_pipeline_rid : RID
var erosion_uniform_set_rid : RID

# Texture pipeline
var gen_output_texture_rid : RID
var erosion_final_texture_rid : RID

# ssbos
var droplet_buffer_rid : RID
var height_buffer_rid : RID

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
		
	# Heightfeild pipeline
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, gen_pipeline_rid)
	rd.compute_list_bind_uniform_set(compute_list, gen_uniform_set_rid, 0)
	
	var gen_stream := StreamPeerBuffer.new()
	gen_stream.put_float(seed_value)
	gen_stream.put_float(time)
	gen_stream.put_float(pan_direction.x)
	gen_stream.put_float(pan_direction.y)
	gen_stream.put_float(pan_speed)
	gen_stream.put_float(scale)
	gen_stream.put_float(detail)
	gen_stream.put_float(manual_pan.x)
	gen_stream.put_float(manual_pan.y)
	
	var gen_bytes: PackedByteArray = gen_stream.data_array
	rd.compute_list_set_push_constant(compute_list, gen_bytes, gen_bytes.size())
	
	var work_groups_gen = ceil(float(texture_size) / 16.0)
	rd.compute_list_dispatch(compute_list, work_groups_gen, work_groups_gen, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	if useErosion:
		var raw_in = rd.texture_get_data(gen_output_texture_rid, 0).to_float32_array()
		var h_in := PackedFloat32Array()
		h_in.resize(texture_size * texture_size)
		for i in range(h_in.size()):
			h_in[i] = raw_in[i * 4]
		rd.buffer_update(height_buffer_rid, 0, h_in.size() * 4, h_in.to_byte_array())
	
	# Erosion pipeline
	
	if useErosion:
		var ero_list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(ero_list, erosion_pipeline_rid)
		rd.compute_list_bind_uniform_set(ero_list, erosion_uniform_set_rid, 0)
		
		seed = randf() * 10000.0
		
		var erosion_stream := StreamPeerBuffer.new()
		erosion_stream.put_32(texture_size)
		erosion_stream.put_float(inertia)
		erosion_stream.put_float(sedimentCapacityFactor)
		erosion_stream.put_float(minSedimentCapacityFactor)
		erosion_stream.put_float(erosionSpeed)
		erosion_stream.put_float(depositionSpeed)
		erosion_stream.put_float(evaporationRate)
		erosion_stream.put_float(gravity)
		erosion_stream.put_32(useErosion)
		erosion_stream.put_32(step)
		erosion_stream.put_float(seed)
		
		var erosion_byte: PackedByteArray = erosion_stream.data_array
		rd.compute_list_set_push_constant(ero_list, erosion_byte,erosion_byte.size())
		
		var total_droplets = texture_size * texture_size
		var work_groups_erosion = ceil(float(total_droplets)/ 256.0)
		rd.compute_list_dispatch(ero_list, work_groups_erosion, 1, 1)
		rd.compute_list_end()
	
		rd.submit()
		rd.sync()
	
	if useErosion:
		output_height = rd.buffer_get_data(height_buffer_rid).to_float32_array()
	else:
		var raw_bytes: PackedByteArray = rd.texture_get_data(gen_output_texture_rid, 0)
		var channels = raw_bytes.to_float32_array()
		output_height.resize(texture_size * texture_size)
		for i in range(texture_size * texture_size):
			output_height[i] = channels[i * 4]

func make_mesh():
	if output_height.size() == 0:
		return
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
			
	
func _process(_delta: float) -> void:
	
	#step += int(_delta)
	#_queue_update()
	
	pass
	
func _queue_update() -> void:
	if Engine.is_editor_hint() or is_inside_tree():
		update_noise()
		make_mesh()
		
func _create_rendering_device() -> void:
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		return
		
	# Compile Shaders
	var gen_file := load("res://shaders/fbm_terrain.glsl")
	gen_shader_rid = rd.shader_create_from_spirv(gen_file.get_spirv())
	
	var erosion_file := load("res://shaders/fbm_terrain_erosion.glsl")
	erosion_shader_rid = rd.shader_create_from_spirv(erosion_file.get_spirv())
	
	# Setup image buffer input
	var fmt := RDTextureFormat.new()
	fmt.width = texture_size
	fmt.height = texture_size
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT 
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT

	# 2. Allocate the initial byte array for the texture (4 bytes per float/pixel)
	var initial_bytes := PackedByteArray()
	initial_bytes.resize(texture_size * texture_size * 16)
	
	gen_output_texture_rid = rd.texture_create(fmt, RDTextureView.new(), [initial_bytes])
	erosion_final_texture_rid = rd.texture_create(fmt, RDTextureView.new(), [initial_bytes])
	
	# Droplet buffer
	var droplet_bytes := PackedByteArray()
	droplet_bytes.resize(texture_size * texture_size * 32)
	droplet_buffer_rid = rd.storage_buffer_create(droplet_bytes.size(), droplet_bytes)
	
	# Height buffer
	var scratch_bytes := PackedByteArray()
	scratch_bytes.resize(texture_size * texture_size *4)
	height_buffer_rid = rd.storage_buffer_create(scratch_bytes.size(), scratch_bytes)
	
	# Bind generation Uniforms
	var gen_uniform := RDUniform.new()
	gen_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	gen_uniform.binding = 0
	gen_uniform.add_id(gen_output_texture_rid)
	gen_uniform_set_rid = rd.uniform_set_create([gen_uniform], gen_shader_rid, 0)
	gen_pipeline_rid = rd.compute_pipeline_create(gen_shader_rid)
	
	# Bind Erosion, input img, output ig, droplet buffer, height buffer
	
	var uniform_in := RDUniform.new()
	uniform_in.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_in.binding = 1
	uniform_in.add_id(gen_output_texture_rid)
	
	var uniform_out := RDUniform.new()
	uniform_out.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_out.binding = 2
	uniform_out.add_id(erosion_final_texture_rid)
	
	var uniform_droplets := RDUniform.new()
	uniform_droplets.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_droplets.binding = 3
	uniform_droplets.add_id(droplet_buffer_rid)
	
	var uniform_scratch := RDUniform.new()
	uniform_scratch.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_scratch.binding = 4
	uniform_scratch.add_id(height_buffer_rid)
	
	erosion_uniform_set_rid = rd.uniform_set_create([uniform_in, uniform_out, uniform_droplets, uniform_scratch], erosion_shader_rid, 0)
	erosion_pipeline_rid = rd.compute_pipeline_create(erosion_shader_rid)
	
func _exit_tree() -> void:
	if rd:	
		rd.free_rid(gen_pipeline_rid)
		rd.free_rid(gen_uniform_set_rid)
		rd.free_rid(gen_output_texture_rid)
		rd.free_rid(gen_shader_rid)
		
		rd.free_rid(erosion_pipeline_rid)
		rd.free_rid(erosion_uniform_set_rid)
		rd.free_rid(erosion_final_texture_rid)
		rd.free_rid(droplet_buffer_rid)
		rd.free_rid(height_buffer_rid)
		rd.free_rid(erosion_shader_rid)
	

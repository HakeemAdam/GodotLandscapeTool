#include "Landscape.h"
#include "godot_cpp/classes/global_constants.hpp"
#include "godot_cpp/classes/image.hpp"
#include "godot_cpp/classes/mesh.hpp"
#include "godot_cpp/classes/mesh_instance3d.hpp"
#include "godot_cpp/classes/node.hpp"
#include "godot_cpp/classes/object.hpp"
#include "godot_cpp/classes/ref.hpp"
#include "godot_cpp/classes/shader_material.hpp"
#include "godot_cpp/classes/texture2d.hpp"
#include "godot_cpp/core/class_db.hpp"
#include "godot_cpp/core/math.hpp"
#include "godot_cpp/core/object.hpp"
#include "godot_cpp/core/property_info.hpp"
#include "godot_cpp/variant/callable.hpp"
#include "godot_cpp/variant/typed_array.hpp"
#include "godot_cpp/variant/variant.hpp"
#include "godot_cpp/variant/vector2.hpp"
#include "godot_cpp/variant/vector3.hpp"

void Landscape::_bind_methods(){
	godot::ClassDB::bind_method(godot::D_METHOD("generate_landscape"), &Landscape::generate_landscape);

	godot::ClassDB::bind_method(godot::D_METHOD("_on_noise_changed"), &Landscape::_on_noise_changed);

	godot::ClassDB::bind_method(godot::D_METHOD("get_landscape_size"), &Landscape::get_landscape_size);

	godot::ClassDB::bind_method(godot::D_METHOD("set_landscape_size", "p_size"), &Landscape::set_landscape_size);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::VECTOR2, "landscape_size"), "set_landscape_size", "get_landscape_size");

	godot::ClassDB::bind_method(godot::D_METHOD("get_noise_scale"), &Landscape::get_noise_scale);

	godot::ClassDB::bind_method(godot::D_METHOD("set_noise_scale", "p_scale"), &Landscape::set_noise_scale);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::FLOAT, "noise_scale"), "set_noise_scale", "get_noise_scale");

	godot::ClassDB::bind_method(godot::D_METHOD("get_spacing"), &Landscape::get_spacing);

	godot::ClassDB::bind_method(godot::D_METHOD("set_spacing", "p_space"), &Landscape::set_spacing);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::FLOAT, "spacing"), "set_spacing", "get_spacing");

	godot::ClassDB::bind_method(godot::D_METHOD("get_landscape_material"), &Landscape::get_landscape_material);

	godot::ClassDB::bind_method(godot::D_METHOD("set_landscape_material", "p_material"), &Landscape::set_landscape_material);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "landscape_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial", godot::PROPERTY_USAGE_DEFAULT | godot::PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT), "set_landscape_material", "get_landscape_material");

	godot::ClassDB::bind_method(godot::D_METHOD("get_landscape_noise"), &Landscape::get_landscape_noise);

	godot::ClassDB::bind_method(godot::D_METHOD("set_landscape_noise", "p_noise"), &Landscape::set_landscape_noise);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "landscape_noise", godot::PROPERTY_HINT_RESOURCE_TYPE, "FastNoiseLite",godot::PROPERTY_USAGE_DEFAULT | godot::PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT), "set_landscape_noise", "get_landscape_noise");

	godot::ClassDB::bind_method(godot::D_METHOD("get_landscape_texture"), &Landscape::get_landscape_texture);

	godot::ClassDB::bind_method(godot::D_METHOD("set_landscape_texture", "p_texture"), &Landscape::set_landscape_texture);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "landscape_texture", godot::PROPERTY_HINT_RESOURCE_TYPE, "Texture2D",godot::PROPERTY_USAGE_DEFAULT), "set_landscape_texture", "get_landscape_texture");

	godot::ClassDB::bind_method(godot::D_METHOD("get_use_texture"), &Landscape::get_use_texture);

	godot::ClassDB::bind_method(godot::D_METHOD("set_use_texture", "p_set"), &Landscape::set_use_texture);

	ADD_PROPERTY(godot::PropertyInfo(godot::Variant::BOOL, "use_texture"), "set_use_texture", "get_use_texture");


}

Landscape::Landscape(){
	p_landscape_size = godot::Vector2(32,32);
	p_noise_scale = 10.0f;
	p_spacing = 1.0f;
	p_use_texture = false;

	st.instantiate();

}

Landscape::~Landscape(){

}

void Landscape::_ready(){
	if(!landscape_material.is_valid()){
		landscape_material.instantiate();
		set_material_override(landscape_material);
	}

	if(!noise_instance.is_valid()){
		noise_instance.instantiate();
		noise_instance->connect("changed", godot::Callable(this, "_on_noise_changed"));
	}
	//godot::Ref<godot::InputEventMouseMotion> mouse_motion




	generate_landscape();





}

void Landscape::generate_landscape(){


	st->clear();
	st->begin(godot::Mesh::PRIMITIVE_TRIANGLES);

	float spacing = p_spacing;
	int width = (int)p_landscape_size.x;
	int depth = (int)p_landscape_size.y;



	godot::Ref<godot::Image> img;
	if (landscape_texture.is_valid()){
		img = landscape_texture->get_image();
		if (img.is_valid() && img->is_compressed()) {
			img->decompress();
		}
	}

	// Sample noise
	for(int z = 0; z < depth; z++){
		for(int x = 0; x < width; x++){
			float y = 0.0f;

			// Use texture
			if (p_use_texture == true) {
				if (img.is_valid()) {
					float u = (width > 1) ? (float)x / (width - 1) : 0.0f;
					float v = (depth > 1) ? (float)z / (depth - 1) : 0.0f;

					int img_x = (int)(u * (img->get_width() - 1));
					int img_z = (int)(v * (img->get_height() - 1));

					img_x = godot::CLAMP(img_x, 0, img->get_width() - 1);
					img_z = godot::CLAMP(img_z, 0, img->get_height() - 1);

					godot::Color px_color = img->get_pixel(img_x, img_z);
					y =  px_color.get_v() * p_noise_scale;
				}
			}
			else {
				// Use noise
				if (noise_instance.is_valid()) {
					y = noise_instance->get_noise_2d((float)x, (float)z) * p_noise_scale;
				}
			}

			// Generate UVs and Geometry
			st->set_uv(godot::Vector2((float)x / (width - 1), (float)z / (depth - 1)));
			st->add_vertex(godot::Vector3(x * spacing, y, z * spacing));
		}
	}

	// Build vetices
	for(int z = 0; z < depth - 1; z++){
		for(int x = 0; x < width - 1; x++){
			// Get vertex row indices
			int current_row = z * width;
			int next_row = (z + 1) * width;

			// Triangle 1
			st->add_index(current_row + x);
			st->add_index(current_row + x + 1);
			st->add_index(next_row + x);

			// Triangle 2
			st->add_index(next_row + x);
			st->add_index(current_row + x + 1);
			st->add_index(next_row + x + 1);
		}
	}

	st->generate_normals();

	mesh = st->commit();
	set_mesh(mesh);
	set_material_override(landscape_material);

	// Collision
	create_collision();



}

void Landscape::create_collision() {
	// Get children
	godot::TypedArray<godot::Node> children = get_children();

	// loop backwards and remove
	for (int i = children.size() - 1; i >= 0; i--) {
		godot::Node* child = godot::Object::cast_to<godot::Node>(children[i]);

		if (child != nullptr && child->is_class("StaticBody3D")) {
			remove_child(child);
			child->queue_free();
		}
	}
	create_trimesh_collision();

}

void Landscape::_on_noise_changed(){
	generate_landscape();
}

godot::Vector2 Landscape::get_landscape_size(){
	return p_landscape_size;
}

void Landscape::set_landscape_size(const godot::Vector2& p_size){
	p_landscape_size = p_size;
	generate_landscape();

}

float Landscape::get_noise_scale(){
	return p_noise_scale;
}

void Landscape::set_noise_scale(const float p_scale){
	p_noise_scale = p_scale;
	generate_landscape();
}

float Landscape::get_spacing(){
	return p_spacing;
}

void Landscape::set_spacing(const float p_space){
	p_spacing=p_space;
	generate_landscape();
}

godot::Ref<godot::ShaderMaterial> Landscape::get_landscape_material(){
	return landscape_material;
}

void Landscape::set_landscape_material(const godot::Ref<godot::ShaderMaterial>&  p_material){
	landscape_material = p_material;
	generate_landscape();
}


godot::Ref<godot::FastNoiseLite>  Landscape::get_landscape_noise(){
	return noise_instance;
}

void Landscape::set_landscape_noise(const godot::Ref<godot::FastNoiseLite>& p_noise){
	if (noise_instance.is_valid() && noise_instance->is_connected("changed", godot::Callable(this, "_on_noise_changed"))){
		noise_instance->disconnect("changed", godot::Callable(this, "_on_noise_changed"));
	}
	noise_instance = p_noise;

	if(noise_instance.is_valid()){
		noise_instance->connect("changed", godot::Callable(this, "_on_noise_changed"));
	}
	generate_landscape();
}

godot::Ref<godot::Texture2D> Landscape::get_landscape_texture(){
	return landscape_texture;
}

void Landscape::set_landscape_texture(const godot::Ref<godot::Texture2D>& p_texture){
	landscape_texture = p_texture;
	generate_landscape();
}

bool Landscape::get_use_texture(){
	return p_use_texture;
}

void Landscape::set_use_texture(const bool p_set){
	p_use_texture = p_set;
	generate_landscape();
}


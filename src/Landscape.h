#pragma once

#include "godot_cpp/classes/fast_noise_lite.hpp"
#include "godot_cpp/classes/mesh.hpp"
#include "godot_cpp/classes/shader_material.hpp"
#include "godot_cpp/classes/mesh_instance3d.hpp"
#include "godot_cpp/classes/ref.hpp"
#include "godot_cpp/classes/shader_material.hpp"
#include "godot_cpp/classes/texture2d.hpp"
#include "godot_cpp/classes/wrapped.hpp"
#include "godot_cpp/variant/vector2.hpp"
#include "godot_cpp/classes/surface_tool.hpp"

class Landscape : public godot::MeshInstance3D{
	GDCLASS(Landscape, godot::MeshInstance3D)

	private:
		// Mesh, material, noise, mesh setting
		// getters and setters: size, division, material + settings
		godot::Ref<godot::Mesh> mesh;

		godot::Ref<godot::SurfaceTool> st;

		godot::Ref<godot::ShaderMaterial> landscape_material;

		godot::Ref<godot::FastNoiseLite> noise_instance;

		godot::Ref<godot::Texture2D> landscape_texture;

		bool p_use_texture;

		// Mesh variables
		godot::Vector2 p_landscape_size;

		float p_noise_scale;

		float p_spacing;

		void create_collision();

		// Brush
		//godot::MeshInstance3D* brush_mesh=nullptr;

	protected:
		static void _bind_methods();

	public:
		Landscape();
		~Landscape();

		void _ready() override;

		void generate_landscape();


		// Signals
		void _on_noise_changed();


		// Mesh settings
		godot::Vector2 get_landscape_size();

 		void set_landscape_size(const godot::Vector2& p_size);

		float get_noise_scale();

		void set_noise_scale(const float p_scale);

		float get_spacing();

		void set_spacing(const float p_space);

		// Material Assignment
		godot::Ref<godot::ShaderMaterial> get_landscape_material();

		void set_landscape_material(const godot::Ref<godot::ShaderMaterial>& p_material);

		// Noise Assignment
		godot::Ref<godot::FastNoiseLite> get_landscape_noise();

		void set_landscape_noise(const godot::Ref<godot::FastNoiseLite>& p_noise);

		// Texture Assigment
		godot::Ref<godot::Texture2D> get_landscape_texture();

		void set_landscape_texture(const godot::Ref<godot::Texture2D>& p_texture);

		bool get_use_texture();

		void set_use_texture(const bool p_set);





};

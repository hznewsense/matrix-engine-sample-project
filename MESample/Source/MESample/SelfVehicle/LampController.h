/****************************************************************************/
/* Matrix Engine Demo Project                                               */
/* Copyright (c) 2026 NewSense. All rights reserved.                        */
/*                                                                          */
/* Licensed under the Matrix Engine Demo Public License (MEDPL) v1.0.       */
/* You may use this file only in compliance with the License.               */
/*                                                                          */
/* This Software is provided for evaluation, research, and internal         */
/* development purposes only.                                               */
/* Production use in commercial vehicles or embedded automotive systems is  */
/* strictly prohibited without a separate commercial license agreement.     */
/*                                                                          */
/* 本软件仅用于评估、研究及内部开发目的。                                      */
/* 未经正式商业授权，不得用于任何量产车辆或商业嵌入式系统。                     */
/*                                                                          */
/* Matrix Runtime 为专有软件，不在本许可范围内。                              */
/****************************************************************************/

#pragma once

#include "Common/CommonLib.h"
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/shader_material.hpp>

class LampController : public godot::Node {
	GDCLASS(LampController, godot::Node)

private:
	// 材质引用（Inspector 赋值）
	godot::Ref<godot::ShaderMaterial> m_drl_material;
	godot::Ref<godot::ShaderMaterial> m_headlight_material;
	godot::Ref<godot::ShaderMaterial> m_fog_light_material;
	godot::Ref<godot::ShaderMaterial> m_brake_material;
	godot::Ref<godot::ShaderMaterial> m_turn_left_material;
	godot::Ref<godot::ShaderMaterial> m_turn_right_material;

	// 灯光状态
	bool m_drl{ false };
	bool m_low_beam{ false };
	bool m_high_beam{ false };
	bool m_brake{ false };
	bool m_left_turn{ false };
	bool m_right_turn{ false };
	bool m_fog{ false };

public:
#define LAMP_SETTER(name, material_member, uniform) \
	void set_##name(bool on) { \
		m_##name = on; \
		if (material_member.is_valid()) \
			material_member->set_shader_parameter(uniform, on); \
	}

	LAMP_SETTER(drl, m_drl_material, "drl")
	LAMP_SETTER(low_beam, m_headlight_material, "low_beam")
	LAMP_SETTER(high_beam, m_headlight_material, "high_beam")
	LAMP_SETTER(brake, m_brake_material, "brake_light")
	LAMP_SETTER(left_turn, m_turn_left_material, "hazardlight")
	LAMP_SETTER(right_turn, m_turn_right_material, "hazardlight")
	LAMP_SETTER(fog, m_fog_light_material, "rear_fog_light")

#undef LAMP_SETTER

	void set_hazard(bool on) {
		m_left_turn = on;
		m_right_turn = on;
		if (m_turn_left_material.is_valid())
			m_turn_left_material->set_shader_parameter("hazardlight", on);
		if (m_turn_right_material.is_valid())
			m_turn_right_material->set_shader_parameter("hazardlight", on);
	}

	// 材质 setter/getter
#define MAT_PROPS(name, member) \
	void set_##name(godot::Ref<godot::ShaderMaterial> v) { member = v; } \
	godot::Ref<godot::ShaderMaterial> get_##name() const { return member; }

	MAT_PROPS(drl_material, m_drl_material)
	MAT_PROPS(headlight_material, m_headlight_material)
	MAT_PROPS(fog_light_material, m_fog_light_material)
	MAT_PROPS(brake_material, m_brake_material)
	MAT_PROPS(turn_left_material, m_turn_left_material)
	MAT_PROPS(turn_right_material, m_turn_right_material)

#undef MAT_PROPS

protected:
	static void _bind_methods() {
		// 材质属性
		ClassDB::bind_method(godot::D_METHOD("set_drl_material", "mat"), &LampController::set_drl_material);
		ClassDB::bind_method(godot::D_METHOD("get_drl_material"), &LampController::get_drl_material);
		ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "drl_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"), "set_drl_material", "get_drl_material");

		ClassDB::bind_method(godot::D_METHOD("set_headlight_material", "mat"), &LampController::set_headlight_material);
		ClassDB::bind_method(godot::D_METHOD("get_headlight_material"), &LampController::get_headlight_material);
		ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "headlight_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"), "set_headlight_material", "get_headlight_material");

		ClassDB::bind_method(godot::D_METHOD("set_fog_light_material", "mat"), &LampController::set_fog_light_material);
		ClassDB::bind_method(godot::D_METHOD("get_fog_light_material"), &LampController::get_fog_light_material);
		ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "fog_light_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"), "set_fog_light_material", "get_fog_light_material");

		ClassDB::bind_method(godot::D_METHOD("set_brake_material", "mat"), &LampController::set_brake_material);
		ClassDB::bind_method(godot::D_METHOD("get_brake_material"), &LampController::get_brake_material);
		ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "brake_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"), "set_brake_material", "get_brake_material");

		ClassDB::bind_method(godot::D_METHOD("set_turn_left_material", "mat"), &LampController::set_turn_left_material);
		ClassDB::bind_method(godot::D_METHOD("get_turn_left_material"), &LampController::get_turn_left_material);
		ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "turn_left_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"), "set_turn_left_material", "get_turn_left_material");

		ClassDB::bind_method(godot::D_METHOD("set_turn_right_material", "mat"), &LampController::set_turn_right_material);
		ClassDB::bind_method(godot::D_METHOD("get_turn_right_material"), &LampController::get_turn_right_material);
		ADD_PROPERTY(godot::PropertyInfo(godot::Variant::OBJECT, "turn_right_material", godot::PROPERTY_HINT_RESOURCE_TYPE, "ShaderMaterial"), "set_turn_right_material", "get_turn_right_material");

		// 灯光控制方法
		ClassDB::bind_method(godot::D_METHOD("set_drl", "on"), &LampController::set_drl);
		ClassDB::bind_method(godot::D_METHOD("set_low_beam", "on"), &LampController::set_low_beam);
		ClassDB::bind_method(godot::D_METHOD("set_high_beam", "on"), &LampController::set_high_beam);
		ClassDB::bind_method(godot::D_METHOD("set_brake", "on"), &LampController::set_brake);
		ClassDB::bind_method(godot::D_METHOD("set_left_turn", "on"), &LampController::set_left_turn);
		ClassDB::bind_method(godot::D_METHOD("set_right_turn", "on"), &LampController::set_right_turn);
		ClassDB::bind_method(godot::D_METHOD("set_fog", "on"), &LampController::set_fog);
		ClassDB::bind_method(godot::D_METHOD("set_hazard", "on"), &LampController::set_hazard);
	}
};

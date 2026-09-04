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
#include "godot_cpp/classes/node3d.hpp"
#include "godot_cpp/classes/area3d.hpp"
#include "godot_cpp/classes/collision_shape3d.hpp"
#include "godot_cpp/classes/input_event_mouse_button.hpp"
#include "godot_cpp/classes/input_event_screen_touch.hpp"
#include "godot_cpp/classes/input_event_screen_drag.hpp"
#include "godot_cpp/classes/camera3d.hpp"
#include "godot_cpp/classes/viewport.hpp"
#include "godot_cpp/classes/world3d.hpp"
#include "godot_cpp/classes/physics_direct_space_state3d.hpp"
#include "godot_cpp/classes/physics_ray_query_parameters3d.hpp"
#include "godot_cpp/core/print_string.hpp"
#include "godot_cpp/classes/display_server.hpp"
#include <array>

class DoorController : public godot::Node3D {
	GDCLASS(DoorController, godot::Node3D)

public:
	enum DoorType { DOOR_LEFT_FRONT, DOOR_RIGHT_FRONT, DOOR_LEFT_REAR, DOOR_RIGHT_REAR, DOOR_HOOD, DOOR_TRUNK, DOOR_CHARGE_PORT, DOOR_COUNT };
	enum DoorState { DOOR_STATE_CLOSED, DOOR_STATE_OPENING, DOOR_STATE_OPEN, DOOR_STATE_CLOSING };

private:
	struct DoorData {
		godot::NodePath path;
		godot::NodePath area_path;
		godot::Node3D *node{ nullptr };
		godot::Area3D *area{ nullptr };
        godot::CollisionShape3D *shape{ nullptr };
        godot::Vector3 axis{ 0, 1, 0 };
		float angle{ 60.0f };
		float progress{ 0.0f };
		DoorState state{ DOOR_STATE_CLOSED };
		godot::Quaternion initial_rot;
	};

	std::array<DoorData, DOOR_COUNT> m_doors;
	float m_duration{ 0.5f }, m_ray_len{ 100.0f };
	bool m_interaction_enabled{ false };
	bool m_interaction_permitted{ true };
	float m_hide_timer{ 0.0f };
	static constexpr float HIDE_DELAY{ 5.0f };
	int m_touch_count{ 0 };
	bool m_touch_dragged{ false };

	// 单一宏定义门的属性（控制节点 + Area3D）
#define DOOR_PROPS(name, idx) \
	godot::NodePath m_##name##_path; \
	godot::NodePath m_##name##_area_path; \
	godot::Vector3 m_##name##_axis{ 0, 1, 0 }; \
	float m_##name##_angle{ 60.0f }; \
	void set_##name##_path(godot::NodePath v) { m_##name##_path = v; m_doors[idx].path = v; } \
	godot::NodePath get_##name##_path() const { return m_##name##_path; } \
	void set_##name##_area_path(godot::NodePath v) { m_##name##_area_path = v; m_doors[idx].area_path = v; } \
	godot::NodePath get_##name##_area_path() const { return m_##name##_area_path; } \
	void set_##name##_axis(godot::Vector3 v) { m_##name##_axis = v; m_doors[idx].axis = v.normalized(); } \
	godot::Vector3 get_##name##_axis() const { return m_##name##_axis; } \
	void set_##name##_angle(float v) { m_##name##_angle = v; m_doors[idx].angle = v; } \
	float get_##name##_angle() const { return m_##name##_angle; }

	DOOR_PROPS(left_front_door, DOOR_LEFT_FRONT)
	DOOR_PROPS(right_front_door, DOOR_RIGHT_FRONT)
	DOOR_PROPS(left_rear_door, DOOR_LEFT_REAR)
	DOOR_PROPS(right_rear_door, DOOR_RIGHT_REAR)
	DOOR_PROPS(hood, DOOR_HOOD)
	DOOR_PROPS(trunk, DOOR_TRUNK)
	DOOR_PROPS(charge_port, DOOR_CHARGE_PORT)
#undef DOOR_PROPS

	void _resolve_nodes() {
		for (auto &d : m_doors) {
			if (!d.path.is_empty() && (d.node = get_node<godot::Node3D>(d.path)))
				d.initial_rot = d.node->get_quaternion();
			if (!d.area_path.is_empty()) {
				d.area = get_node<godot::Area3D>(d.area_path);
				if (d.area) {
					for (int c = 0; c < d.area->get_child_count(); ++c) {
						d.shape = godot::Object::cast_to<godot::CollisionShape3D>(d.area->get_child(c));
						if (d.shape) break;
					}
				}
			}
		}
	}

	void _apply_rot(DoorData &d) {
		if (!d.node) return;
		float t = d.progress * d.progress * (3.0f - 2.0f * d.progress);
		d.node->set_quaternion(d.initial_rot * godot::Quaternion(d.axis, godot::Math::deg_to_rad(d.angle * t)));
	}

	int _try_hit_door(const godot::Vector2 &pos) const {
		godot::Camera3D *cam = get_viewport()->get_camera_3d();
		if (!cam) return -1;
		const float HIT_TOLERANCE = 90.0f;
		int best_door = -1;
		float best_dist = HIT_TOLERANCE;
		for (int i = 0; i < DOOR_COUNT; ++i) {
			if (!m_doors[i].area) continue;
			godot::Vector3 ctr = m_doors[i].shape
					? m_doors[i].shape->get_global_position()
					: m_doors[i].area->get_global_position();
			godot::Vector2 sp = cam->unproject_position(ctr);
			float d = sp.distance_to(pos);
			if (d < best_dist) { best_dist = d; best_door = i; }
		}
		return best_door;
	}


public:
	void _ready() override {
		_resolve_nodes();
		m_interaction_enabled = true;
		set_interaction_enabled(false);
	}

	void _physics_process(double dt) override {
		float delta = static_cast<float>(dt);
		for (int i = 0; i < DOOR_COUNT; ++i) {
			DoorData &d = m_doors[i];
			bool opening = d.state == DOOR_STATE_OPENING, closing = d.state == DOOR_STATE_CLOSING;
			if (opening) {
				d.progress = godot::Math::min(d.progress + delta / m_duration, 1.0f);
				if (d.progress >= 1.0f) { d.state = DOOR_STATE_OPEN; emit_signal("door_opened", i); }
			} else if (closing) {
				d.progress = godot::Math::max(d.progress - delta / m_duration, 0.0f);
				if (d.progress <= 0.0f) { d.state = DOOR_STATE_CLOSED; emit_signal("door_closed", i); }
			}
			if (opening || closing) { _apply_rot(d); emit_signal("door_state_changed", i, d.state); }
		}
		if (m_interaction_enabled && m_touch_count == 0) {
			m_hide_timer -= delta;
			if (m_hide_timer <= 0.0f) set_interaction_enabled(false);
		}
	}

	void _unhandled_input(const godot::Ref<godot::InputEvent> &e) override {
		godot::InputEventScreenTouch *te = godot::Object::cast_to<godot::InputEventScreenTouch>(e.ptr());
		if (te) {
			if (te->is_pressed()) {
				++m_touch_count;
				if (m_touch_count == 1) m_touch_dragged = false;
				m_hide_timer = HIDE_DELAY;
				int hit = _try_hit_door(te->get_position());
				if (hit < 0) set_interaction_enabled(false);
			} else {
				if (m_touch_count > 0) --m_touch_count;
				if (m_touch_count > 0) return;
				set_interaction_enabled(true);
				if (m_touch_dragged) return;
				int hit = _try_hit_door(te->get_position());
				if (hit >= 0) toggle_door(hit);
			}
			return;
		}
		godot::InputEventScreenDrag *de = godot::Object::cast_to<godot::InputEventScreenDrag>(e.ptr());
		if (de) { m_touch_dragged = true; set_interaction_enabled(false); m_hide_timer = HIDE_DELAY; return; }
		godot::InputEventMouseButton *me = godot::Object::cast_to<godot::InputEventMouseButton>(e.ptr());
		if (!me || !me->is_pressed() || me->get_button_index() != godot::MOUSE_BUTTON_LEFT) return;
		if (godot::DisplayServer::get_singleton()->is_touchscreen_available()) return;
		set_interaction_enabled(true);
		int hit = _try_hit_door(me->get_position());
		if (hit >= 0) toggle_door(hit);
	}

	void toggle_door(int idx) { if (idx >= 0 && idx < DOOR_COUNT) m_doors[idx].state >= DOOR_STATE_OPEN ? close_door(idx) : open_door(idx); }
	void open_door(int idx) {
		if (idx >= 0 && idx < DOOR_COUNT && m_doors[idx].node && m_doors[idx].state < DOOR_STATE_OPEN)
		{ m_doors[idx].state = DOOR_STATE_OPENING; emit_signal("door_state_changed", idx, m_doors[idx].state); }
	}
	void close_door(int idx) {
		if (idx >= 0 && idx < DOOR_COUNT && m_doors[idx].node && m_doors[idx].state >= DOOR_STATE_OPEN)
		{ m_doors[idx].state = DOOR_STATE_CLOSING; emit_signal("door_state_changed", idx, m_doors[idx].state); }
	}
	bool is_door_open(int idx) const { return idx >= 0 && idx < DOOR_COUNT && m_doors[idx].state == DOOR_STATE_OPEN; }
	int get_door_state(int idx) const { return (idx >= 0 && idx < DOOR_COUNT) ? m_doors[idx].state : DOOR_STATE_CLOSED; }
	void open_all_doors() { for (int i = 0; i < DOOR_COUNT; ++i) open_door(i); }
	void close_all_doors() { for (int i = 0; i < DOOR_COUNT; ++i) close_door(i); }

	void set_interaction_enabled(bool v) {
		if (!m_interaction_permitted) v = false;
		if (m_interaction_enabled == v) return;
		m_interaction_enabled = v;
		if (v) m_hide_timer = HIDE_DELAY;
		for (auto &d : m_doors) {
			if (d.area) {
				d.area->set_visible(v);
				if (d.shape) d.shape->set_disabled(!v);
			}
		}
		godot::print_line("[DoorController] interaction_enabled = ", v);
		emit_signal("interaction_visibility_changed", v);
	}
	bool is_interaction_enabled() const { return m_interaction_enabled; }

	void set_interaction_permitted(bool v) {
		m_interaction_permitted = v;
		if (!v) set_interaction_enabled(false);
	}
	bool is_interaction_permitted() const { return m_interaction_permitted; }

	// 属性访问器
	void set_animation_duration(float v) { m_duration = v; }
	float get_animation_duration() const { return m_duration; }
	void set_ray_length(float v) { m_ray_len = v; }
	float get_ray_length() const { return m_ray_len; }

protected:
	static void _bind_methods() {
		using namespace godot;
#define BP(name) ClassDB::bind_method(D_METHOD("set_" #name, "v"), &DoorController::set_##name); ClassDB::bind_method(D_METHOD("get_" #name), &DoorController::get_##name);
		BP(animation_duration); BP(ray_length);
#undef BP
		ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "animation_duration"), "set_animation_duration", "get_animation_duration");
		ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "ray_length"), "set_ray_length", "get_ray_length");

#define DP(name, group) \
		ADD_GROUP(group, #name "_"); \
		ClassDB::bind_method(D_METHOD("set_" #name "_path", "v"), &DoorController::set_##name##_path); \
		ClassDB::bind_method(D_METHOD("get_" #name "_path"), &DoorController::get_##name##_path); \
		ClassDB::bind_method(D_METHOD("set_" #name "_area_path", "v"), &DoorController::set_##name##_area_path); \
		ClassDB::bind_method(D_METHOD("get_" #name "_area_path"), &DoorController::get_##name##_area_path); \
		ClassDB::bind_method(D_METHOD("set_" #name "_axis", "v"), &DoorController::set_##name##_axis); \
		ClassDB::bind_method(D_METHOD("get_" #name "_axis"), &DoorController::get_##name##_axis); \
		ClassDB::bind_method(D_METHOD("set_" #name "_angle", "v"), &DoorController::set_##name##_angle); \
		ClassDB::bind_method(D_METHOD("get_" #name "_angle"), &DoorController::get_##name##_angle); \
		ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, #name "_path"), "set_" #name "_path", "get_" #name "_path"); \
		ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, #name "_area_path"), "set_" #name "_area_path", "get_" #name "_area_path"); \
		ADD_PROPERTY(PropertyInfo(Variant::VECTOR3, #name "_axis"), "set_" #name "_axis", "get_" #name "_axis"); \
		ADD_PROPERTY(PropertyInfo(Variant::FLOAT, #name "_angle"), "set_" #name "_angle", "get_" #name "_angle");

		DP(left_front_door, "Left Front Door"); DP(right_front_door, "Right Front Door");
		DP(left_rear_door, "Left Rear Door"); DP(right_rear_door, "Right Rear Door");
		DP(hood, "Hood"); DP(trunk, "Trunk"); DP(charge_port, "Charge Port");
#undef DP

		BIND_ENUM_CONSTANT(DOOR_LEFT_FRONT); BIND_ENUM_CONSTANT(DOOR_RIGHT_FRONT);
		BIND_ENUM_CONSTANT(DOOR_LEFT_REAR); BIND_ENUM_CONSTANT(DOOR_RIGHT_REAR);
		BIND_ENUM_CONSTANT(DOOR_HOOD); BIND_ENUM_CONSTANT(DOOR_TRUNK); BIND_ENUM_CONSTANT(DOOR_CHARGE_PORT); BIND_ENUM_CONSTANT(DOOR_COUNT);
		BIND_ENUM_CONSTANT(DOOR_STATE_CLOSED); BIND_ENUM_CONSTANT(DOOR_STATE_OPENING);
		BIND_ENUM_CONSTANT(DOOR_STATE_OPEN); BIND_ENUM_CONSTANT(DOOR_STATE_CLOSING);

		ADD_SIGNAL(MethodInfo("door_opened", PropertyInfo(Variant::INT, "door_type")));
		ADD_SIGNAL(MethodInfo("door_closed", PropertyInfo(Variant::INT, "door_type")));
		ADD_SIGNAL(MethodInfo("door_state_changed", PropertyInfo(Variant::INT, "door_type"), PropertyInfo(Variant::INT, "state")));
		ADD_SIGNAL(MethodInfo("interaction_visibility_changed", PropertyInfo(Variant::BOOL, "enabled")));

		ClassDB::bind_method(D_METHOD("toggle_door", "door_type"), &DoorController::toggle_door);
		ClassDB::bind_method(D_METHOD("open_door", "door_type"), &DoorController::open_door);
		ClassDB::bind_method(D_METHOD("close_door", "door_type"), &DoorController::close_door);
		ClassDB::bind_method(D_METHOD("is_door_open", "door_type"), &DoorController::is_door_open);
		ClassDB::bind_method(D_METHOD("get_door_state", "door_type"), &DoorController::get_door_state);
		ClassDB::bind_method(D_METHOD("open_all_doors"), &DoorController::open_all_doors);
		ClassDB::bind_method(D_METHOD("close_all_doors"), &DoorController::close_all_doors);
		ClassDB::bind_method(D_METHOD("set_interaction_enabled", "enabled"), &DoorController::set_interaction_enabled);
		ClassDB::bind_method(D_METHOD("is_interaction_enabled"), &DoorController::is_interaction_enabled);
		ClassDB::bind_method(D_METHOD("set_interaction_permitted", "enabled"), &DoorController::set_interaction_permitted);
		ClassDB::bind_method(D_METHOD("is_interaction_permitted"), &DoorController::is_interaction_permitted);
		ADD_PROPERTY(PropertyInfo(Variant::BOOL, "interaction_permitted"), "set_interaction_permitted", "is_interaction_permitted");
	}
};

VARIANT_ENUM_CAST(DoorController::DoorType);
VARIANT_ENUM_CAST(DoorController::DoorState);

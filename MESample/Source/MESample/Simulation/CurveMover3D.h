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
#include "Common/Funclib.h"
#include "godot_cpp/classes/curve3d.hpp"
#include "godot_cpp/classes/node3d.hpp"
#include "godot_cpp/classes/path3d.hpp"
#include "godot_cpp/classes/path_follow3d.hpp"
#include "godot_cpp/classes/wrapped.hpp"
#include "godot_cpp/variant/transform3d.hpp"
#include <map>

class CurveMover3D : public godot::Path3D {
	GDCLASS(CurveMover3D, godot::Path3D)

	godot::Dictionary m_stops{};
	REGISTER(stops)

	godot::PathFollow3D *m_path_follow{};
	REGISTER_NODE(path_follow)

	float m_driving_speed{0.f};
	REGISTER(driving_speed);

	float m_accelerate{ 0.f };
	REGISTER(accelerate);

	float length{};

	bool m_is_dwelling{};
	float m_dwell_left{};

	int m_current_index{ -1 };

	std::map<int, float> m_index2progress{};

	static void _bind_methods() {
		_bind_stops();
		_bind_path_follow();
		_bind_driving_speed();
		_bind_accelerate();

		ADD_SIGNAL(godot::MethodInfo("point_passed", godot::PropertyInfo(godot::Variant::INT, "point_index")));
	}

public:
	virtual void _ready() override {
		if (get_curve().is_null()) {
			set_curve(memnew(godot::Curve3D));
		}
		length = get_curve()->get_baked_length();
		for (int i = 0; i < get_curve()->get_point_count(); ++i) {
			get_curve()->set_point_tilt(i, 0.f);
		}
		m_index2progress[-1] = -1.f;
		for (int i = 0; i < get_curve()->get_point_count(); ++i) {
			m_index2progress[i] = get_curve()->get_closest_offset(get_curve()->get_point_position(i));
		}
	}

	virtual void _physics_process(double p_delta) override {
		if (m_is_dwelling) {
			m_dwell_left -= p_delta;
			if (m_dwell_left <= 0.f) {
				m_is_dwelling = false;
				m_current_index += 1;
			}
		}
		
		if (!m_path_follow) {
			Funclib::ns_errs(__FUNCTION__, __LINE__, " Null path_follow");
			return;
		}
		
		auto current_speed = m_is_dwelling ? 0.f : m_driving_speed;
		auto new_progress = m_path_follow->get_progress() + current_speed * p_delta;
		if(new_progress >= length){
			Funclib::ns_logs("CurveMover3D:","back to start");
			m_current_index = -1;
		}
		new_progress = std::fmodf(new_progress, length);
		m_path_follow->set_progress(new_progress);

		if (m_index2progress.contains(m_current_index + 1) && m_index2progress[m_current_index + 1] < new_progress) {
			m_current_index += 1;
			Funclib::ns_logs("point_passed", m_current_index);
			emit_signal("point_passed", m_current_index);
			if(m_stops.has(m_current_index)){
				m_is_dwelling = true;
				m_dwell_left = m_stops[m_current_index];
			}
		}
	}
};
#undef class_name
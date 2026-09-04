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
#ifndef COMMONLIB_H
#define COMMONLIB_H

#include "godot_cpp/variant/utility_functions.hpp"
#include <sstream>

#define COMPILE_TIME __DATE__ "::" __TIME__

#define LOG(level, ...) CommonLib::LogImplement<level>(__FILE__, ":", __LINE__, "   ", __VA_ARGS__);

#define LOGTEMP 1
#define LOGWARNING 2
#define LOGERROR 3

#define DECLEAR_SETANDGET(NAME)              \
	void Set##NAME(decltype(NAME) p##NAME) { \
		NAME = p##NAME;                      \
	}                                        \
	decltype(NAME) Get##NAME() {             \
		return NAME;                         \
	}

#define REGISTER(name)                                                                                 \
	void set_##name(decltype(m_##name) p_##name) {                                                     \
		m_##name = p_##name;                                                                           \
	}                                                                                                  \
	auto get_##name() {                                                                                \
		return m_##name;                                                                               \
	}                                                                                                  \
	static void _bind_##name() {                                                                       \
		::godot::ClassDB::bind_method(::godot::D_METHOD("set_" #name, #name), &self_type::set_##name); \
		::godot::ClassDB::bind_method(::godot::D_METHOD("get_" #name), &self_type::get_##name);        \
		decltype(m_##name) instance{};                                                                 \
		::godot::Variant v{ instance };                                                                \
		ADD_PROPERTY(::godot::PropertyInfo(v.get_type(), #name), "set_" #name, "get_" #name);          \
	}

#define REGISTER_NODE(name)                                                                                                                                                                                \
	void set_##name(decltype(m_##name) p_##name) {                                                                                                                                                         \
		m_##name = p_##name;                                                                                                                                                                               \
	}                                                                                                                                                                                                      \
	auto get_##name() {                                                                                                                                                                                    \
		return m_##name;                                                                                                                                                                                   \
	}                                                                                                                                                                                                      \
	static void _bind_##name() {                                                                                                                                                                           \
		::godot::ClassDB::bind_method(::godot::D_METHOD("set_" #name, #name), &self_type::set_##name);                                                                                                     \
		::godot::ClassDB::bind_method(::godot::D_METHOD("get_" #name), &self_type::get_##name);                                                                                                            \
		ADD_PROPERTY(::godot::PropertyInfo(::godot::Variant::OBJECT, #name, ::godot::PROPERTY_HINT_NODE_TYPE, std::remove_pointer_t<decltype(m_##name)>::get_class_static()), "set_" #name, "get_" #name); \
	}

namespace CommonLib {

template <int LogLevel, typename... Args>
void LogImplement(Args... args) {
	std::stringstream ss;
	ss << "[Version: " << COMPILE_TIME << "]: ";
	if constexpr (LogLevel == LOGERROR) {
		ss << "LogError: ";
		((ss << args), ...);
		godot::UtilityFunctions::printerr(ss.str().c_str());
	} else if constexpr (LogLevel == LOGWARNING) {
		ss << "LogWarning: ";
		((ss << args), ...);
		godot::UtilityFunctions::print(ss.str().c_str());
	} else {
		ss << "LogTemp: ";
		((ss << args), ...);
		godot::UtilityFunctions::print(ss.str().c_str());
	}
}

} //namespace CommonLib

#endif
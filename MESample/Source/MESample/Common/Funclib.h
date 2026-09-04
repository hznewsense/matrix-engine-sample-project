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
#ifndef FUNLIB_H
#define FUNLIB_H

#include <godot_cpp/variant/utility_functions.hpp>

#include <sstream>
#include <string>
#include <type_traits>

#ifdef NS_ANDROID
#include <android/log.h>
#endif

namespace Funclib {

inline void _ns_log(const std::string &p_tag, const std::string &p_str) {
#ifdef NS_ANDROID
	__android_log_print(ANDROID_LOG_INFO, p_tag.data(), "%s", p_str.c_str());
#else
	(void)p_tag;
	godot::UtilityFunctions::print(p_str.data());
#endif
}

inline void _ns_err(const std::string &p_tag, const std::string &p_str) {
#ifdef NS_ANDROID
	__android_log_print(ANDROID_LOG_ERROR, p_tag.data(), "%s", p_str.c_str());
#else
	(void)p_tag;
	godot::UtilityFunctions::printerr(p_str.data());
#endif
}

inline std::string to_string(const std::string &p_arg) {
	return p_arg;
}

inline std::string to_string(const char *p_arg) {
	return std::string{ p_arg };
}

template <typename E>
inline typename std::enable_if<std::is_enum<E>::value, std::string>::type
to_string(E e) {
	using Underlying = typename std::underlying_type<E>::type;
	return std::to_string(static_cast<Underlying>(e));
}

inline std::string to_string(int p_arg) {
	return std::to_string(p_arg);
}

inline std::string to_string(float p_arg) {
	return std::to_string(p_arg);
}

template <typename... Args>
inline void ns_log(const Args &...args) {
	std::array<std::string, sizeof...(Args)> variant_args{ std::forward<std::string>(to_string(args))... };
	std::string result{};
	std::ostringstream oss;
	for (const auto &arg : variant_args) {
		oss << arg;
	}
	_ns_log("NS_LOG", oss.str());
}

template <typename... Args>
inline void ns_logs(const Args &...args) {
	std::array<std::string, sizeof...(Args)> variant_args{ std::forward<std::string>(to_string(args))... };
	std::string result{};
	std::ostringstream oss;
	for (const auto &arg : variant_args) {
		oss << arg << " ";
	}
	_ns_log("NS_LOG", oss.str());
}

template <typename... Args>
inline void ns_logt(const Args &...args) {
	std::array<std::string, sizeof...(Args)> variant_args{ std::forward<std::string>(to_string(args))... };
	std::string result{};
	std::ostringstream oss;
	for (const auto &arg : variant_args) {
		oss << arg << "\t";
	}
	_ns_log("NS_LOG", oss.str());
}

template <typename... Args>
inline void ns_err(const Args &...args) {
	std::array<std::string, sizeof...(Args)> variant_args{ std::forward<std::string>(to_string(args))... };
	std::string result{};
	std::ostringstream oss;
	for (const auto &arg : variant_args) {
		oss << arg;
	}
	_ns_err("NS_LOG", oss.str());
}

template <typename... Args>
inline void ns_errs(const Args &...args) {
	std::array<std::string, sizeof...(Args)> variant_args{ std::forward<std::string>(to_string(args))... };
	std::string result{};
	std::ostringstream oss;
	for (const auto &arg : variant_args) {
		oss << arg << " ";
	}
	_ns_err("NS_LOG", oss.str());
}

template <typename... Args>
inline void ns_errt(const Args &...args) {
	std::array<std::string, sizeof...(Args)> variant_args{ std::forward<std::string>(to_string(args))... };
	std::string result{};
	std::ostringstream oss;
	for (const auto &arg : variant_args) {
		oss << arg << "\t";
	}
	_ns_err("NS_LOG", oss.str());
}

} //namespace Funclib

#endif
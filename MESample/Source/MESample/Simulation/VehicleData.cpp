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

#include "VehicleData.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>

VehicleData::VehicleData() {
    std::random_device rd;
    rng = std::mt19937(rd());

    current_speed = 0.0;
    target_speed = 60.0;
    acceleration = 0.0;

    noa_status = NOA_ACTIVE;
    noa_warning = "";
    noa_remaining_distance = 15000.0;
    noa_lane_change_pending = false;

    traffic_light_timer = 0.0;
    speed_change_timer = 0.0;
    current_nav_index = 0;
    is_paused = false;
    use_external_target_speed = false;

    // 初始化红绿灯数据
    traffic_light["id"] = 1;
    traffic_light["color"] = (int)TRAFFIC_RED;
    traffic_light["countdown"] = 30.0;
    traffic_light["distance"] = 150.0;

    // 初始化导航数据
    _generate_random_navigation();
    
    // ========== 初始化轨迹事件数据 ==========
    use_trajectory_mode = false;
    current_speed_limit = 30;
    current_min_speed = 0;
    tbt_distance_meters = 500;
    tbt_direction = ROAD_ARROW_STRAIGHT;
    // 使用UTF-8编码的道路名称
    tbt_road_name = String::utf8("江 南 大 道");
    nav_remaining_minutes = 5;
    nav_remaining_seconds = 30;
    nav_arrive_hour = 11;
    nav_arrive_minute = 30;
    
    // 初始化道路箭头（1:直行, 2:直行, 3:直行）
    road_arrows.clear();
    road_arrows.push_back(ROAD_ARROW_STRAIGHT);
    road_arrows.push_back(ROAD_ARROW_STRAIGHT);
    road_arrows.push_back(ROAD_ARROW_STRAIGHT);
    
    // 初始化TBT距离累积器
    tbt_distance_accumulator = 0.0;
}

VehicleData::~VehicleData() {
}

void VehicleData::_bind_methods() {
    // 枚举绑定
    BIND_ENUM_CONSTANT(NOA_INACTIVE);
    BIND_ENUM_CONSTANT(NOA_ACTIVE);
    BIND_ENUM_CONSTANT(NOA_UNAVAILABLE);

    BIND_ENUM_CONSTANT(TRAFFIC_RED);
    BIND_ENUM_CONSTANT(TRAFFIC_YELLOW);
    BIND_ENUM_CONSTANT(TRAFFIC_GREEN);
    
    BIND_ENUM_CONSTANT(ROAD_ARROW_STRAIGHT);
    BIND_ENUM_CONSTANT(ROAD_ARROW_LEFT);
    BIND_ENUM_CONSTANT(ROAD_ARROW_RIGHT);
    BIND_ENUM_CONSTANT(ROAD_ARROW_UTURN);

    // 信号
    ADD_SIGNAL(MethodInfo("speed_changed", PropertyInfo(Variant::FLOAT, "speed")));
    ADD_SIGNAL(MethodInfo("noa_status_changed", PropertyInfo(Variant::INT, "status"), PropertyInfo(Variant::STRING, "warning")));
    ADD_SIGNAL(MethodInfo("traffic_light_changed", PropertyInfo(Variant::DICTIONARY, "light_data")));
    ADD_SIGNAL(MethodInfo("navigation_changed", PropertyInfo(Variant::ARRAY, "instructions")));
    
    // 新增信号
    ADD_SIGNAL(MethodInfo("speed_limit_changed", PropertyInfo(Variant::INT, "limit"), PropertyInfo(Variant::INT, "min_speed")));
    ADD_SIGNAL(MethodInfo("road_arrows_changed", PropertyInfo(Variant::ARRAY, "arrows")));
    ADD_SIGNAL(MethodInfo("tbt_changed", PropertyInfo(Variant::STRING, "road_name"), PropertyInfo(Variant::INT, "distance"), PropertyInfo(Variant::INT, "direction")));
    ADD_SIGNAL(MethodInfo("nav_time_changed", PropertyInfo(Variant::INT, "minutes"), PropertyInfo(Variant::INT, "seconds"), PropertyInfo(Variant::INT, "arrive_hour"), PropertyInfo(Variant::INT, "arrive_minute")));

    // 车速方法
    ClassDB::bind_method(D_METHOD("get_current_speed"), &VehicleData::get_current_speed);
    ClassDB::bind_method(D_METHOD("set_current_speed", "speed"), &VehicleData::set_current_speed);
    ClassDB::bind_method(D_METHOD("get_target_speed"), &VehicleData::get_target_speed);
    ClassDB::bind_method(D_METHOD("set_target_speed", "speed"), &VehicleData::set_target_speed);
    
    // 模拟参数方法
    ClassDB::bind_method(D_METHOD("get_random_speed_min"), &VehicleData::get_random_speed_min);
    ClassDB::bind_method(D_METHOD("set_random_speed_min", "value"), &VehicleData::set_random_speed_min);
    ClassDB::bind_method(D_METHOD("get_random_speed_max"), &VehicleData::get_random_speed_max);
    ClassDB::bind_method(D_METHOD("set_random_speed_max", "value"), &VehicleData::set_random_speed_max);
    ClassDB::bind_method(D_METHOD("get_accel_rate"), &VehicleData::get_accel_rate);
    ClassDB::bind_method(D_METHOD("set_accel_rate", "value"), &VehicleData::set_accel_rate);
    ClassDB::bind_method(D_METHOD("get_decel_rate"), &VehicleData::get_decel_rate);
    ClassDB::bind_method(D_METHOD("set_decel_rate", "value"), &VehicleData::set_decel_rate);
    ClassDB::bind_method(D_METHOD("get_speed_change_interval"), &VehicleData::get_speed_change_interval);
    ClassDB::bind_method(D_METHOD("set_speed_change_interval", "value"), &VehicleData::set_speed_change_interval);

    // NOA方法
    ClassDB::bind_method(D_METHOD("get_noa_status"), &VehicleData::get_noa_status);
    ClassDB::bind_method(D_METHOD("set_noa_status", "status"), &VehicleData::set_noa_status);
    ClassDB::bind_method(D_METHOD("get_noa_warning"), &VehicleData::get_noa_warning);
    ClassDB::bind_method(D_METHOD("set_noa_warning", "warning"), &VehicleData::set_noa_warning);
    ClassDB::bind_method(D_METHOD("get_noa_remaining_distance"), &VehicleData::get_noa_remaining_distance);
    ClassDB::bind_method(D_METHOD("set_noa_remaining_distance", "distance"), &VehicleData::set_noa_remaining_distance);
    ClassDB::bind_method(D_METHOD("is_noa_lane_change_pending"), &VehicleData::is_noa_lane_change_pending);
    ClassDB::bind_method(D_METHOD("set_noa_lane_change_pending", "pending"), &VehicleData::set_noa_lane_change_pending);

    // 红绿灯方法
    ClassDB::bind_method(D_METHOD("get_traffic_light"), &VehicleData::get_traffic_light);
    ClassDB::bind_method(D_METHOD("set_traffic_light", "light"), &VehicleData::set_traffic_light);
    ClassDB::bind_method(D_METHOD("get_traffic_light_id"), &VehicleData::get_traffic_light_id);
    ClassDB::bind_method(D_METHOD("get_traffic_light_color"), &VehicleData::get_traffic_light_color);
    ClassDB::bind_method(D_METHOD("get_traffic_light_countdown"), &VehicleData::get_traffic_light_countdown);
    ClassDB::bind_method(D_METHOD("get_traffic_light_distance"), &VehicleData::get_traffic_light_distance);

    // 导航方法
    ClassDB::bind_method(D_METHOD("get_navigation_instructions"), &VehicleData::get_navigation_instructions);
    ClassDB::bind_method(D_METHOD("set_navigation_instructions", "instructions"), &VehicleData::set_navigation_instructions);
    ClassDB::bind_method(D_METHOD("get_current_nav_index"), &VehicleData::get_current_nav_index);
    ClassDB::bind_method(D_METHOD("set_current_nav_index", "index"), &VehicleData::set_current_nav_index);
    ClassDB::bind_method(D_METHOD("get_current_navigation"), &VehicleData::get_current_navigation);

    // 模拟更新
    ClassDB::bind_method(D_METHOD("update_simulation", "delta_time"), &VehicleData::update_simulation);

    // 模拟控制
    ClassDB::bind_method(D_METHOD("reset"), &VehicleData::reset);
    ClassDB::bind_method(D_METHOD("pause"), &VehicleData::pause);
    ClassDB::bind_method(D_METHOD("resume"), &VehicleData::resume);
    ClassDB::bind_method(D_METHOD("get_is_paused"), &VehicleData::get_is_paused);
    ClassDB::bind_method(D_METHOD("reset_external_target_speed"), &VehicleData::reset_external_target_speed);
    ClassDB::bind_method(D_METHOD("reset_speed_timer"), &VehicleData::reset_speed_timer);
    
    // ========== 轨迹事件模式方法绑定 ==========
    ClassDB::bind_method(D_METHOD("set_trajectory_events", "events"), &VehicleData::set_trajectory_events);
    ClassDB::bind_method(D_METHOD("get_trajectory_events"), &VehicleData::get_trajectory_events);
    ClassDB::bind_method(D_METHOD("set_use_trajectory_mode", "use"), &VehicleData::set_use_trajectory_mode);
    ClassDB::bind_method(D_METHOD("get_use_trajectory_mode"), &VehicleData::get_use_trajectory_mode);
    ClassDB::bind_method(D_METHOD("on_trajectory_point_passed", "point_index"), &VehicleData::on_trajectory_point_passed);
    
    // 限速方法
    ClassDB::bind_method(D_METHOD("get_current_speed_limit"), &VehicleData::get_current_speed_limit);
    ClassDB::bind_method(D_METHOD("set_current_speed_limit", "limit"), &VehicleData::set_current_speed_limit);
    ClassDB::bind_method(D_METHOD("get_current_min_speed"), &VehicleData::get_current_min_speed);
    ClassDB::bind_method(D_METHOD("set_current_min_speed", "min_speed"), &VehicleData::set_current_min_speed);
    
    // 道路箭头方法
    ClassDB::bind_method(D_METHOD("get_road_arrows"), &VehicleData::get_road_arrows);
    ClassDB::bind_method(D_METHOD("set_road_arrows", "arrows"), &VehicleData::set_road_arrows);
    
    // TBT导航方法
    ClassDB::bind_method(D_METHOD("get_tbt_road_name"), &VehicleData::get_tbt_road_name);
    ClassDB::bind_method(D_METHOD("set_tbt_road_name", "name"), &VehicleData::set_tbt_road_name);
    ClassDB::bind_method(D_METHOD("get_tbt_distance"), &VehicleData::get_tbt_distance);
    ClassDB::bind_method(D_METHOD("set_tbt_distance", "distance"), &VehicleData::set_tbt_distance);
    ClassDB::bind_method(D_METHOD("get_tbt_direction"), &VehicleData::get_tbt_direction);
    ClassDB::bind_method(D_METHOD("set_tbt_direction", "direction"), &VehicleData::set_tbt_direction);
    
    // 导航时间方法
    ClassDB::bind_method(D_METHOD("get_nav_remaining_minutes"), &VehicleData::get_nav_remaining_minutes);
    ClassDB::bind_method(D_METHOD("set_nav_remaining_minutes", "minutes"), &VehicleData::set_nav_remaining_minutes);
    ClassDB::bind_method(D_METHOD("get_nav_remaining_seconds"), &VehicleData::get_nav_remaining_seconds);
    ClassDB::bind_method(D_METHOD("set_nav_remaining_seconds", "seconds"), &VehicleData::set_nav_remaining_seconds);
    ClassDB::bind_method(D_METHOD("get_nav_arrive_hour"), &VehicleData::get_nav_arrive_hour);
    ClassDB::bind_method(D_METHOD("set_nav_arrive_hour", "hour"), &VehicleData::set_nav_arrive_hour);
    ClassDB::bind_method(D_METHOD("get_nav_arrive_minute"), &VehicleData::get_nav_arrive_minute);
    ClassDB::bind_method(D_METHOD("set_nav_arrive_minute", "minute"), &VehicleData::set_nav_arrive_minute);
    ClassDB::bind_method(D_METHOD("update_nav_time"), &VehicleData::update_nav_time);

    // 属性
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "current_speed"), "set_current_speed", "get_current_speed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "target_speed"), "set_target_speed", "get_target_speed");
    
    // 模拟参数属性（在检查器中可见）
    ADD_GROUP("Speed Simulation", "speed_");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed_random_min", PROPERTY_HINT_RANGE, "0,200,1"), "set_random_speed_min", "get_random_speed_min");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed_random_max", PROPERTY_HINT_RANGE, "0,200,1"), "set_random_speed_max", "get_random_speed_max");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed_accel_rate", PROPERTY_HINT_RANGE, "0.1,50,0.1"), "set_accel_rate", "get_accel_rate");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed_decel_rate", PROPERTY_HINT_RANGE, "0.1,50,0.1"), "set_decel_rate", "get_decel_rate");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed_change_interval", PROPERTY_HINT_RANGE, "1,30,0.5"), "set_speed_change_interval", "get_speed_change_interval");
    
    ADD_GROUP("", "");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "noa_status", PROPERTY_HINT_ENUM, "Inactive,Active,Unavailable"), "set_noa_status", "get_noa_status");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "noa_warning"), "set_noa_warning", "get_noa_warning");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "noa_remaining_distance"), "set_noa_remaining_distance", "get_noa_remaining_distance");
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "traffic_light"), "set_traffic_light", "get_traffic_light");
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "navigation_instructions"), "set_navigation_instructions", "get_navigation_instructions");
    
    // ========== 轨迹事件属性 ==========
    ADD_GROUP("Trajectory Events", "trajectory_");
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "trajectory_events"), "set_trajectory_events", "get_trajectory_events");
    ADD_PROPERTY(PropertyInfo(Variant::BOOL, "trajectory_use_mode"), "set_use_trajectory_mode", "get_use_trajectory_mode");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "trajectory_speed_limit", PROPERTY_HINT_RANGE, "0,200,1"), "set_current_speed_limit", "get_current_speed_limit");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "trajectory_min_speed", PROPERTY_HINT_RANGE, "0,200,1"), "set_current_min_speed", "get_current_min_speed");
    ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "trajectory_road_arrows"), "set_road_arrows", "get_road_arrows");
    
    ADD_GROUP("TBT Navigation", "tbt_");
    ADD_PROPERTY(PropertyInfo(Variant::STRING, "tbt_road_name"), "set_tbt_road_name", "get_tbt_road_name");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "tbt_distance"), "set_tbt_distance", "get_tbt_distance");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "tbt_direction", PROPERTY_HINT_ENUM, "Straight,Left,Right,UTurn"), "set_tbt_direction", "get_tbt_direction");
    
    ADD_GROUP("Navigation Time", "nav_");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "nav_remaining_minutes"), "set_nav_remaining_minutes", "get_nav_remaining_minutes");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "nav_remaining_seconds"), "set_nav_remaining_seconds", "get_nav_remaining_seconds");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "nav_arrive_hour"), "set_nav_arrive_hour", "get_nav_arrive_hour");
    ADD_PROPERTY(PropertyInfo(Variant::INT, "nav_arrive_minute"), "set_nav_arrive_minute", "get_nav_arrive_minute");
}

// 车速实现
double VehicleData::get_current_speed() const {
    return current_speed;
}

void VehicleData::set_current_speed(double p_speed) {
    current_speed = std::clamp(p_speed, 0.0, 200.0);
}

double VehicleData::get_target_speed() const {
    return target_speed;
}

void VehicleData::set_target_speed(double p_speed) {
    target_speed = std::clamp(p_speed, 0.0, 200.0);
    // 外部设置目标车速时，启用外部控制模式
    use_external_target_speed = true;
}

// 模拟参数实现
double VehicleData::get_random_speed_min() const {
    return random_speed_min;
}

void VehicleData::set_random_speed_min(double p_value) {
    random_speed_min = std::clamp(p_value, 0.0, 200.0);
}

double VehicleData::get_random_speed_max() const {
    return random_speed_max;
}

void VehicleData::set_random_speed_max(double p_value) {
    random_speed_max = std::clamp(p_value, 0.0, 200.0);
}

double VehicleData::get_accel_rate() const {
    return accel_rate;
}

void VehicleData::set_accel_rate(double p_value) {
    accel_rate = std::max(0.1, p_value);
}

double VehicleData::get_decel_rate() const {
    return decel_rate;
}

void VehicleData::set_decel_rate(double p_value) {
    decel_rate = std::max(0.1, p_value);
}

double VehicleData::get_speed_change_interval() const {
    return speed_change_interval;
}

void VehicleData::set_speed_change_interval(double p_value) {
    speed_change_interval = std::max(0.5, p_value);
}

// NOA实现
VehicleData::ENOAStatus VehicleData::get_noa_status() const {
    return noa_status;
}

void VehicleData::set_noa_status(ENOAStatus p_status) {
    if (noa_status != p_status) {
        noa_status = p_status;
        emit_noa_status_changed();
    }
}

String VehicleData::get_noa_warning() const {
    return noa_warning;
}

void VehicleData::set_noa_warning(const String &p_warning) {
    noa_warning = p_warning;
}

double VehicleData::get_noa_remaining_distance() const {
    return noa_remaining_distance;
}

void VehicleData::set_noa_remaining_distance(double p_distance) {
    noa_remaining_distance = std::max(0.0, p_distance);
}

bool VehicleData::is_noa_lane_change_pending() const {
    return noa_lane_change_pending;
}

void VehicleData::set_noa_lane_change_pending(bool p_pending) {
    noa_lane_change_pending = p_pending;
}

// 红绿灯实现
Dictionary VehicleData::get_traffic_light() const {
    return traffic_light;
}

void VehicleData::set_traffic_light(const Dictionary &p_light) {
    traffic_light = p_light;
}

int VehicleData::get_traffic_light_id() const {
    return traffic_light.get("id", 0);
}

VehicleData::ETrafficLightColor VehicleData::get_traffic_light_color() const {
    return (ETrafficLightColor)(int)traffic_light.get("color", TRAFFIC_RED);
}

double VehicleData::get_traffic_light_countdown() const {
    return traffic_light.get("countdown", 0.0);
}

double VehicleData::get_traffic_light_distance() const {
    return traffic_light.get("distance", 0.0);
}

// 导航实现
Array VehicleData::get_navigation_instructions() const {
    return navigation_instructions;
}

void VehicleData::set_navigation_instructions(const Array &p_instructions) {
    navigation_instructions = p_instructions;
}

int VehicleData::get_current_nav_index() const {
    return current_nav_index;
}

void VehicleData::set_current_nav_index(int p_index) {
    current_nav_index = std::clamp(p_index, 0, std::max(0, (int)navigation_instructions.size() - 1));
}

Dictionary VehicleData::get_current_navigation() const {
    if (navigation_instructions.size() > 0 && current_nav_index < navigation_instructions.size()) {
        return navigation_instructions[current_nav_index];
    }
    return Dictionary();
}

// 主更新函数
void VehicleData::update_simulation(double delta_time) {
    if (is_paused) {
        return;
    }
    
    // 车速模拟始终运行
    _update_speed_simulation(delta_time);
    
    if (use_trajectory_mode) {
        // 轨迹事件模式：只更新红绿灯倒计时
        _update_trajectory_mode(delta_time);
    } else {
        // 随机模拟模式
        _update_noa_simulation(delta_time);
        _update_traffic_light_simulation(delta_time);
        _update_navigation_simulation(delta_time);
    }
}

// 车速模拟
void VehicleData::_update_speed_simulation(double delta_time) {
    // 只有在非外部控制模式下才随机改变目标速度
    if (!use_external_target_speed) {
        speed_change_timer += delta_time;

        // 隔一段时间改变目标速度
        if (speed_change_timer >= speed_change_interval) {
            speed_change_timer = 0.0;
            std::uniform_real_distribution<double> dist(random_speed_min, random_speed_max);
            target_speed = dist(rng);
        }
    }

    // 平滑加速/减速
    double speed_diff = target_speed - current_speed;
    if (std::abs(speed_diff) > 0.5) {
        acceleration = speed_diff > 0 ? accel_rate : -decel_rate;
        current_speed += acceleration * delta_time;
        current_speed = std::clamp(current_speed, 0.0, 200.0);
        emit_speed_changed();
    } else if (target_speed <= 0.0 && current_speed <= 0.5) {
        // 目标车速为0且当前车速很小时，直接设为0
        current_speed = 0.0;
        emit_speed_changed();
    }
}

// NOA模拟
void VehicleData::_update_noa_simulation(double delta_time) {
    if (noa_status == NOA_ACTIVE) {
        // 减少剩余距离
        double speed_mps = current_speed / 3.6; // km/h -> m/s
        noa_remaining_distance -= speed_mps * delta_time;

        if (noa_remaining_distance <= 0) {
            // 到达NOA终点
            noa_status = NOA_INACTIVE;
            noa_warning = "NOA ended, please take over";
            emit_noa_status_changed();
        } else if (noa_remaining_distance < 1000 && !noa_warning.contains("approaching")) {
            noa_warning = "Approaching NOA end point in 1km";
            emit_noa_status_changed();
        }

        // 随机变道请求
        std::uniform_real_distribution<double> dist(0.0, 1.0);
        if (!noa_lane_change_pending && dist(rng) < 0.001) { // 0.1%概率每帧
            noa_lane_change_pending = true;
            noa_warning = "Lane change suggested: keep left";
            emit_noa_status_changed();
        } else if (noa_lane_change_pending && dist(rng) < 0.02) { // 2%概率完成变道
            noa_lane_change_pending = false;
            noa_warning = "";
            emit_noa_status_changed();
        }
    }
}

// 红绿灯模拟
void VehicleData::_update_traffic_light_simulation(double delta_time) {
    double countdown = get_traffic_light_countdown();
    ETrafficLightColor color = get_traffic_light_color();
    double distance = get_traffic_light_distance();

    // 倒计时递减
    countdown -= delta_time;
    if (countdown <= 0) {
        // 切换到下一个颜色
        switch (color) {
            case TRAFFIC_RED:
                color = TRAFFIC_GREEN;
                countdown = 25.0 + std::uniform_real_distribution<double>(0, 10)(rng);
                break;
            case TRAFFIC_GREEN:
                color = TRAFFIC_YELLOW;
                countdown = 3.0;
                break;
            case TRAFFIC_YELLOW:
                color = TRAFFIC_RED;
                countdown = 20.0 + std::uniform_real_distribution<double>(0, 15)(rng);
                break;
        }
    }

    // 根据车速减少距离
    double speed_mps = current_speed / 3.6;
    distance -= speed_mps * delta_time;

    // 如果通过了红绿灯，生成新的红绿灯
    if (distance <= 10.0) {
        std::uniform_int_distribution<int> id_dist(1, 100);
        std::uniform_real_distribution<double> distance_dist(100.0, 500.0);
        std::uniform_int_distribution<int> color_dist(0, 2);

        traffic_light["id"] = id_dist(rng);
        color = (ETrafficLightColor)color_dist(rng);
        distance = distance_dist(rng);

        switch (color) {
            case TRAFFIC_RED:
                countdown = 20.0 + std::uniform_real_distribution<double>(0, 15)(rng);
                break;
            case TRAFFIC_GREEN:
                countdown = 25.0 + std::uniform_real_distribution<double>(0, 10)(rng);
                break;
            case TRAFFIC_YELLOW:
                countdown = 3.0;
                break;
        }
    }

    traffic_light["color"] = (int)color;
    traffic_light["countdown"] = countdown;
    traffic_light["distance"] = distance;

    emit_traffic_light_changed();
}

// 导航模拟
void VehicleData::_update_navigation_simulation(double delta_time) {
    if (navigation_instructions.size() == 0) {
        return;
    }

    Dictionary current_nav = get_current_navigation();
    if (current_nav.is_empty()) {
        return;
    }

    double nav_distance = current_nav.get("distance", 0.0);
    double speed_mps = current_speed / 3.6;
    nav_distance -= speed_mps * delta_time;

    if (nav_distance <= 0) {
        // 进入下一个导航点
        current_nav_index++;
        if (current_nav_index >= navigation_instructions.size()) {
            // 到达终点，重新生成导航
            _generate_random_navigation();
            current_nav_index = 0;
        }
        emit_navigation_changed();
    } else {
        // 更新当前导航点距离
        current_nav["distance"] = nav_distance;
        navigation_instructions[current_nav_index] = current_nav;
    }
}

// 生成随机导航数据
void VehicleData::_generate_random_navigation() {
    navigation_instructions.clear();

    Array instructions_list;
    instructions_list.push_back("前方右转");
    instructions_list.push_back("前方左转");
    instructions_list.push_back("直行");
    instructions_list.push_back("靠左行驶");
    instructions_list.push_back("靠右行驶");
    instructions_list.push_back("进入隧道");
    instructions_list.push_back("驶出隧道");
    instructions_list.push_back("进入服务区");
    instructions_list.push_back("前方有测速摄像头");
    instructions_list.push_back("前方匝道出口");

    std::uniform_int_distribution<int> count_dist(3, 6);
    int count = count_dist(rng);

    std::uniform_real_distribution<double> distance_dist(500.0, 5000.0);

    for (int i = 0; i < count; i++) {
        Dictionary nav_point;

        std::uniform_int_distribution<int> instr_idx(0, instructions_list.size() - 1);
        nav_point["instruction"] = instructions_list[instr_idx(rng)];
        nav_point["distance"] = distance_dist(rng) * (count - i) / count; // 距离递减

        // 方向指示: 0=直行, 1=左转, 2=右转, 3=掉头
        std::uniform_int_distribution<int> direction_dist(0, 3);
        nav_point["direction"] = direction_dist(rng);

        // 道路名称
        Array road_names;
        road_names.push_back("G15沈海高速");
        road_names.push_back("G2京沪高速");
        road_names.push_back("S20外环高速");
        road_names.push_back("人民路");
        road_names.push_back("中山路");
        road_names.push_back("解放大道");
        std::uniform_int_distribution<int> road_idx(0, road_names.size() - 1);
        nav_point["road_name"] = road_names[road_idx(rng)];

        navigation_instructions.push_back(nav_point);
    }

    current_nav_index = 0;
}

// 发射信号
void VehicleData::emit_speed_changed() {
    emit_signal("speed_changed", current_speed);
}

void VehicleData::emit_noa_status_changed() {
    emit_signal("noa_status_changed", (int)noa_status, noa_warning);
}

void VehicleData::emit_traffic_light_changed() {
    emit_signal("traffic_light_changed", traffic_light);
}

void VehicleData::emit_navigation_changed() {
    emit_signal("navigation_changed", navigation_instructions);
}

// 模拟控制
void VehicleData::reset() {
    current_speed = 0.0;
    target_speed = 60.0;
    acceleration = 0.0;

    noa_status = NOA_ACTIVE;
    noa_warning = "";
    noa_remaining_distance = 15000.0;
    noa_lane_change_pending = false;

    traffic_light_timer = 0.0;
    speed_change_timer = 0.0;
    current_nav_index = 0;
    is_paused = false;

    // 重置红绿灯数据
    traffic_light["id"] = 1;
    traffic_light["color"] = (int)TRAFFIC_RED;
    traffic_light["countdown"] = 30.0;
    traffic_light["distance"] = 150.0;

    // 重新生成导航数据
    _generate_random_navigation();

    // 发射信号通知UI更新
    emit_speed_changed();
    emit_noa_status_changed();
    emit_traffic_light_changed();
    emit_navigation_changed();
}

void VehicleData::pause() {
    is_paused = true;
}

void VehicleData::resume() {
    is_paused = false;
}

bool VehicleData::get_is_paused() const {
    return is_paused;
}

void VehicleData::reset_external_target_speed() {
    use_external_target_speed = false;
}

void VehicleData::reset_speed_timer() {
    speed_change_timer = 0.0;
}

// ========== 轨迹事件模式实现 ==========

void VehicleData::set_trajectory_events(const Dictionary &p_events) {
    trajectory_events = p_events;
}

Dictionary VehicleData::get_trajectory_events() const {
    return trajectory_events;
}

void VehicleData::set_use_trajectory_mode(bool p_use) {
    use_trajectory_mode = p_use;
}

bool VehicleData::get_use_trajectory_mode() const {
    return use_trajectory_mode;
}

void VehicleData::on_trajectory_point_passed(int point_index) {
    // 检查是否有该点的轨迹事件配置
    if (!trajectory_events.has(point_index)) {
        return;
    }
    
    Dictionary event = trajectory_events[point_index];
    
    // 处理NOA状态变化
    if (event.has("noa_status")) {
        set_noa_status((ENOAStatus)(int)event["noa_status"]);
    }
    if (event.has("noa_warning")) {
        set_noa_warning(event["noa_warning"]);
    }
    if (event.has("noa_remaining_distance")) {
        set_noa_remaining_distance(event["noa_remaining_distance"]);
    }
    
    // 处理红绿灯变化
    if (event.has("traffic_light")) {
        Dictionary tl_event = event["traffic_light"];
        if (tl_event.has("color")) {
            traffic_light["color"] = tl_event["color"];
        }
        if (tl_event.has("countdown")) {
            traffic_light["countdown"] = tl_event["countdown"];
        }
        if (tl_event.has("distance")) {
            traffic_light["distance"] = tl_event["distance"];
        }
        if (tl_event.has("id")) {
            traffic_light["id"] = tl_event["id"];
        }
        emit_traffic_light_changed();
    }
    
    // 处理限速变化（确保最低限速<=最高限速）
    int new_max_limit = current_speed_limit;
    int new_min_limit = current_min_speed;
    
    if (event.has("speed_limit")) {
        new_max_limit = (int)event["speed_limit"];
    }
    if (event.has("min_speed")) {
        new_min_limit = (int)event["min_speed"];
    }
    
    // 确保最低限速不超过最高限速
    if (new_min_limit > new_max_limit) {
        new_min_limit = new_max_limit - 20; // 最低比最高少20
        if (new_min_limit < 0) new_min_limit = 0;
    }
    
    current_speed_limit = new_max_limit;
    current_min_speed = new_min_limit;
    emit_speed_limit_changed();
    
    // 处理道路箭头变化（修正逻辑：1:直行/左转, 2:直行, 3:直行/右转）
    if (event.has("road_arrows")) {
        Array arrows = event["road_arrows"];
        road_arrows.clear();
        
        // 第一个箭头：直行(0)或左转(1)
        int arrow1 = ROAD_ARROW_STRAIGHT;
        if (arrows.size() >= 1) {
            int a = (int)arrows[0];
            if (a == ROAD_ARROW_LEFT || a == ROAD_ARROW_STRAIGHT) {
                arrow1 = a;
            }
        }
        road_arrows.push_back(arrow1);
        
        // 第二个箭头：永远是直行
        road_arrows.push_back(ROAD_ARROW_STRAIGHT);
        
        // 第三个箭头：直行(0)或右转(2)
        int arrow3 = ROAD_ARROW_STRAIGHT;
        if (arrows.size() >= 3) {
            int a = (int)arrows[2];
            if (a == ROAD_ARROW_RIGHT || a == ROAD_ARROW_STRAIGHT) {
                arrow3 = a;
            }
        }
        road_arrows.push_back(arrow3);
        
        emit_road_arrows_changed();
    }
    
    // 处理TBT导航变化（方向只能是直行或左转）
    if (event.has("tbt")) {
        Dictionary tbt_event = event["tbt"];
        if (tbt_event.has("road_name")) {
            set_tbt_road_name(tbt_event["road_name"]);
        }
        if (tbt_event.has("distance")) {
            set_tbt_distance(tbt_event["distance"]);
        }
        if (tbt_event.has("direction")) {
            int dir = (int)tbt_event["direction"];
            // TBT方向只能是直行(0)或左转(1)
            if (dir != ROAD_ARROW_LEFT && dir != ROAD_ARROW_STRAIGHT) {
                dir = ROAD_ARROW_STRAIGHT;
            }
            set_tbt_direction(dir);
        }
        emit_tbt_changed();
    }
    
    // 处理导航时间变化（到达时间只在轨迹点更新）
    if (event.has("nav_time")) {
        Dictionary nav_event = event["nav_time"];
        if (nav_event.has("minutes")) {
            set_nav_remaining_minutes(nav_event["minutes"]);
        }
        if (nav_event.has("seconds")) {
            set_nav_remaining_seconds(nav_event["seconds"]);
        }
        if (nav_event.has("arrive_hour")) {
            set_nav_arrive_hour(nav_event["arrive_hour"]);
        }
        if (nav_event.has("arrive_minute")) {
            set_nav_arrive_minute(nav_event["arrive_minute"]);
        }
        emit_nav_time_changed();
    }
}

// 限速实现
int VehicleData::get_current_speed_limit() const {
    return current_speed_limit;
}

void VehicleData::set_current_speed_limit(int p_limit) {
    current_speed_limit = std::clamp(p_limit, 0, 200);
    emit_speed_limit_changed();
}

int VehicleData::get_current_min_speed() const {
    return current_min_speed;
}

void VehicleData::set_current_min_speed(int p_min) {
    current_min_speed = std::clamp(p_min, 0, 200);
}

// 道路箭头实现
Array VehicleData::get_road_arrows() const {
    return road_arrows;
}

void VehicleData::set_road_arrows(const Array &p_arrows) {
    road_arrows = p_arrows;
    emit_road_arrows_changed();
}

// TBT导航实现
String VehicleData::get_tbt_road_name() const {
    return tbt_road_name;
}

void VehicleData::set_tbt_road_name(const String &p_name) {
    tbt_road_name = p_name;
}

int VehicleData::get_tbt_distance() const {
    return tbt_distance_meters;
}

void VehicleData::set_tbt_distance(int p_distance) {
    tbt_distance_meters = std::max(0, p_distance);
}

int VehicleData::get_tbt_direction() const {
    return tbt_direction;
}

void VehicleData::set_tbt_direction(int p_direction) {
    tbt_direction = std::clamp(p_direction, 0, 3);
}

// 导航时间实现
int VehicleData::get_nav_remaining_minutes() const {
    return nav_remaining_minutes;
}

void VehicleData::set_nav_remaining_minutes(int p_minutes) {
    nav_remaining_minutes = std::max(0, p_minutes);
}

int VehicleData::get_nav_remaining_seconds() const {
    return nav_remaining_seconds;
}

void VehicleData::set_nav_remaining_seconds(int p_seconds) {
    nav_remaining_seconds = std::clamp(p_seconds, 0, 59);
}

int VehicleData::get_nav_arrive_hour() const {
    return nav_arrive_hour;
}

void VehicleData::set_nav_arrive_hour(int p_hour) {
    nav_arrive_hour = std::clamp(p_hour, 0, 23);
}

int VehicleData::get_nav_arrive_minute() const {
    return nav_arrive_minute;
}

void VehicleData::set_nav_arrive_minute(int p_minute) {
    nav_arrive_minute = std::clamp(p_minute, 0, 59);
}

void VehicleData::update_nav_time() {
    // 更新导航剩余时间
    nav_remaining_seconds--;
    if (nav_remaining_seconds < 0) {
        nav_remaining_seconds = 59;
        nav_remaining_minutes--;
        
        // 当倒计时结束（变成0分0秒后），重新随机一个时间
        if (nav_remaining_minutes < 0) {
            std::uniform_int_distribution<int> min_dist(3, 10);
            std::uniform_int_distribution<int> sec_dist(0, 59);
            nav_remaining_minutes = min_dist(rng);
            nav_remaining_seconds = sec_dist(rng);
        }
    }
    
    // 注意：到达时间不在每秒更新，只在轨迹点事件中更新
    // 这样到达时间会更稳定，不会频繁变化
    
    emit_nav_time_changed();
}

// 轨迹事件模式下的更新
void VehicleData::_update_trajectory_mode(double delta_time) {
    // 在轨迹事件模式下，红绿灯倒计时继续递减
    double countdown = get_traffic_light_countdown();
    ETrafficLightColor color = get_traffic_light_color();
    
    countdown -= delta_time;
    if (countdown <= 0) {
        // 自动切换颜色
        switch (color) {
            case TRAFFIC_RED:
                color = TRAFFIC_GREEN;
                countdown = 25.0;
                break;
            case TRAFFIC_GREEN:
                color = TRAFFIC_YELLOW;
                countdown = 3.0;
                break;
            case TRAFFIC_YELLOW:
                color = TRAFFIC_RED;
                countdown = 20.0;
                break;
        }
    }
    
    traffic_light["color"] = (int)color;
    traffic_light["countdown"] = countdown;
    emit_traffic_light_changed();
    
    // TBT距离逐渐减少（根据车速）
    if (current_speed > 0.5) {
        double speed_mps = current_speed / 3.6; // km/h -> m/s
        double distance_reduction = speed_mps * delta_time;
        
        // 使用成员变量累积距离变化
        tbt_distance_accumulator += distance_reduction;
        
        // 每10米减少一次
        if (tbt_distance_accumulator >= 10.0) {
            int meters_to_reduce = ((int)tbt_distance_accumulator / 10) * 10;
            tbt_distance_meters -= meters_to_reduce;
            tbt_distance_accumulator -= meters_to_reduce;
            
            if (tbt_distance_meters <= 0) {
                // 距离到达0或以下，重新生成一个随机距离继续倒计时
                std::uniform_int_distribution<int> dist(300, 800);
                tbt_distance_meters = dist(rng);
            }
            emit_tbt_changed();
        }
    }
}

// 新增信号发射
void VehicleData::emit_speed_limit_changed() {
    emit_signal("speed_limit_changed", current_speed_limit, current_min_speed);
}

void VehicleData::emit_road_arrows_changed() {
    emit_signal("road_arrows_changed", road_arrows);
}

void VehicleData::emit_tbt_changed() {
    emit_signal("tbt_changed", tbt_road_name, tbt_distance_meters, tbt_direction);
}

void VehicleData::emit_nav_time_changed() {
    emit_signal("nav_time_changed", nav_remaining_minutes, nav_remaining_seconds, nav_arrive_hour, nav_arrive_minute);
}

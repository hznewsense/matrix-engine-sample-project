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

#ifndef VEHICLE_DATA_H
#define VEHICLE_DATA_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <random>

using namespace godot;

class VehicleData : public RefCounted {
    GDCLASS(VehicleData, RefCounted)

public:
    enum ENOAStatus {
        NOA_INACTIVE,
        NOA_ACTIVE,
        NOA_UNAVAILABLE,
    };

    enum ETrafficLightColor {
        TRAFFIC_RED,
        TRAFFIC_YELLOW,
        TRAFFIC_GREEN,
    };

    // 道路箭头方向
    enum ERoadArrowDirection {
        ROAD_ARROW_STRAIGHT = 0,
        ROAD_ARROW_LEFT = 1,
        ROAD_ARROW_RIGHT = 2,
        ROAD_ARROW_UTURN = 3,
    };

private:
    // 车辆状态
    double current_speed;
    double target_speed;
    double acceleration;

    // 模拟参数（可在检查器中配置）
    double random_speed_min = 0.0;      // 随机目标车速最小值 (km/h)
    double random_speed_max = 30.0;     // 随机目标车速最大值 (km/h)
    double accel_rate = 3.0;            // 加速度 (km/h/s)
    double decel_rate = 5.0;            // 减速度 (km/h/s)
    double speed_change_interval = 5.0;  // 速度变化间隔 (秒)

    // NOA相关
    ENOAStatus noa_status;
    String noa_warning;
    double noa_remaining_distance;
    bool noa_lane_change_pending;

    // 红绿灯数据
    Dictionary traffic_light;

    // 导航TBT
    Array navigation_instructions;
    int current_nav_index;

    // 随机数生成器
    std::mt19937 rng;

    // 内部计时器
    double traffic_light_timer;
    double speed_change_timer;

    // 暂停状态
    bool is_paused;
    
    // 是否使用外部设置的目标车速（档位控制模式）
    bool use_external_target_speed;

    // ========== 轨迹事件驱动数据 ==========
    // 轨迹点事件配置：key=点索引, value=事件字典
    Dictionary trajectory_events;
    
    // 当前限速值（由轨迹点事件设置）
    int current_speed_limit;
    
    // 最低限速值
    int current_min_speed;
    
    // 道路箭头方向数组（3个箭头）
    Array road_arrows; // 存储3个ERoadArrowDirection
    
    // TBT导航数据
    String tbt_road_name;
    int tbt_distance_meters;
    int tbt_direction; // ERoadArrowDirection
    
    // 导航时间
    int nav_remaining_minutes;
    int nav_remaining_seconds;
    int nav_arrive_hour;
    int nav_arrive_minute;
    
    // 是否使用轨迹事件模式
    bool use_trajectory_mode;
    
    // TBT距离累积器（用于平滑减少距离）
    double tbt_distance_accumulator;

protected:
    static void _bind_methods();

public:
    VehicleData();
    ~VehicleData();

    // 车速相关
    double get_current_speed() const;
    void set_current_speed(double p_speed);
    double get_target_speed() const;
    void set_target_speed(double p_speed);
    
    // 模拟参数
    double get_random_speed_min() const;
    void set_random_speed_min(double p_value);
    double get_random_speed_max() const;
    void set_random_speed_max(double p_value);
    double get_accel_rate() const;
    void set_accel_rate(double p_value);
    double get_decel_rate() const;
    void set_decel_rate(double p_value);
    double get_speed_change_interval() const;
    void set_speed_change_interval(double p_value);

    // NOA相关
    ENOAStatus get_noa_status() const;
    void set_noa_status(ENOAStatus p_status);
    String get_noa_warning() const;
    void set_noa_warning(const String &p_warning);
    double get_noa_remaining_distance() const;
    void set_noa_remaining_distance(double p_distance);
    bool is_noa_lane_change_pending() const;
    void set_noa_lane_change_pending(bool p_pending);

    // 红绿灯相关
    Dictionary get_traffic_light() const;
    void set_traffic_light(const Dictionary &p_light);
    int get_traffic_light_id() const;
    ETrafficLightColor get_traffic_light_color() const;
    double get_traffic_light_countdown() const;
    double get_traffic_light_distance() const;

    // 导航相关
    Array get_navigation_instructions() const;
    void set_navigation_instructions(const Array &p_instructions);
    int get_current_nav_index() const;
    void set_current_nav_index(int p_index);
    Dictionary get_current_navigation() const;

    // 模拟更新
    void update_simulation(double delta_time);

    // 模拟控制
    void reset();
    void pause();
    void resume();
    bool get_is_paused() const;
    void reset_external_target_speed();
    void reset_speed_timer();

    // ========== 轨迹事件模式 ==========
    // 设置/获取轨迹事件配置
    void set_trajectory_events(const Dictionary &p_events);
    Dictionary get_trajectory_events() const;
    
    // 启用/禁用轨迹事件模式
    void set_use_trajectory_mode(bool p_use);
    bool get_use_trajectory_mode() const;
    
    // 当通过轨迹点时调用（由VehicleDataController调用）
    void on_trajectory_point_passed(int point_index);
    
    // 限速相关
    int get_current_speed_limit() const;
    void set_current_speed_limit(int p_limit);
    int get_current_min_speed() const;
    void set_current_min_speed(int p_min);
    
    // 道路箭头相关
    Array get_road_arrows() const;
    void set_road_arrows(const Array &p_arrows);
    
    // TBT导航相关
    String get_tbt_road_name() const;
    void set_tbt_road_name(const String &p_name);
    int get_tbt_distance() const;
    void set_tbt_distance(int p_distance);
    int get_tbt_direction() const;
    void set_tbt_direction(int p_direction);
    
    // 导航时间相关
    int get_nav_remaining_minutes() const;
    void set_nav_remaining_minutes(int p_minutes);
    int get_nav_remaining_seconds() const;
    void set_nav_remaining_seconds(int p_seconds);
    int get_nav_arrive_hour() const;
    void set_nav_arrive_hour(int p_hour);
    int get_nav_arrive_minute() const;
    void set_nav_arrive_minute(int p_minute);
    
    // 导航时间更新（每秒调用）
    void update_nav_time();

    // 信号
    void emit_speed_changed();
    void emit_noa_status_changed();
    void emit_traffic_light_changed();
    void emit_navigation_changed();
    
    // 新增信号发射
    void emit_speed_limit_changed();
    void emit_road_arrows_changed();
    void emit_tbt_changed();
    void emit_nav_time_changed();

private:
    void _update_speed_simulation(double delta_time);
    void _update_noa_simulation(double delta_time);
    void _update_traffic_light_simulation(double delta_time);
    void _update_navigation_simulation(double delta_time);
    void _generate_random_navigation();
    
    // 轨迹事件模式下的更新
    void _update_trajectory_mode(double delta_time);
};

VARIANT_ENUM_CAST(VehicleData::ENOAStatus);
VARIANT_ENUM_CAST(VehicleData::ETrafficLightColor);
VARIANT_ENUM_CAST(VehicleData::ERoadArrowDirection);

#endif // VEHICLE_DATA_H

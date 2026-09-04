/* godot-cpp integration testing project.
 *
 * This is free and unencumbered software released into the public domain.
 */

#include "register_types.h"


#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

#include "Simulation/VehicleData.h"
#include "Simulation/CurveMover3D.h"
#include "SelfVehicle/DoorController.h"
#include "SelfVehicle/LampController.h"

using namespace godot;

void initialize_MESample_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}

    GDREGISTER_CLASS(VehicleData);
    GDREGISTER_RUNTIME_CLASS(CurveMover3D);
    GDREGISTER_RUNTIME_CLASS(DoorController);
    GDREGISTER_RUNTIME_CLASS(LampController);
}

void uninitialize_MESample_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
        }

}

extern "C" {
GDExtensionBool GDE_EXPORT
MESample_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,GDExtensionClassLibraryPtr p_library,	GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library,r_initialization);

	init_obj.register_initializer(initialize_MESample_module);
	init_obj.register_terminator(uninitialize_MESample_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);

	return init_obj.init();
}
}

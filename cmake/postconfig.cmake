# Save the current directory for later use
set(GD_POSTCONFIG_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")
set(GD_POSTCONFIG_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/gd_postconfig" CACHE INTERNAL "")

if(NOT IS_SUBPROJECT)
	# Get the platform info
	include("${GD_POSTCONFIG_DIR}/platform_info.cmake")
endif()

set(GD_EXT_Android ".so")
set(GD_EXT_HTML5 ".wasm")
set(GD_EXT_Haiku ".so")
set(GD_EXT_OSX ".dylib")
set(GD_EXT_UWP ".dll")
set(GD_EXT_Windows ".dll")
set(GD_EXT_X11 ".so")
set(GD_EXT_iOS ".framework" ".xcframework" ".a" ".dylib")

# This function handles setting up and installing the actual nativelib resource file for the compiled binary.
# It also dynamically detects what libraries are already installed and adds them to the list, so multiple archs can be installed.
function(install_gdnlib)
	set(GD_OPTIONS 
		"EXCLUDE_FROM_ALL" # Exclude this library from the default installation
	)
	set(GD_VALUE
		"NAME" # The name the library will be given in Godot
		"TARGET" # The target being installed as a library, must be a SHARED library linked to godot::cpp
		"DESTINATION"  # The relative install location for the library (relative to INSTALL_PREFIX)
		"SYMBOL_PREFIX" # The prefix to add to the symbols in Godot

		"COMPONENT" # Component this library is associated with at installation time, see cmake install for more details.

		"SINGLETON" # The library must be loaded as a singleton
		# Note: Setting this to true makes reloadable implicitly false!

		"LOAD_ONCE" # The library is not allowed to be loaded multiple times simultaneously
		# Note: Setting load_once to false does not play nice with most shared libraries!

		"RELOADABLE" # The library can be reloaded if true
	)
	set(GD_MULTI_VALUE 
		"CLASSES" # list of classes that are begin added by this library
		"DEPENDENCIES" # List of targets or files that are dependencies of this library
		
		"CONFIGURATIONS" # The list of configurations this library will be installed in
		"PERMISSIONS" # File permissions to set for installed files
	)
	cmake_parse_arguments(PARSE_ARGV 0 "GD" 
		"${GD_OPTIONS}"
		"${GD_VALUE}"
		"${GD_MULTI_VALUE}"
	)
	
	### Do all fatal error checking first:
	
	if(DEFINED GD_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "install_gdnlib function received unsupported arguments: ${GD_UNPARSED_ARGUMENTS}")
	endif()

	# Check for required arguments:
	if(NOT DEFINED "GD_TARGET")
		message(FATAL_ERROR "install_gdnlib: Required argument TARGET not found!")
	endif()

	if(NOT DEFINED "GD_DESTINATION")
		message(FATAL_ERROR "install_gdnlib: Required argument DESTINATION not found!")
	endif()

	# Check if target exists
	if(NOT TARGET "${GD_TARGET}")
		message(FATAL_ERROR "install_gdnlib: Target '${GD_TARGET}' cannot be not found!")
	endif()

	# Check if the target is a shared library.
	get_target_property(TARGET_TYPE "${GD_TARGET}" TYPE)
	if(NOT ${TARGET_TYPE} STREQUAL "SHARED_LIBRARY")
		message(FATAL_ERROR "install_gdnlib: Target '${GD_TARGET}' is not a shared library!")
	endif()

	# Fallback to target name if no NAME argument
	if(NOT DEFINED "GD_NAME")
		message(STATUS "install_gdnlib: No NAME argument passed in, defaulting to target name")
		set(GD_NAME "${GD_TARGET}")
	endif()

	# Make sure all classes specified are valid C identifiers
	if(DEFINED GD_CLASSES)
		foreach(CLASS_NAME IN LISTS GD_CLASSES)
			# Check for full match (ie use ^ and $ for start and end)
			if(NOT "${CLASS_NAME}" MATCHES "^[A-Za-z_][A-Za-z0-9_]*$")
				message(FATAL_ERROR "install_gdnlib: The class name '${CLASS_NAME}' is not a valid C identifier!")
			endif()
		endforeach()
		unset(CLASS_NAME)
	endif()

	# Set singleton to default value (false)
	if(NOT DEFINED GD_SINGLETON)
		set(GD_SINGLETON "FALSE")
	endif()
	if(GD_SINGLETON)
		set(GD_IS_SINGLETON "true")
	else()
		set(GD_IS_SINGLETON "false")
	endif()

	# Set load_once to default value (true)
	if(NOT DEFINED GD_LOAD_ONCE)
		set(GD_LOAD_ONCE "TRUE")
	endif()
	if(GD_LOAD_ONCE)
		set(GD_IS_LOAD_ONCE "true")
	else()
		set(GD_IS_LOAD_ONCE "false")
	endif()

	# Set reloadable to default value (true)
	if(NOT DEFINED GD_RELOADABLE)
		set(GD_RELOADABLE "TRUE")
	endif()
	if(GD_RELOADABLE)
		if(GD_SINGLETON)
			message(FATAL_ERROR "install_gdnlib: Setting RELOADABLE and SINGLETON is not allowed!")
		endif()
		set(GD_IS_RELOADABLE "true")
	else()
		set(GD_IS_RELOADABLE "false")
	endif()

	# Set the symbol prefix default value (godot_)
	if(NOT DEFINED GD_SYMBOL_PREFIX)
		set(GD_SYMBOL_PREFIX "godot_")
	endif()

	# Prepare the component argument to be forwarded
	if(DEFINED GD_COMPONENT)
		set(GD_ARG_COMPONENT "COMPONENT" ${GD_COMPONENT})
	endif()
	
	# Prepare the configurations argument to be forwarded
	if(DEFINED GD_CONFIGURATIONS)
		set(GD_ARG_CONFIGURATIONS "CONFIGURATIONS" ${GD_CONFIGURATIONS})
	endif()

	# Prepare the permissions argument to be forwarded
	if(DEFINED GD_PERMISSIONS)
		set(GD_ARG_PERMISSIONS "PERMISSIONS" ${GD_PERMISSIONS})
	endif()

	# Prepare the exclude from all argument to be forwarded
	if(GD_EXCLUDE_FROM_ALL)
		set(GD_ARG_EXCLUDE_FROM_ALL "EXCLUDE_FROM_ALL")
	else()
		set(GD_ARG_EXCLUDE_FROM_ALL)
	endif()

	# Install the binaries, on windows this will also install unnecessary static components (IMPLIB).
	install(TARGETS "${GD_TARGET}"
		DESTINATION "${GD_DESTINATION}/${GD_PLATFORM_NAME}/${GD_PLATFORM_ARCH}"

		# Forward all the arguments, if not defined they expand to nothing. DONT put quotes around them.
		${GD_ARG_PERMISSIONS}
		${GD_ARG_CONFIGURATIONS}
		${GD_ARG_COMPONENT}
		${GD_ARG_EXCLUDE_FROM_ALL}
	)

	# Prepare a directory to put our temporary files into without conflicting with any other install_gdnlib installations
	set(GD_CURRENT_BINARY_DIR "${GD_POSTCONFIG_BINARY_DIR}/${GD_NAME}")

	# Prepare the install script
	configure_file(
		"${GD_POSTCONFIG_DIR}/update_gdnlib.cmake"
		"${GD_CURRENT_BINARY_DIR}/update_gdnlib.cmake"
		@ONLY
	)

	# Build a list of dependencies at install time, to check to see if the full list is handled.
	
	if(DEFINED GD_DEPENDENCIES)
		# Check each dependency to see if its a proper target or library file, then add it to a list for installation.
		foreach(GD_DEP IN LISTS GD_DEPENDENCIES)
			if(TARGET "${GD_DEP}")
				# Check if the target is a shared library.
				get_target_property(TARGET_TYPE ${GD_DEP} TYPE)
				if(NOT ${TARGET_TYPE} STREQUAL "SHARED_LIBRARY")
					continue()
				endif()

				list(APPEND GD_DEPENDENCY_FILES "$<TARGET_FILE:${GD_DEP}>")
			elseif(EXISTS "${GD_DEP}")
				get_filename_component(GD_DEP_EXT "${GD_DEP}" LAST_EXT)
				string(TOLOWER "${GD_DEP_EXT}" GD_DEP_EXT)

				# If the file has a valid extension for this platform, we can install it.
				if("${GD_DEP_EXT}" IN_LIST "GD_EXT_${GD_PLATFORM_NAME}")
					list(APPEND GD_DEPENDENCY_FILES "${GD_DEP}")
				else()
					message(FATAL_ERROR "install_gdnlib: The library file '${GD_DEP}' has an incorrect file extension for the platform '${GD_PLATFORM_NAME}'!")
				endif()
			else()
				message(FATAL_ERROR "install_gdnlib: Failed to find a target or library file '${GD_DEP}'!")
			endif()
		endforeach()

		file(GENERATE
			OUTPUT "${GD_CURRENT_BINARY_DIR}/gdnlib_target_files_$<CONFIG>.cmake"
			CONTENT 
			"set(GD_DEPENDENCY_FILES ${GD_DEPENDENCY_FILES})\nset(GD_TARGET_FILE \"$<TARGET_FILE:${GD_TARGET}>\")\n"
		)
	else()
		# Just automatically find the deps
		file(GENERATE
			OUTPUT "${GD_CURRENT_BINARY_DIR}/gdnlib_target_files_$<CONFIG>.cmake"
			CONTENT 
			"set(GD_DEPENDENCY_FILES \"$<TARGET_RUNTIME_DLLS:${GD_TARGET}\")\nset(GD_TARGET_FILE \"$<TARGET_FILE:${GD_TARGET}>\")\n"
		)
	endif()

	# Changed this because its the only way to know what the configuration type is at install time.
	install(CODE "set(GD_INSTALL_CONFIG $<CONFIG>)\ninclude(${GD_CURRENT_BINARY_DIR}/update_gdnlib.cmake)"
		${GD_ARG_COMPONENT}
		${GD_ARG_EXCLUDE_FROM_ALL}
	)
endfunction()

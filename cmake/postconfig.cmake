# Save the current directory for later use
set(GD_CMAKE_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")
set(GD_POSTCONFIG_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/gd_postconfig" CACHE INTERNAL "")

if(NOT IS_SUBPROJECT)
	# Get the platform info
	include("${GD_CMAKE_DIR}/platform_info.cmake")
endif()

set(GD_EXT_Android ".so")
set(GD_EXT_HTML5 ".wasm")
set(GD_EXT_Haiku ".so")
set(GD_EXT_OSX ".dylib")
set(GD_EXT_UWP ".dll")
set(GD_EXT_Windows ".dll")
set(GD_EXT_X11 ".so")
set(GD_EXT_iOS ".framework" ".xcframework" ".a" ".dylib")

# This function handles setting up and installing the actual gdextension configuration file, necessary for godot to use our lib.
# It checks for an already installed .gdextension file, and updates it to include the new configuration without overwritting the old.
# This allows for installing multiple different architectures to the same project directory.
function(install_gdextension)
	set(GD_OPTIONS 
		"EXCLUDE_FROM_ALL" # Exclude this library from the default installation
	)
	set(GD_VALUE
		#CMake specific
		"NAME" # The name the library will be given in Godot
		"TARGET" # The target being installed as a library, must be a SHARED library linked to godot::cpp
		"DESTINATION"  # The relative install location for the library (relative to INSTALL_PREFIX)

		"COMPONENT" # Component this library is associated with at installation time, see cmake install for more details.

		# Godot specific
		"ENTRY_SYMBOL" # The name of the entry symbol in the binary, used to initialize the extension
	)
	set(GD_MULTI_VALUE 
		# Dependencies may not be allowed anymore, or they may need to be put directly into the install location to be loaded, TBD
		# "DEPENDENCIES" # List of targets or files that are dependencies of this library
		
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
		message(FATAL_ERROR "install_gdextension function received unsupported arguments: ${GD_UNPARSED_ARGUMENTS}")
	endif()

	# Check for required arguments:
	if(NOT DEFINED "GD_TARGET")
		message(FATAL_ERROR "install_gdextension: Required argument TARGET not found!")
	endif()

	if(NOT DEFINED "GD_DESTINATION")
		message(FATAL_ERROR "install_gdextension: Required argument DESTINATION not found!")
	endif()

	if(NOT DEFINED "GD_ENTRY_SYMBOL")
		message(FATAL_ERROR "install_gdextension: Required argument ENTRY_SYMBOL not found!")
	endif()

	# Check if target exists
	if(NOT TARGET "${GD_TARGET}")
		message(FATAL_ERROR "install_gdextension: Target '${GD_TARGET}' cannot be not found!")
	endif()

	# Allow static linkage on ios, because apple
	if(NOT "$CACHE{GD_PLATFORM_NAME}" STREQUAL "ios")
		# Check if the target is a shared library.
		get_target_property(TARGET_TYPE "${GD_TARGET}" TYPE)
		if(NOT ${TARGET_TYPE} STREQUAL "SHARED_LIBRARY")
			message(FATAL_ERROR "install_gdextension: Target '${GD_TARGET}' is not a shared library!")
		endif()
	endif()

	# Fallback to target name if no NAME argument
	if(NOT DEFINED "GD_NAME")
		message(STATUS "install_gdextension: No NAME argument passed in, defaulting to target name")
		set(GD_NAME "${GD_TARGET}")
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

	# Prepare a directory to put our temporary files into without conflicting with any other install_gdextension installations
	set(GD_CURRENT_BINARY_DIR "${GD_POSTCONFIG_BINARY_DIR}/${GD_NAME}")

	# Prepare the install script
	configure_file(
		"${GD_CMAKE_DIR}/update_gdextension.cmake"
		"${GD_CURRENT_BINARY_DIR}/update_gdextension.cmake"
		@ONLY
	)
	
	# Note that the OUTPUT filename has a generator expression for config, this is required for multiconfig generators
	file(GENERATE
		OUTPUT "${GD_CURRENT_BINARY_DIR}/gdnlib_target_files_$<CONFIG>.cmake"
		CONTENT 
		"set(GD_DEPENDENCY_FILES ${GD_DEPENDENCY_FILES})\nset(GD_TARGET_FILE \"$<TARGET_FILE:${GD_TARGET}>\")\n"
	)
	
	install(SCRIPT "${GD_CURRENT_BINARY_DIR}/update_gdextension.cmake"
		${GD_ARG_COMPONENT}
		${GD_ARG_EXCLUDE_FROM_ALL}
	)
endfunction()

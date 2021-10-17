cmake_minimum_required(VERSION 3.16)

set(GD_CONFIGURATIONS @GD_CONFIGURATIONS@)

# Avoid installing when the config is not in the whitelist, we check here instead of in postconfig to support multi-config generators
if(NOT DEFINED GD_CONFIGURATIONS OR "${GD_INSTALL_CONFIG}" IN_LIST "GD_CONFIGURATIONS")
	set(GD_CURRENT_BINARY_DIR "@GD_CURRENT_BINARY_DIR@")
	set(GD_POSTCONFIG_DIR "@GD_POSTCONFIG_DIR@")

	set(GD_PLATFORM_NAME "@GD_PLATFORM_NAME@")
	set(GD_PLATFORM_ARCH "@GD_PLATFORM_ARCH@")

	# The name of the gdnative library itself
	set(GD_NAME "@GD_NAME@")

	# The desired destination to install the gdnlib, may be relative or absolute.
	set(GD_DESTINATION "@GD_DESTINATION@")

	# Always compute the absolute directory at install time, not before.
	# This allows the user to change the install prefix without reconfiguring the entire project.
	if(IS_ABSOLUTE "${GD_DESTINATION}")
		set(GD_ABSOLUTE_DIR "${GD_DESTINATION}")
	else()
		# Trim any trailing backslash or forward slash
		string(REGEX REPLACE "[\\\\\\/]+$" "" "GD_DESTINATION" "${GD_DESTINATION}")
		
		set(GD_ABSOLUTE_DIR "${CMAKE_INSTALL_PREFIX}/${GD_DESTINATION}")
	endif()

	set(GD_IS_SINGLETON "@GD_IS_SINGLETON@")
	set(GD_IS_LOAD_ONCE "@GD_IS_LOAD_ONCE@")
	set(GD_IS_RELOADABLE "@GD_IS_RELOADABLE@")
	set(GD_SYMBOL_PREFIX "@GD_SYMBOL_PREFIX@")

	set(GD_CLASSES @GD_CLASSES@)
	set(GD_PERMISSIONS @GD_PERMISSIONS@)

	# Convert a CamelCase name to snake_case
	function(to_snake_case VALUE OUTPUT_VARIABLE)
		string(REGEX REPLACE "([A-Z]+)" "_\\1" UNDERSCORED "${VALUE}")
		string(TOLOWER "${UNDERSCORED}" LOWERCASE)
		
		string(LENGTH "${LOWERCASE}" LC_LENGTH)
		string(FIND "${LOWERCASE}" "_" LC_FIRST_UNDERSCORE)
		if(LC_FIRST_UNDERSCORE EQUAL 0)
			string(SUBSTRING "${LOWERCASE}" 1 ${LC_LENGTH} LOWERCASE)
		endif()
		
		set("${OUTPUT_VARIABLE}" "${LOWERCASE}" PARENT_SCOPE)
	endfunction()


	if(DEFINED GD_PERMISSIONS)
		set(GD_ARG_PERMISSIONS "FILE_PERMISSIONS" ${GD_PERMISSIONS})
	endif()

	# Defines GD_DEPENDENCY_FILES and GD_TARGET_FILE
	include("${GD_CURRENT_BINARY_DIR}/gdnlib_target_files_${GD_INSTALL_CONFIG}.cmake")

	# find the project root directory
	set(GD_PROJECT_DIR "${GD_ABSOLUTE_DIR}")
	while(NOT EXISTS "${GD_PROJECT_DIR}/project.godot")
		get_filename_component(PARENT_DIR "${GD_PROJECT_DIR}/.." ABSOLUTE)

		if("${GD_PROJECT_DIR}" STREQUAL "${PARENT_DIR}")
			message(FATAL_ERROR "DESTINATION passed into 'install_gdnlib' is not within a Godot project directory!")
		endif()

		set(GD_PROJECT_DIR ${PARENT_DIR})
	endwhile()
	unset(PARENT_DIR)

	# Get the relative install destination (Relative to the project root directory)
	file(RELATIVE_PATH 
		GD_PROJECT_RELATIVE_DIR 
		"${GD_PROJECT_DIR}"
		"${GD_ABSOLUTE_DIR}"
	)

	# Install all the classes specified
	list(LENGTH GD_CLASSES GD_NUM_CLASSES)
	if(GD_NUM_CLASSES GREATER 0)
		set(GDNLIB_PATH "res://${GD_PROJECT_RELATIVE_DIR}/${GD_NAME}.gdnlib")
		set(CLASS_INSTALL_LIST "")

		foreach(GD_CLASS_NAME IN LISTS GD_CLASSES)
			to_snake_case("${GD_CLASS_NAME}" GD_RESOURCE_NAME)
			configure_file("${GD_POSTCONFIG_DIR}/nativescript.gdns.in" "${GD_CURRENT_BINARY_DIR}/${GD_RESOURCE_NAME}.gdns")
			list(APPEND CLASS_INSTALL_LIST "${GD_CURRENT_BINARY_DIR}/${GD_RESOURCE_NAME}.gdns")
		endforeach()

		file(INSTALL ${CLASS_INSTALL_LIST}
			DESTINATION "${GD_ABSOLUTE_DIR}"
			${GD_ARG_PERMISSIONS}
		)
	endif()

	# Install the dependencies
	if(DEFINED GD_DEPENDENCY_FILES)
		file(COPY ${GD_DEPENDENCY_FILES}
			DESTINATION "${GD_ABSOLUTE_DIR}/${GD_PLATFORM_NAME}/${GD_PLATFORM_ARCH}"
			${GD_ARG_PERMISSIONS}
		)
	endif()

	# Load the configuration into a string
	if(NOT EXISTS "${GD_ABSOLUTE_DIR}/${GD_NAME}.gdnlib")
		# The default template
		file(READ "${GD_POSTCONFIG_DIR}/nativelib.gdnlib" GDNLIB_CONFIG)
	else()
		# A pre-existing nativelib file
		file(READ "${GD_ABSOLUTE_DIR}/${GD_NAME}.gdnlib" GDNLIB_CONFIG)
	endif()

	# Replace singleton, load_once, reloadable and symbol_prefix
	string(REGEX REPLACE 
		"singleton=[^\n]*" 
		"singleton=\${GD_IS_SINGLETON}"
		GDNLIB_CONFIG 
		"${GDNLIB_CONFIG}"
	)
	string(REGEX REPLACE 
		"load_once=[^\n]*" 
		"load_once=\${GD_IS_LOAD_ONCE}"
		GDNLIB_CONFIG 
		"${GDNLIB_CONFIG}"
	)
	string(REGEX REPLACE 
		"reloadable=[^\n]*" 
		"reloadable=\${GD_IS_RELOADABLE}"
		GDNLIB_CONFIG 
		"${GDNLIB_CONFIG}"
	)
	string(REGEX REPLACE 
		"symbol_prefix=[^\n]*" 
		"symbol_prefix=\"\${GD_SYMBOL_PREFIX}\""
		GDNLIB_CONFIG
		"${GDNLIB_CONFIG}"
	)


	# Calculate the main entry for this target
	get_filename_component(GD_TARGET_FILE_NAME "${GD_TARGET_FILE}" NAME)
	set(GD_TARGET_ENTRY "res://${GD_PROJECT_RELATIVE_DIR}/${GD_PLATFORM_NAME}/${GD_PLATFORM_ARCH}/${GD_TARGET_FILE_NAME}")

	# Replace the entry in the config file
	string(REGEX REPLACE 
		"${GD_PLATFORM_NAME}\\.${GD_PLATFORM_ARCH}=\"[^\n]*" 
		"${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}=\"\${GD_TARGET_ENTRY}\""
		GDNLIB_CONFIG
		"${GDNLIB_CONFIG}"
	)

	# Calculate the list of dependencies for this target
	foreach(DEP_FILE IN LISTS GD_DEPENDENCY_FILES)
		get_filename_component(GD_DEP_FILE_NAME "${DEP_FILE}" NAME)
		set(GD_DEP_ENTRY "res://${GD_PROJECT_RELATIVE_DIR}/${GD_PLATFORM_NAME}/${GD_PLATFORM_ARCH}/${GD_DEP_FILE_NAME}")
		list(APPEND GD_DEP_ENTRIES "\"${GD_DEP_ENTRY}\"")
	endforeach()
	string(REPLACE ";" ", " GD_DEP_ENTRIES "${GD_DEP_ENTRIES}")

	# Replace the deps entry in the config file
	string(REGEX REPLACE
		"${GD_PLATFORM_NAME}\\.${GD_PLATFORM_ARCH}=\\[[^\n]*"
		"${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}=[\${GD_DEP_ENTRIES}]"
		GDNLIB_CONFIG
		"${GDNLIB_CONFIG}"
	)

	file(WRITE "${GD_CURRENT_BINARY_DIR}/${GD_NAME}.gdnlib.in" "${GDNLIB_CONFIG}")
	configure_file("${GD_CURRENT_BINARY_DIR}/${GD_NAME}.gdnlib.in" "${GD_CURRENT_BINARY_DIR}/${GD_NAME}.gdnlib")

	file(INSTALL "${GD_CURRENT_BINARY_DIR}/${GD_NAME}.gdnlib"
		DESTINATION "${GD_ABSOLUTE_DIR}"
		${GD_ARG_PERMISSIONS}
	)
endif()
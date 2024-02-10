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

	# Install the dependencies
	if(DEFINED GD_DEPENDENCY_FILES)
		file(COPY ${GD_DEPENDENCY_FILES}
			DESTINATION "${GD_ABSOLUTE_DIR}/${GD_PLATFORM_NAME}/${GD_PLATFORM_ARCH}"
			${GD_ARG_PERMISSIONS}
		)
	endif()

	# Load the configuration into a string
	if(NOT EXISTS "${GD_ABSOLUTE_DIR}/${GD_NAME}.gdextension")
		# The default template
		file(READ "${GD_POSTCONFIG_DIR}/extension_template.gdextension" GDNLIB_CONFIG)
	else()
		# A pre-existing nativelib file
		file(READ "${GD_ABSOLUTE_DIR}/${GD_NAME}.gdextension" GDNLIB_CONFIG)
	endif()

	# Calculate the main entry for this target
	get_filename_component(GD_TARGET_FILE_NAME "${GD_TARGET_FILE}" NAME)
	set(GD_TARGET_ENTRY "res://${GD_PROJECT_RELATIVE_DIR}/${GD_PLATFORM_NAME}/${GD_TARGET_FILE_NAME}")
	set(GD_TARGET_ENTRY_KEY "${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}")

	# Remove all preexisting entries
	string(REGEX REPLACE
		"${GD_TARGET_ENTRY_KEY}=\"[^\\\"]*\"\\s*"
		""
		GDNLIB_CONFIG
		"${GDNLIB_CONFIG}"
	)
	
	# Add the extry to it
	string(REGEX REPLACE 
		"\\[libraries\\]\s+" 
		"[libraries]\n${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}=\"\${GD_TARGET_ENTRY}\""
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

	# Remove any preexisting entries
	string(REGEX REPLACE
		"${GD_TARGET_ENTRY_KEY}=\\[[^\\]]*\\]\\s*"
		""
		GDNLIB_CONFIG
		"${GDNLIB_CONFIG}"
	)

	# Replace the deps entry in the config file
	string(REGEX REPLACE
		"\\[dependencies\\]\s+" 
		"[dependencies]\n${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}=[\${GD_DEP_ENTRIES}]"
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
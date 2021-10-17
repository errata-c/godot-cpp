cmake_minimum_required(VERSION 3.16)

set(GD_CONFIGURATIONS @GD_CONFIGURATIONS@)

# Avoid installing when the config is not in the whitelist, we check here instead of in postconfig to support multi-config generators
if(NOT DEFINED GD_CONFIGURATIONS OR "${GD_INSTALL_CONFIG}" IN_LIST "GD_CONFIGURATIONS")
	set(GD_CURRENT_BINARY_DIR "@GD_CURRENT_BINARY_DIR@")
	set(GD_CMAKE_DIR "@GD_CMAKE_DIR@")

	set(GD_PLATFORM_NAME "@GD_PLATFORM_NAME@")
	set(GD_PLATFORM_ARCH "@GD_PLATFORM_ARCH@")
	string(TOLOWER "${GD_INSTALL_CONFIG}" GD_PLATFORM_CONFIG)

	set(GD_NAME "@GD_NAME@")
	set(GD_DESTINATION "@GD_DESTINATION@")
	set(GD_ENTRY_SYMBOL "@GD_ENTRY_SYMBOL@")

	set(GD_PERMISSIONS @GD_PERMISSIONS@)

	# Always compute the absolute directory at install time, not before.
	# This allows the user to change the install prefix without reconfiguring the entire project.
	if(IS_ABSOLUTE "${GD_DESTINATION}")
		set(GD_ABSOLUTE_DIR "${GD_DESTINATION}")
	else()
		# Trim any trailing backslash or forward slash
		string(REGEX REPLACE "[\\\\\\/]+$" "" "GD_DESTINATION" "${GD_DESTINATION}")
		
		set(GD_ABSOLUTE_DIR "${CMAKE_INSTALL_PREFIX}/${GD_DESTINATION}")
	endif()

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
			message(FATAL_ERROR "DESTINATION passed into 'install_gdextension' is not within a Godot project directory!")
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

	# Load the configuration into a string
	if(NOT EXISTS "${GD_ABSOLUTE_DIR}/${GD_NAME}.gdextension")
		# The default template
		file(READ "${GD_CMAKE_DIR}/template.gdextension" GDEXTENSION_CONFIG)
		
		string(REGEX REPLACE 
		"entry_symbol=[^\n]*" 
		"entry_symbol=\"\${GD_ENTRY_SYMBOL}\""
		GDEXTENSION_CONFIG
		"${GDEXTENSION_CONFIG}"
	)
	else()
		# A pre-existing nativelib file
		file(READ "${GD_ABSOLUTE_DIR}/${GD_NAME}.gdextension" GDEXTENSION_CONFIG)
	endif()

	if("${GDEXTENSION_CONFIG}" MATCHES "entry_symbol=([^\n]*)")
		if(NOT "${CMAKE_MATCH_0}" STREQUAL "${GD_ENTRY_SYMBOL}")
			message(FATAL_ERROR 
				"The entry_symbol in ${GD_NAME}.gdextension has changed!\n
				"The extension must be removed and reinstalled."
			)
		endif()
	else()
		message(FATAL_ERROR "Misconfiguration! The gdextension configuration file does not contain an entry_symbol key-value pair!")
	endif()

	# libraries are added like so: platform.arch.config="path_to_binary"

	# Generate the key-value pair to add to the configuration
	get_filename_component(GD_TARGET_FILE_NAME "${GD_TARGET_FILE}" NAME)
	set(GD_TARGET_KEY "${GD_PLATFORM_NAME}\\.${GD_PLATFORM_ARCH}\\.${GD_PLATFORM_CONFIG}")
	set(GD_TARGET_VALUE "res://${GD_PROJECT_RELATIVE_DIR}/${GD_PLATFORM_NAME}/${GD_PLATFORM_ARCH}/${GD_PLATFORM_CONFIG}/${GD_TARGET_FILE_NAME}")
	
	if("${GDEXTENSION_CONFIG}" MATCHES "${GD_TARGET_KEY}=[^\n]*")
		# Replace the entry in the config file
		string(REGEX REPLACE 
			"${GD_PLATFORM_NAME}\\.${GD_PLATFORM_ARCH}=\"[^\n]*" 
			"${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}=\"\${GD_TARGET_ENTRY}\""
			GDEXTENSION_CONFIG
			"${GDEXTENSION_CONFIG}"
		)
	else()
		# Append the entry to the config
		string(APPEND GDEXTENSION_CONFIG "${GD_TARGET_KEY}=\"${GD_TARGET_ENTRY}\"")
	endif()
	
	# Write the file to tmp directory
	file(WRITE "${GD_CURRENT_BINARY_DIR}/${GD_NAME}.gdextension" "${GDEXTENSION_CONFIG}")
	
	# finally install it, overwritting the old one (if there was an old one)
	file(INSTALL "${GD_CURRENT_BINARY_DIR}/${GD_NAME}.gdextension"
		DESTINATION "${GD_ABSOLUTE_DIR}"
		${GD_ARG_PERMISSIONS}
	)
endif()
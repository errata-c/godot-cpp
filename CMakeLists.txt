# cmake arguments
# CMAKE_BUILD_TYPE:			Compilation target (Debug or Release defaults to Debug)
#
# godot-cpp cmake arguments
# GODOT_HEADERS_DIR:		This is where the gdnative include folder is (godot_source/modules/gdnative/include)
# GODOT_CUSTOM_API_FILE:	This is if you have another path for the godot_api.json
#
# Android cmake arguments
# CMAKE_TOOLCHAIN_FILE:		The path to the android cmake toolchain ($ANDROID_NDK/build/cmake/android.toolchain.cmake)
# ANDROID_NDK:				The path to the android ndk root folder
# ANDROID_TOOLCHAIN_NAME:	The android toolchain (arm-linux-androideabi-4.9 or aarch64-linux-android-4.9 or x86-4.9 or x86_64-4.9)
# ANDROID_PLATFORM:			The android platform version (android-23)
# More info here: https://godot.readthedocs.io/en/latest/development/compiling/compiling_for_android.html
#
# Examples
#
# Builds a debug version:
# cmake .
# cmake --build .
#
# Builds a release version with clang
# CC=/usr/bin/clang CXX=/usr/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -G "Unix Makefiles" .
# cmake --build .
#
# Builds an android armeabi-v7a debug version:
# cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DANDROID_NDK=$ANDROID_NDK \
#		-DANDROID_TOOLCHAIN_NAME=arm-linux-androideabi-4.9 -DANDROID_PLATFORM=android-23 -DCMAKE_BUILD_TYPE=Debug .
# cmake --build .
#
# Protip
# Generate the buildfiles in a sub directory to not clutter the root directory with build files:
# mkdir build && cd build && cmake -G "Unix Makefiles" .. && cmake --build .

# Version 3.16 is the newest version supported by Ubuntu
cmake_minimum_required(VERSION 3.16)

project(GODOT_CPP
VERSION 0.2.0
LANGUAGES C CXX)

get_directory_property(IS_SUBPROJECT PARENT_DIRECTORY)

if(NOT IS_SUBPROJECT)
	include(FetchContent)
	
	# This is for installing the project targets
	FetchContent_Declare(
		ez-cmake
		GIT_REPOSITORY "https://github.com/errata-c/ez-cmake.git"
		GIT_TAG "ba4fb8714f815919e90b5905552b3fc41142d847"
	)
	FetchContent_MakeAvailable(ez-cmake)
endif()

option(GODOT_CPP_GENERATE_TEMPLATE_GET_NODE "Generate a template version of the Node class's get_node method." ON)

# The default config directory is one that cmake's find_package function will automatically search for package config files.
set(GODOT_CPP_CONFIG_DIR "share/godot-cpp" CACHE STRING "The relative directory to install godot-cpp package config files.")

# Default build type is Debug in the SConstruct
if("${CMAKE_BUILD_TYPE}" STREQUAL "")
	set(CMAKE_BUILD_TYPE Debug)
endif()

set(GODOT_CPP_HEADERS_DIR "godot-headers" CACHE STRING 
	"Location of the c-api header files, can be changed if you have a different set of headers to use")

set(GODOT_CPP_CUSTOM_API_FILE "godot-headers/api.json" CACHE STRING 
	"Location of the api.json file, describing what to actually generate from the header files")

set(GODOT_COMPILE_FLAGS )
set(GODOT_LINKER_FLAGS )

# Determine what the platform name and architecture is.
# This creates the cache entries GD_PLATFORM_NAME and GD_PLATFORM_ARCH
include("cmake/platform_checks.cmake")

# using Visual Studio C++
if ("${CMAKE_CXX_COMPILER_ID}" MATCHES "^.*MSVC.*$")
	# Treat all warnings as erros
	set(GODOT_COMPILE_FLAGS "/WX") # /GF /MP
	
	# These flags enable msvc to generate a multithreaded dll
	list(APPEND GODOT_COMPILE_FLAGS "$<IF:$<CONFIG:Debug,RelWithDebInfo>,/MDd,/MD>") # /Od /RTC1 /Zi
	
	# Disable conversion warning, trunkation, unreferenced var, signed missmatch
	list(APPEND GODOT_COMPILE_FLAGS "/wd4244" "/wd4305" "/wd4101" "/wd4018" "/wd4267")
else()
	# link to static libgcc and libstdc++
	set(GODOT_LINKER_FLAGS "-static-libgcc" "-static-libstdc++")

	# Hmm.. maybe to strikt?
	list(APPEND GODOT_COMPILE_FLAGS "-Wwrite-strings")
	list(APPEND GODOT_COMPILE_FLAGS "-Wchar-subscripts" "-Wcomment" "-Wdisabled-optimization")
	list(APPEND GODOT_COMPILE_FLAGS "-Wformat" "-Wformat=2" "-Wformat-security" "-Wformat-y2k")
	list(APPEND GODOT_COMPILE_FLAGS "-Wimport" "-Winit-self" "-Winline" "-Winvalid-pch" "-Werror")
	list(APPEND GODOT_COMPILE_FLAGS "-Wmissing-braces" "-Wmissing-format-attribute")
	list(APPEND GODOT_COMPILE_FLAGS "-Wmissing-include-dirs" "-Wmissing-noreturn" "-Wpacked" "-Wpointer-arith")
	list(APPEND GODOT_COMPILE_FLAGS "-Wredundant-decls" "-Wreturn-type" "-Wsequence-point")
	list(APPEND GODOT_COMPILE_FLAGS "-Wswitch" "-Wswitch-enum" "-Wtrigraphs")
	list(APPEND GODOT_COMPILE_FLAGS "-Wuninitialized" "-Wunknown-pragmas" "-Wunreachable-code" "-Wunused-label")
	list(APPEND GODOT_COMPILE_FLAGS "-Wunused-value" "-Wvariadic-macros" "-Wvolatile-register-var" "-Wno-error=attributes")

	# -Wshadow -Wextra -Wall -Weffc++ -Wfloat-equal -Wstack-protector -Wunused-parameter -Wsign-compare -Wunused-variable -Wcast-align
	# -Wunused-function -Wstrict-aliasing -Wstrict-aliasing=2 -Wmissing-field-initializers

	list(APPEND GODOT_COMPILE_FLAGS "$<$<NOT:$<PLATFORM_ID:Android>>:-Wno-ignored-attributes>")
endif()

# Generate source from the bindings file
find_package(Python3 3.4 REQUIRED) # pathlib should be present
if(GENERATE_TEMPLATE_GET_NODE)
	set(GENERATE_BINDING_PARAMETERS "True")
else()
	set(GENERATE_BINDING_PARAMETERS "False")
endif()

if(NOT "$CACHE{GODOT_CPP_BINDINGS_GENERATED}")
	execute_process(COMMAND "${Python_EXECUTABLE}" "-c" "import binding_generator; binding_generator.print_file_list(\"${GODOT_CPP_CUSTOM_API_FILE}\", \"${CMAKE_CURRENT_SOURCE_DIR}\", headers=True)"
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		RESULT_VARIABLE HEADERS_FILE_LIST_RESULT
		OUTPUT_VARIABLE HEADERS_FILE_LIST
		ERROR_VARIABLE HEADERS_ERROR
	)
	set(HEADERS_FILE_LIST ${HEADERS_FILE_LIST})

	if(NOT HEADERS_ERROR STREQUAL "")
		message(FATAL_ERROR "${HEADERS_ERROR}")
	endif()

	execute_process(COMMAND "${Python_EXECUTABLE}" "-c" "import binding_generator; binding_generator.print_file_list(\"${GODOT_CPP_CUSTOM_API_FILE}\", \"${CMAKE_CURRENT_SOURCE_DIR}\", sources=True)"
		WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
		RESULT_VARIABLE SOURCES_FILE_LIST_RESULT
		OUTPUT_VARIABLE SOURCES_FILE_LIST
		ERROR_VARIABLE SOURCES_ERROR
	)
	set(SOURCES_FILE_LIST ${SOURCES_FILE_LIST})

	if(NOT SOURCES_ERROR STREQUAL "")
		message(FATAL_ERROR "${SOURCES_ERROR}")
	endif()

	set(GODOT_CPP_BINDINGS_GENERATED TRUE CACHE INTERNAL "")
	set(GODOT_CPP_HEADERS_FILE_LIST "${HEADERS_FILE_LIST}" CACHE INTERNAL "")
	set(GODOT_CPP_SOURCES_FILE_LIST "${SOURCES_FILE_LIST}" CACHE INTERNAL "")
endif()

add_custom_command(OUTPUT ${GODOT_CPP_HEADERS_FILE_LIST} ${GODOT_CPP_SOURCES_FILE_LIST}
	COMMAND "${Python_EXECUTABLE}" "-c" "import binding_generator; binding_generator.generate_bindings(\"${GODOT_CPP_CUSTOM_API_FILE}\", \"${GENERATE_BINDING_PARAMETERS}\", \"${CMAKE_CURRENT_SOURCE_DIR}\")"
	VERBATIM
	WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
	MAIN_DEPENDENCY "${GODOT_CPP_CUSTOM_API_FILE}"
	DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/binding_generator.py"
	COMMENT "Generating Bindings"
)

# Get Sources
file(GLOB_RECURSE CORE_SOURCES "src/core/*.c**")
file(GLOB_RECURSE CORE_HEADERS "include/core/*.h**")

# Define the godot-cpp library
add_library(godot-cpp STATIC 
	"${CORE_SOURCES}" 
	"${CORE_HEADERS}"

	"${GODOT_CPP_HEADERS_FILE_LIST}"
	"${GODOT_CPP_SOURCES_FILE_LIST}"
)

target_include_directories(godot-cpp
	PUBLIC
	"$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
	"$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/core>"
	"$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include/gen>"
	
	"$<INSTALL_INTERFACE:include>"
	"$<INSTALL_INTERFACE:include/core>"
	"$<INSTALL_INTERFACE:include/gen>"

	"$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/${GODOT_CPP_HEADERS_DIR}>"
)
target_compile_definitions(godot-cpp PUBLIC 
	"$<IF:$<CONFIG:Debug,RelWithDebInfo>,_DEBUG,NDEBUG>" 
	"$<$<PLATFORM_ID:Windows>:WIN32_LEAN_AND_MEAN;_CRT_SECURE_NO_WARNINGS>"
)
target_compile_features(godot-cpp PUBLIC cxx_std_14)
target_compile_options(godot-cpp PUBLIC ${GODOT_COMPILE_FLAGS})
target_link_options(godot-cpp PUBLIC ${GODOT_LINKER_FLAGS})

string(TOLOWER "${GD_PLATFORM_NAME}" "GD_SYSTEM_NAME")

set_target_properties(godot-cpp PROPERTIES
	POSITION_INDEPENDENT_CODE "TRUE"
	EXPORT_NAME "cpp"
	BUILD_RPATH_USE_ORIGIN "TRUE"
	OUTPUT_NAME "godot-cpp.${GD_SYSTEM_NAME}.$<LOWER_CASE:$<CONFIG>>.${GD_PLATFORM_ARCH}"
)

add_library(godot::cpp ALIAS godot-cpp)


if(IS_SUBPROJECT)
	include("cmake/postconfig.cmake")
else()

	# Install all the include files
	install(DIRECTORY "include/" DESTINATION "include" 
		FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
	)

	# Install the generated header files as well
	install(DIRECTORY "${GODOT_CPP_HEADERS_DIR}/" DESTINATION "include"
		FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
	)

	install(TARGETS godot-cpp
		EXPORT godot-cpp-targets
		RUNTIME DESTINATION "bin/$<CONFIG>"
		ARCHIVE DESTINATION "lib/$<CONFIG>"
		LIBRARY DESTINATION "lib/$<CONFIG>"
	)

	# Installs nativelib and nativescript template files, as well as target_info for the package
	install(
	FILES 
		"cmake/nativelib.gdnlib" 
		"cmake/nativescript.gdns.in" 
		"cmake/update_gdnlib.cmake" 
		"${CMAKE_CURRENT_BINARY_DIR}/platform_info.cmake"
	DESTINATION 
		"${GODOT_CPP_CONFIG_DIR}"
	)

	# Install the main package files, this allows the use of find_package(godot-cpp) later
	install_package(
		NAME "godot-cpp"
		NAMESPACE "godot::"
		EXPORT "godot-cpp-targets"
		VERSION "${GODOT_CPP_VERSION}"
		COMPATIBILITY "SameMajorVersion"
		DESTINATION "${GODOT_CPP_CONFIG_DIR}"

		# Postconfig contains the necessary setup for the install_gdlib function, to be used downstream
		POSTCONFIG "${CMAKE_CURRENT_SOURCE_DIR}/cmake/postconfig.cmake"
	)

endif()
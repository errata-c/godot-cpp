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
# 
# Todo
# Test build for Windows, Mac and mingw.

cmake_minimum_required(VERSION 3.19)

project(godot-cpp
VERSION 0.1.0
LANGUAGES C CXX)

option(GENERATE_TEMPLATE_GET_NODE "Generate a template version of the Node class's get_node." ON)

# Default build type is Debug in the SConstruct
if(CMAKE_BUILD_TYPE STREQUAL "")
	set(CMAKE_BUILD_TYPE Debug)
endif()

# Input from user for godot headers and the api file
set(GODOT_HEADERS_DIR "godot-headers" CACHE STRING "")
set(GODOT_CUSTOM_API_FILE "godot-headers/api.json" CACHE STRING "")

set(GODOT_COMPILE_FLAGS )
set(GODOT_LINKER_FLAGS )

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
	# using Visual Studio C++
	set(GODOT_COMPILE_FLAGS "/EHsc /WX") # /GF /MP

	if(CMAKE_BUILD_TYPE MATCHES Debug)
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /MDd") # /Od /RTC1 /Zi
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /MD /O2") # /Oy /GL /Gy
		STRING(REGEX REPLACE "/RTC(su|[1su])" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
		string(REPLACE "/RTC1" "" CMAKE_CXX_FLAGS_DEBUG ${CMAKE_CXX_FLAGS_DEBUG})
	endif()

	# Disable conversion warning, trunkation, unreferenced var, signed missmatch
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} /wd4244 /wd4305 /wd4101 /wd4018 /wd4267")

	# Todo: Check if needed.
	add_definitions(-DWIN32_LEAN_AND_MEAN -D_CRT_SECURE_NO_WARNINGS)

	# Unkomment for warning level 4
	#if(CMAKE_CXX_FLAGS MATCHES "/W[0-4]")
	#	string(REGEX REPLACE "/W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
	#endif()

else()
	set(GODOT_LINKER_FLAGS "-static-libgcc -static-libstdc++ -Wl,-R,'$$ORIGIN'")

	# Hmm.. maybe to strikt?
	set(GODOT_COMPILE_FLAGS "-g -Wwrite-strings")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wchar-subscripts -Wcomment -Wdisabled-optimization")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wformat -Wformat=2 -Wformat-security -Wformat-y2k")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wimport -Winit-self -Winline -Winvalid-pch -Werror")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wmissing-braces -Wmissing-format-attribute")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wmissing-include-dirs -Wmissing-noreturn -Wpacked -Wpointer-arith")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wredundant-decls -Wreturn-type -Wsequence-point")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wswitch -Wswitch-enum -Wtrigraphs")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wuninitialized -Wunknown-pragmas -Wunreachable-code -Wunused-label")
	set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wunused-value -Wvariadic-macros -Wvolatile-register-var -Wno-error=attributes")

	# -Wshadow -Wextra -Wall -Weffc++ -Wfloat-equal -Wstack-protector -Wunused-parameter -Wsign-compare -Wunused-variable -Wcast-align
	# -Wunused-function -Wstrict-aliasing -Wstrict-aliasing=2 -Wmissing-field-initializers

	if(NOT CMAKE_SYSTEM_NAME STREQUAL "Android")
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -Wno-ignored-attributes")
	endif()

	if(CMAKE_BUILD_TYPE MATCHES Debug)
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -fno-omit-frame-pointer -O0")
	else()
		set(GODOT_COMPILE_FLAGS "${GODOT_COMPILE_FLAGS} -O3")
	endif()
endif()

# Generate source from the bindings file
find_package(PythonInterp REQUIRED)
if(GENERATE_TEMPLATE_GET_NODE)
	set(GENERATE_BINDING_PARAMETERS "True")
else()
	set(GENERATE_BINDING_PARAMETERS "False")
endif()

message(STATUS "Generating Bindings")
execute_process(COMMAND "${PYTHON_EXECUTABLE}" "-c" "import binding_generator; binding_generator.generate_bindings(\"${GODOT_CUSTOM_API_FILE}\", ${GENERATE_BINDING_PARAMETERS})"
	WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
	RESULT_VARIABLE GENERATION_RESULT
	OUTPUT_VARIABLE GENERATION_OUTPUT)
message(STATUS ${GENERATION_RESULT} ${GENERATION_OUTPUT})

# Get Sources
file(GLOB_RECURSE SOURCES src/*.c**)
file(GLOB_RECURSE HEADERS include/*.h**)

# Define our godot-cpp library
add_library(godot-cpp SHARED "${SOURCES}" "${HEADERS}")
target_include_directories(godot-cpp
	PUBLIC
	"include"
	"include/core"
	"include/gen"
	
	SYSTEM PUBLIC
	"${GODOT_HEADERS_DIR}"
)
target_compile_definitions(godot-cpp PUBLIC "$<IF:$<Config:Debug>,_DEBUG,NDEBUG>"
target_compile_features(godot-cpp PUBLIC cxx_std_14)

target_compile_options(godot-cpp PUBLIC ${GODOT_COMPILE_FLAGS})
target_link_options(godot-cpp PUBLIC ${GODOT_LINKER_FLAGS})


# Create the correct name (godot.os.build_type.system_bits)

set(BITS 32)
if(CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(BITS 64)
endif(CMAKE_SIZEOF_VOID_P EQUAL 8)

string(TOLOWER ${CMAKE_SYSTEM_NAME} SYSTEM_NAME)
string(TOLOWER ${CMAKE_BUILD_TYPE} BUILD_TYPE)

if(ANDROID)
	# Added the android abi after system name
	set(SYSTEM_NAME ${SYSTEM_NAME}.${ANDROID_ABI})
	# Android does not have the bits at the end if you look at the main godot repo build
	set_property(TARGET godot-cpp PROPERTY OUTPUT_NAME "godot-cpp.${SYSTEM_NAME}.${BUILD_TYPE}")
else()
	set_property(TARGET godot-cpp PROPERTY OUTPUT_NAME "godot-cpp.${SYSTEM_NAME}.${BUILD_TYPE}.${BITS}")
endif()


# Find the host platform bit width.
if(NOT DEFINED GD_PLATFORM_BITS)
	if(NOT DEFINED BITS)
		set(BITS 32)
		if(CMAKE_SIZEOF_VOID_P EQUAL 8)
			set(BITS 64)
		endif()
	endif()
	
	set(GD_PLATFORM_BITS ${BITS})
endif()

# Find the host platform name and architecture
if(NOT DEFINED GD_PLATFORM_NAME OR NOT DEFINED GD_PLATFORM_ARCH)
	
	if(WIN32 AND NOT WINDOWS)
		set(WINDOWS TRUE)
	endif()

	if("${CMAKE_SYSTEM_NAME}" MATCHES ".*Android.*")
		set(ANDROID TRUE)
	endif()

	if (${CMAKE_SYSTEM_NAME} MATCHES ".*Darwin.*")
		set(MACOSX TRUE)
	endif()


	if(WINDOWS)
		set(GD_PLATFORM_NAME "windows")
		set(GD_PLATFORM_ARCH "${GD_PLATFORM_BITS}")
	
	elseif(UNIX AND NOT APPLE)
		set(GD_PLATFORM_NAME "linux")
		set(GD_PLATFORM_ARCH "${GD_PLATFORM_BITS}")

	elseif("${CMAKE_SYSTEM_NAME}" MATCHES "Haiku.*")
		set(GD_PLATFORM_NAME "haiku")
		set(GD_PLATFORM_ARCH "${GD_PLATFORM_BITS}")
	
	# Now the harder platforms...
	elseif(APPLE)
		# For apple the architechure is inside the CMAKE_OSX_ARCHITECTURES variable

		if("${CMAKE_SYSTEM_NAME}" MATCHES ".*MacOS.*")
			if(NOT IS_64BIT)
				message(FATAL_ERROR "Only 64-bit builds are supported for the macOS target!")
			endif()
	
			set(GD_PLATFORM_NAME "OSX")
			set(GD_PLATFORM_ARCH "${GD_PLATFORM_BITS}")
		
		
		elseif("${CMAKE_SYSTEM_NAME}" MATCHES ".*iOS.*")
			set(GD_PLATFORM_NAME "iOS")

			if(CMAKE_OSX_ARCHITECTURES STREQUAL "armv7")
				set(GD_PLATFORM_ARCH "armv7")
			elseif(CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
				set(GD_PLATFORM_ARCH "arm64")
			else()
				message(FATAL_ERROR "Unsupported iOS architecture selected!")
			endif()
		else()
			message(FATAL_ERROR "Unsupported apple system detected! Only Mac OSX and iOS are supported currently.")
		endif()

	elseif(ANDROID)
		set(GD_PLATFORM_NAME "android")
	
		if(NOT DEFINED ANDROID_ABI)
			message(FATAL_ERROR 
				"Compiling for android system, but ANDROID_ABI is undefined! "
				"Cross compiling for android can be done with NVIDIA Nsight Tegra Visual Studio Edition, Visual Studio tools for Android, the NDK, or a standalone toolchain. More information can be found in the cmake-toolchains documentation."
			)
		endif()
	
		if(NOT "${ANDROID_ABI}" MATCHES "armeabi-v7a|arm64-v8a|x86|x86_64")
			message(FATAL_ERROR "Unsupported android abi selected!")
		endif()

		set(GD_PLATFORM_ARCH "${ANDROID_ABI}")
	elseif("${CMAKE_SYSTEM_NAME}" MATCHES ".*Emscripten.*")
		set(GD_PLATFORM_NAME "html5")
		set(GD_PLATFORM_ARCH "wasm32")
	
	elseif("${CMAKE_C_COMPILER_TARGET}" STREQUAL "wasm32" OR "${CMAKE_CXX_COMPILER_TARGET}" STREQUAL "wasm32")
		set(GD_PLATFORM_NAME "html5")
		set(GD_PLATFORM_ARCH "wasm32")
	
	elseif("${CMAKE_C_COMPILER_TARGET}" STREQUAL "wasm64" OR "${CMAKE_CXX_COMPILER_TARGET}" STREQUAL "wasm64")
		message(FATAL_ERROR "wasm64 target is not currently supported!")
	
	else()
		message(FATAL_ERROR "Unsupported OS detected!")
	endif()


	set(GD_PLATFORM "${GD_PLATFORM_NAME}.${GD_PLATFORM_ARCH}")
endif()
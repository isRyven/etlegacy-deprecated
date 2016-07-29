#RENDERER BUILDS

if(NOT APPLE)
	set(R1_NAME renderer_opengl1_${ARCH})
	set(R2_NAME renderer_opengl2_${ARCH})
else()
	set(R1_NAME renderer_opengl1${LIB_SUFFIX})
	set(R2_NAME renderer_opengl2${LIB_SUFFIX})
endif()

if(RENDERER_DYNAMIC)
	MESSAGE("Will build dynamic renderer libraries")
	add_definitions( "-DUSE_RENDERER_DLOPEN" )
	set(REND_LIBTYPE MODULE)
	list(APPEND RENDERER_COMMON ${RENDERER_COMMON_DYNAMIC})
else(RENDERER_DYNAMIC)
	set(REND_LIBTYPE STATIC)
endif(RENDERER_DYNAMIC)
if(RENDERER_DYNAMIC OR NOT FEATURE_RENDERER2)

	if(FEATURE_RENDERER_GLES)
		add_library(${R1_NAME} ${REND_LIBTYPE} ${RENDERERGLES_FILES} ${RENDERER_COMMON})
	else()
		add_library(${R1_NAME} ${REND_LIBTYPE} ${RENDERER1_FILES} ${RENDERER_COMMON})
	endif()

	if(NOT FEATURE_RENDERER_GLES)
		if(BUNDLED_GLEW)
			add_dependencies(${R1_NAME} bundled_glew)
		endif(BUNDLED_GLEW)
	endif(NOT FEATURE_RENDERER_GLES)

	if(BUNDLED_JPEG)
		add_dependencies(${R1_NAME} bundled_jpeg)
	endif(BUNDLED_JPEG)

	if(BUNDLED_FREETYPE)
		add_dependencies(${R1_NAME} bundled_freetype)
	endif(BUNDLED_FREETYPE)

	target_link_libraries(${R1_NAME} ${RENDERER_LIBRARIES})

	# install the dynamic lib only
	if(RENDERER_DYNAMIC)
		set_target_properties(${R1_NAME}
			PROPERTIES
			LIBRARY_OUTPUT_DIRECTORY ""
			LIBRARY_OUTPUT_DIRECTORY_DEBUG ""
			LIBRARY_OUTPUT_DIRECTORY_RELEASE ""
		)

		if(WIN32)
            set_target_properties(${R1_NAME} PROPERTIES PREFIX "")
		endif(WIN32)

		if(WIN32)
			install(TARGETS ${R1_NAME}
				LIBRARY DESTINATION "${INSTALL_DEFAULT_BINDIR}"
				ARCHIVE DESTINATION "${INSTALL_DEFAULT_BINDIR}"
			)
		else(WIN32)
			install(TARGETS ${R1_NAME}
				LIBRARY DESTINATION "${INSTALL_DEFAULT_MODDIR}"
				ARCHIVE DESTINATION "${INSTALL_DEFAULT_MODDIR}"
			)
		endif(WIN32)
	endif(RENDERER_DYNAMIC)
	if(NOT RENDERER_DYNAMIC)
		list(APPEND CLIENT_LIBRARIES ${R1_NAME})
	endif(NOT RENDERER_DYNAMIC)
endif(RENDERER_DYNAMIC OR NOT FEATURE_RENDERER2)
if(FEATURE_RENDERER2)
	if(MSVC)
		list(APPEND RENDERER2_FILES ${RENDERER2_SHADERS})
	endif(MSVC)

	#This is where we generate the fallback shaders source file.
	if(SED_EXECUTABLE)
		SET(SHADER_OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/glsl/tr_glslsources.c")
		GET_FILENAME_COMPONENT(GLSL_FULLPATH ${GLSL_PATH} ABSOLUTE)
		FILE(READ "${GLSL_PATH}/copyright.txt" SHADER_SOURCES)
		SET(SHADER_SOURCES "${SHADER_SOURCES}\n/* This file was generated by CMake do not modify as it will get overwritten */\n\n#include \"${CMAKE_CURRENT_SOURCE_DIR}/src/renderer2/tr_local.h\"\n\n")
		FOREACH (SHAD ${RENDERER2_SHADERS})
			GET_FILENAME_COMPONENT(SHAD_NAME ${SHAD} NAME_WE)
			GET_FILENAME_COMPONENT(SHAD_FOLDER ${SHAD} PATH)

			string(REPLACE "${GLSL_FULLPATH}/" "" SHAD_FOLDER "${SHAD_FOLDER}")
			string(REPLACE "${GLSL_FULLPATH}" "" SHAD_FOLDER "${SHAD_FOLDER}")

			if(MSVC OR XCODE)
				string(REPLACE "/" "\\" SHAD_FOLDER_WIN "${SHAD_FOLDER}")
				source_group("Shaders\\${SHAD_FOLDER_WIN}" FILES ${SHAD})
			endif()

			string(LENGTH "${SHAD_FOLDER}" FOLDER_LEN)

			IF(FOLDER_LEN GREATER 0)
				string(TOLOWER "${SHAD_FOLDER}/${SHAD_NAME}" SHAD_NAME_FINAL)
				string(REPLACE "/" "_" SHAD_VAR_NAME_FINAL "${SHAD_NAME_FINAL}")
			ELSE(FOLDER_LEN GREATER 0)
				string(TOLOWER ${SHAD_NAME} SHAD_NAME_FINAL)
				set(SHAD_VAR_NAME_FINAL "${SHAD_NAME_FINAL}")
			ENDIF(FOLDER_LEN GREATER 0)

			execute_process(COMMAND ${SED_EXECUTABLE} -f ${CMAKE_CURRENT_SOURCE_DIR}/glsl2c.sed ${SHAD}
				WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
				OUTPUT_VARIABLE OUT_RES
				RESULT_VARIABLE RES_VAR
			)
			IF(SHADER_FUNCTION)
				SET(SHADER_FUNCTION "${SHADER_FUNCTION}\telse if(!Q_stricmp(name,\"${SHAD_NAME_FINAL}\"))\n\t{\n\t\treturn fallbackShader_${SHAD_VAR_NAME_FINAL};\n\t}\n")
			ELSE(SHADER_FUNCTION)
				SET(SHADER_FUNCTION "const char* GetFallbackShader(const char *name)\n{\n\tif(!Q_stricmp(name,\"${SHAD_NAME_FINAL}\"))\n\t{\n\t\treturn fallbackShader_${SHAD_VAR_NAME_FINAL};\n\t}\n")
			ENDIF(SHADER_FUNCTION)
			SET(SHADER_SOURCES "${SHADER_SOURCES}const char *fallbackShader_${SHAD_VAR_NAME_FINAL} =\n${OUT_RES}\n")
		ENDFOREACH(SHAD)
		SET(SHADER_FUNCTION "${SHADER_FUNCTION}\treturn NULL;\n}")

		FOREACH(SHADDEF ${RENDERER2_SHADERDEFS})
			execute_process(COMMAND ${SED_EXECUTABLE} -f ${CMAKE_CURRENT_SOURCE_DIR}/glsl2c.sed ${SHADDEF}
				WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
				OUTPUT_VARIABLE OUT_RES
				RESULT_VARIABLE RES_VAR
			)
			IF(SHADDEF_VAR)
				#FIXME
				#SET(SHADDEF_VAR "${SHADDEF_VAR}\n${OUT_RES}")
			ELSE(SHADDEF_VAR)
				SET(SHADDEF_VAR "//GLSL Shader default definitions found in renderer2/gldef folder")
				SET(SHADDEF_VAR "${SHADDEF_VAR}\nconst char *defaultShaderDefinitions = ${OUT_RES}\n")
			ENDIF(SHADDEF_VAR)
		ENDFOREACH(SHADDEF)

		FILE(WRITE "${SHADER_OUTPUT_FILE}" "${SHADER_SOURCES}${SHADDEF_VAR}${SHADER_FUNCTION}")
		LIST(APPEND RENDERER2_FILES "${SHADER_OUTPUT_FILE}")
	else(SED_EXECUTABLE)
		MESSAGE(FATAL_ERROR "The fallbackshader source file was not created due to \"sed\" missing. The build would fail. :(")
	endif(SED_EXECUTABLE)

	# increased default hunkmegs value
	add_definitions(-DFEATURE_INC_HUNKMEGS)
	add_library(${R2_NAME} ${REND_LIBTYPE} ${RENDERER2_FILES} ${RENDERER_COMMON} ${RENDERER2_SHADERS})
	if(BUNDLED_GLEW)
			add_dependencies(${R2_NAME} bundled_glew)
	endif(BUNDLED_GLEW)
	if(BUNDLED_JPEG)
		add_dependencies(${R2_NAME} bundled_jpeg)
	endif(BUNDLED_JPEG)
	if(BUNDLED_FREETYPE)
		add_dependencies(${R2_NAME} bundled_freetype)
	endif(BUNDLED_FREETYPE)
	target_link_libraries(${R2_NAME} ${RENDERER_LIBRARIES})

	set_target_properties(${R2_NAME}
		PROPERTIES COMPILE_DEFINITIONS "FEATURE_RENDERER2"
		LIBRARY_OUTPUT_DIRECTORY ""
		LIBRARY_OUTPUT_DIRECTORY_DEBUG ""
		LIBRARY_OUTPUT_DIRECTORY_RELEASE ""
	)

	if(WIN32)
    	set_target_properties(${R2_NAME} PROPERTIES PREFIX "")
    endif(WIN32)

	if(WIN32)
		install(TARGETS ${R2_NAME}
			LIBRARY DESTINATION "${INSTALL_DEFAULT_BINDIR}"
			ARCHIVE DESTINATION "${INSTALL_DEFAULT_BINDIR}"
		)
	else(WIN32)
		install(TARGETS ${R2_NAME}
			LIBRARY DESTINATION "${INSTALL_DEFAULT_MODDIR}"
			ARCHIVE DESTINATION "${INSTALL_DEFAULT_MODDIR}"
		)
	endif(WIN32)
	if(NOT RENDERER_DYNAMIC)
		list(APPEND CLIENT_LIBRARIES ${R2_NAME})
	endif()
endif(FEATURE_RENDERER2)

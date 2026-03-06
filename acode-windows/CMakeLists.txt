cmake_minimum_required(VERSION 3.20)
project(ACode C)

set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Windows-specific settings
if(WIN32)
    add_definitions(-DUNICODE -D_UNICODE -DWIN32_LEAN_AND_MEAN -DNOMINMAX)
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SUBSYSTEM:WINDOWS")
endif()

# Source files
file(GLOB_RECURSE SOURCES "src/*.c")

# Dependencies
set(DEP_SOURCES
    deps/sqlite3/sqlite3.c
    deps/cJSON/cJSON.c
)

# Resource file (Windows only)
if(WIN32)
    set(RESOURCE_FILE res/app.rc)
endif()

add_executable(ACode WIN32
    ${SOURCES}
    ${DEP_SOURCES}
    ${RESOURCE_FILE}
)

target_include_directories(ACode PRIVATE
    src
    deps/sqlite3
    deps/cJSON
)

if(WIN32)
    target_link_libraries(ACode PRIVATE
        user32
        gdi32
        shell32
        ole32
        oleaut32
        dwmapi
        d2d1
        dwrite
        comctl32
        shlwapi
        winhttp
        advapi32
    )

    target_compile_definitions(ACode PRIVATE
        _CRT_SECURE_NO_WARNINGS
    )
endif()

# Manifest for DPI awareness and modern controls
if(WIN32 AND MSVC)
    set_target_properties(ACode PROPERTIES
        VS_DPI_AWARE "PerMonitor"
        LINK_FLAGS "/MANIFEST:EMBED /MANIFESTINPUT:${CMAKE_SOURCE_DIR}/res/app.manifest"
    )
endif()

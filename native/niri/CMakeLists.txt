qt_add_qml_module(ateria_niri
    SHARED
    URI Ateria.Niri
    VERSION 1.0
    SOURCES
        niriipc.cpp
        niriipc.h
)

target_link_libraries(ateria_niri
    PRIVATE
        Qt6::Core
        Qt6::Network
        Qt6::Qml
)

target_compile_definitions(ateria_niri
    PRIVATE
        QT_NO_CAST_FROM_ASCII
        QT_NO_CAST_TO_ASCII
)

target_compile_options(ateria_niri PRIVATE -Wall -Wextra -Wpedantic)

if(ATERIA_BUILD_TESTS)
    add_subdirectory(tests)
endif()

qt_add_qml_module(ateria_wallpaper
    SHARED
    URI Ateria.Wallpaper
    VERSION 1.0
    SOURCES
        matugenrunner.cpp
        matugenrunner.h
        processscheduler.cpp
        processscheduler.h
        wallpapermanager.cpp
        wallpapermanager.h
)

target_link_libraries(ateria_wallpaper
    PRIVATE
        Qt6::Concurrent
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
)

target_compile_definitions(ateria_wallpaper
    PRIVATE
        QT_NO_CAST_FROM_ASCII
        QT_NO_CAST_TO_ASCII
)

target_compile_options(ateria_wallpaper PRIVATE -Wall -Wextra -Wpedantic)

if(ATERIA_BUILD_TESTS)
    add_subdirectory(tests)
endif()

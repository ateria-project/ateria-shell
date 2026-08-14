qt_add_executable(tst_wallpapermanager
    tst_wallpapermanager.cpp
)

target_link_libraries(tst_wallpapermanager
    PRIVATE
        ateria_wallpaper
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Test
)

target_include_directories(tst_wallpapermanager PRIVATE ..)
target_compile_options(tst_wallpapermanager PRIVATE -Wall -Wextra -Wpedantic)

add_test(NAME tst_wallpapermanager COMMAND tst_wallpapermanager)

qt_add_executable(tst_matugenrunner
    tst_matugenrunner.cpp
)

target_link_libraries(tst_matugenrunner
    PRIVATE
        ateria_wallpaper
        Qt6::Core
        Qt6::Qml
        Qt6::Test
)

target_include_directories(tst_matugenrunner PRIVATE ..)
target_compile_options(tst_matugenrunner PRIVATE -Wall -Wextra -Wpedantic)

add_test(NAME tst_matugenrunner COMMAND tst_matugenrunner)

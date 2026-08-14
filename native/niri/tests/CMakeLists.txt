qt_add_executable(tst_niriipc
    tst_niriipc.cpp
)

target_link_libraries(tst_niriipc
    PRIVATE
        ateria_niri
        Qt6::Core
        Qt6::Network
        Qt6::Qml
        Qt6::Test
)

target_include_directories(tst_niriipc PRIVATE ..)
target_compile_options(tst_niriipc PRIVATE -Wall -Wextra -Wpedantic)

add_test(NAME tst_niriipc COMMAND tst_niriipc)

qt_add_executable(tst_bluetoothagent
    tst_bluetoothagent.cpp
)

target_link_libraries(tst_bluetoothagent
    PRIVATE
        ateria_bluetooth
        Qt6::Core
        Qt6::DBus
        Qt6::Qml
        Qt6::Test
)

target_include_directories(tst_bluetoothagent PRIVATE ..)
target_compile_options(tst_bluetoothagent PRIVATE -Wall -Wextra -Wpedantic)

add_test(NAME tst_bluetoothagent COMMAND tst_bluetoothagent)

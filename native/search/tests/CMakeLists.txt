qt_add_executable(tst_launchersearchmodel
    tst_launchersearchmodel.cpp
)

target_link_libraries(tst_launchersearchmodel
    PRIVATE
        ateria_search
        Qt6::Core
        Qt6::Qml
        Qt6::Test
)

target_include_directories(tst_launchersearchmodel PRIVATE ..)
target_compile_options(tst_launchersearchmodel PRIVATE -Wall -Wextra -Wpedantic)

add_test(NAME tst_launchersearchmodel COMMAND tst_launchersearchmodel)

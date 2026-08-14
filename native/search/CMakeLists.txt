qt_add_qml_module(ateria_search
    SHARED
    URI Ateria.Search
    VERSION 1.0
    SOURCES
        launchersearch.cpp
        launchersearch.h
        launchersearchmodel.cpp
        launchersearchmodel.h
)

target_link_libraries(ateria_search
    PRIVATE
        Qt6::Core
        Qt6::Qml
)

target_compile_definitions(ateria_search
    PRIVATE
        QT_NO_CAST_FROM_ASCII
        QT_NO_CAST_TO_ASCII
)

target_compile_options(ateria_search PRIVATE -Wall -Wextra -Wpedantic)

if(ATERIA_BUILD_TESTS)
    add_subdirectory(tests)
endif()

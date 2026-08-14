function(ateria_install_qml_module target)
    qt_query_qml_module(${target}
        PLUGIN_TARGET module_plugin_target
        TARGET_PATH module_target_path
        QMLDIR module_qmldir
        TYPEINFO module_typeinfo
    )

    if(NOT module_plugin_target OR NOT module_target_path)
        message(FATAL_ERROR "Could not resolve the install metadata for ${target}")
    endif()

    set(module_install_dir "${ATERIA_QML_INSTALL_DIR}/${module_target_path}")

    # Keep the backing library beside its generated QML plugin. The installed
    # plugin can then resolve it without depending on the build directory.
    install(TARGETS ${target} ${module_plugin_target}
        LIBRARY DESTINATION "${module_install_dir}" COMPONENT ateria-native
        RUNTIME DESTINATION "${module_install_dir}" COMPONENT ateria-native
    )
    install(FILES "${module_qmldir}" "${module_typeinfo}"
        DESTINATION "${module_install_dir}"
        COMPONENT ateria-native
    )

    set_property(TARGET ${module_plugin_target} APPEND PROPERTY
        INSTALL_RPATH "$ORIGIN")
endfunction()

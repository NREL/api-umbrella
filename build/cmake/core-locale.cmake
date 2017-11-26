find_package(Gettext REQUIRED)

file(GLOB locale_files ${CMAKE_SOURCE_DIR}/locale/*.po)

add_custom_command(
  OUTPUT ${CORE_BUILD_DIR}/tmp/locale-build
  DEPENDS ${locale_files}
  COMMAND rm -rf ${CORE_BUILD_DIR}/tmp/locale-build
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/locale-build
  COMMAND touch -h ${CORE_BUILD_DIR}/tmp/locale-build
)

foreach(locale_file ${locale_files})
  get_filename_component(locale ${locale_file} NAME_WE)

  add_custom_command(
    OUTPUT ${CORE_BUILD_DIR}/tmp/locale-build/${locale}.json
    DEPENDS
      ${STAMP_DIR}/core-admin-ui-yarn-install
      ${CORE_BUILD_DIR}/tmp/locale-build
      ${locale_file}
    COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/locale-build/
    COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-ui-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/po2json --format=jed1.x --domain=api-umbrella ${locale_file} ${CORE_BUILD_DIR}/tmp/locale-build/${locale}.json
  )

  list(APPEND locale_depends ${CORE_BUILD_DIR}/tmp/locale-build/${locale}.json)
endforeach(locale_file)

add_custom_command(
  OUTPUT ${STAMP_DIR}/core-locale-build
  DEPENDS ${locale_depends}
  COMMAND touch ${STAMP_DIR}/core-locale-build
)

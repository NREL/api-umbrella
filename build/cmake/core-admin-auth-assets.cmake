add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-auth-assets-build-dir
    ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/package.json
  DEPENDS
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/assets/login.scss
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/package.json
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/webpack.config.js
    ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/yarn.lock
  COMMAND mkdir -p ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build
  COMMAND rsync -a -v --delete-after "--filter=:- ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/.gitignore" ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/ ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/
  COMMAND touch ${STAMP_DIR}/core-admin-auth-assets-build-dir
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-auth-assets-yarn-install
    ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/node_modules
  DEPENDS
    yarn
    ${STAMP_DIR}/core-admin-auth-assets-build-dir
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} yarn install --frozen-lockfile
  # In the CI environment, the "node-sass/vendor" directory seems to sometimes
  # go away. A bit of a hack, but try to workaround this by forcing node-sass
  # to be reinstalled if the vendor dir is missing.
  #
  # See:
  # https://github.com/yarnpkg/yarn/issues/1981
  # https://github.com/yarnpkg/yarn/issues/1832
  # https://github.com/sass/node-sass/issues/1579
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build && test -d node_modules/node-sass && test -d node_modules/node-sass/vendor || env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} yarn add node-sass --force
  COMMAND touch ${STAMP_DIR}/core-admin-auth-assets-yarn-install
)

add_custom_command(
  OUTPUT
    ${STAMP_DIR}/core-admin-auth-assets-build
    ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/assets/dist
  DEPENDS
    ${STAMP_DIR}/core-admin-auth-assets-build-dir
    ${STAMP_DIR}/core-admin-auth-assets-yarn-install
  COMMAND cd ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build && env PATH=${DEV_INSTALL_PREFIX}/bin:$ENV{PATH} ./node_modules/.bin/webpack
  COMMAND touch ${STAMP_DIR}/core-admin-auth-assets-build
)

# Normally we perform the yarn installs out-of-source (so the build takes place
# entirely out of source), but if testing/development is enabled for this
# build, then also create a local symlink within the source. This then allows
# for easier interactions with the application.
if(ENABLE_TEST_DEPENDENCIES)
  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/node_modules
    DEPENDS
      ${STAMP_DIR}/core-admin-auth-assets-yarn-install
      ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/node_modules
    COMMAND rm -rf ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/node_modules
    COMMAND ln -snf ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/node_modules ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/node_modules
    COMMAND touch -h ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/node_modules
  )
  add_custom_target(core-admin-auth-assets-local-yarn ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/node_modules)

  add_custom_command(
    OUTPUT ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/assets/dist
    DEPENDS
      ${STAMP_DIR}/core-admin-auth-assets-build
      ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/assets/dist
    COMMAND rm -rf ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/assets/dist
    COMMAND ln -snf ${CORE_BUILD_DIR}/tmp/admin-auth-assets-build/assets/dist ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/assets/dist
    COMMAND touch -h ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/assets/dist
  )
  add_custom_target(core-admin-auth-assets-local-dist ALL DEPENDS ${CMAKE_SOURCE_DIR}/src/api-umbrella/lapis/assets/dist)
endif()

# Ruby & Bundler: For Rails web-app component

set(BUNDLER_VERSION 1.16.2)
set(BUNDLER_HASH 3bb53e03db0a8008161eb4c816ccd317120d3c415ba6fee6f90bbc7f7eec8690)
set(RUBY_VERSION 2.4.4)
set(RUBY_HASH 45a8de577471b90dc4838c5ef26aeb253a56002896189055a44dc680644243f1)
set(RUBYGEMS_VERSION 2.7.7)
set(RUBYGEMS_HASH 1df4c1883656593eb1b48f572a085f16f73e7c759e69dcafe26189a6eca7cc0f)

list(APPEND RUBY_CONFIGURE_CMD env)
list(APPEND RUBY_CONFIGURE_CMD <SOURCE_DIR>/configure)
list(APPEND RUBY_CONFIGURE_CMD --prefix=${INSTALL_PREFIX_EMBEDDED})
list(APPEND RUBY_CONFIGURE_CMD --enable-load-relative)
list(APPEND RUBY_CONFIGURE_CMD --disable-rpath)
list(APPEND RUBY_CONFIGURE_CMD --disable-install-doc)

ExternalProject_Add(
  ruby
  EXCLUDE_FROM_ALL 1
  URL https://cache.ruby-lang.org/pub/ruby/ruby-${RUBY_VERSION}.tar.bz2
  URL_HASH SHA256=${RUBY_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND ${RUBY_CONFIGURE_CMD}
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  rubygems
  EXCLUDE_FROM_ALL 1
  DEPENDS ruby
  URL https://rubygems.org/downloads/rubygems-update-${RUBYGEMS_VERSION}.gem
  URL_HASH SHA256=${RUBYGEMS_HASH}
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_PATH} gem update --system ${RUBYGEMS_VERSION} --no-document
)

ExternalProject_Add(
  bundler
  EXCLUDE_FROM_ALL 1
  DEPENDS rubygems
  URL https://rubygems.org/downloads/bundler-${BUNDLER_VERSION}.gem
  URL_HASH SHA256=${BUNDLER_HASH}
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_PATH} gem install <DOWNLOADED_FILE> --no-document --env-shebang --local --force
)

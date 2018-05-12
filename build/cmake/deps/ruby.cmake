# Ruby & Bundler: For Rails web-app component

set(BUNDLER_VERSION 1.16.1)
set(BUNDLER_HASH 42b8e0f57093e1d10c15542f956a871446b759e7969d99f91caf3b6731c156e8)
set(RUBY_VERSION 2.4.4)
set(RUBY_HASH 45a8de577471b90dc4838c5ef26aeb253a56002896189055a44dc680644243f1)
set(RUBYGEMS_VERSION 2.7.6)
set(RUBYGEMS_HASH ee5ef219ac97f5499c31e6071eae424c3265620ece33b5cc66e09fa30f22086a)

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
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} gem update --system ${RUBYGEMS_VERSION} --no-document
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
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} gem install <DOWNLOADED_FILE> --no-document --env-shebang --local --force
)

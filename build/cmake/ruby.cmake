# Ruby & Bundler: For Rails web-app component
ExternalProject_Add(
  ruby
  URL https://cache.ruby-lang.org/pub/ruby/2.2/ruby-${RUBY_VERSION}.tar.bz2
  URL_HASH SHA256=${RUBY_HASH}
  CONFIGURE_COMMAND rm -rf <BINARY_DIR> && mkdir -p <BINARY_DIR> # Clean across version upgrades
    COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --enable-load-relative --disable-install-doc
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  bundler
  DEPENDS ruby
  URL https://rubygems.org/downloads/bundler-${BUNDLER_VERSION}.gem
  URL_HASH SHA256=${BUNDLER_HASH}
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} gem uninstall bundler --all --executables
    COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} gem install <DOWNLOADED_FILE> --no-rdoc --no-ri --env-shebang --local
)

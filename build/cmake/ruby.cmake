# Ruby & Bundler: For Rails web-app component
ExternalProject_Add(
  ruby
  URL https://cache.ruby-lang.org/pub/ruby/2.2/ruby-${RUBY_VERSION}.tar.bz2
  URL_HASH SHA256=${RUBY_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${INSTALL_PREFIX_EMBEDDED} --enable-load-relative --disable-install-doc
  INSTALL_COMMAND make install DESTDIR=${STAGE_DIR}
)

ExternalProject_Add(
  bundler
  DEPENDS ruby
  DOWNLOAD_COMMAND cd <SOURCE_DIR> && curl -OL https://rubygems.org/downloads/bundler-${BUNDLER_VERSION}.gem
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND env PATH=${STAGE_EMBEDDED_DIR}/bin:$ENV{PATH} gem install <SOURCE_DIR>/bundler-${BUNDLER_VERSION}.gem --no-rdoc --no-ri --env-shebang --local
)

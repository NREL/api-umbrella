# Unexport make variables given as command line arguments to the make command.
#
# This prevents passing variables that we might set (like DESTDIR, etc) down to
# sub-processes. We're predominately building other projects, and we don't want
# them to automatically pick up these variables, or it can lead to lots of
# strange build errors.
unexport DESTDIR PREFIX ROOT_DIR BUILD_DIR WORK_DIR
MAKEOVERRIDES=

# Also unexport some problematic environment variables that might be set.
#
# These environment variables come from RVM (which our CircleCI environment
# uses) which causes conflicts with our Ruby installation.
unexport GEM_HOME GEM_PATH IRBRC MY_RUBY_HOME RUBY_VERSION

STANDARD_PATH:=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin
PREFIX:=/opt/api-umbrella
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR:=$(ROOT_DIR)/build
WORK_DIR:=$(BUILD_DIR)/work
DEPS_DIR:=$(WORK_DIR)/deps
STAGE_DIR:=$(WORK_DIR)/stage
STAGE_PREFIX:=$(STAGE_DIR)$(PREFIX)
EMBEDDED_DIR:=$(STAGE_PREFIX)/embedded
STAGE_MARKERS_DIR:=$(STAGE_DIR)/.installed
VENDOR_DIR:=$(WORK_DIR)/vendor
BUNDLE_DIR:=$(VENDOR_DIR)/bundle
LUAROCKS_DIR:=$(VENDOR_DIR)/lib/luarocks/rocks
LUAROCKS_CMD:=LUA_PATH="$(EMBEDDED_DIR)/openresty/luajit/share/lua/5.1/?.lua;$(EMBEDDED_DIR)/openresty/luajit/share/lua/5.1/?/init.lua;;" $(EMBEDDED_DIR)/bin/luarocks
LUA_SHARE_DIR:=$(VENDOR_DIR)/share/lua/5.1
LUA_SHARE_MARKERS_DIR:=$(LUA_SHARE_DIR)/.installed
LUA_LIB_DIR:=$(VENDOR_DIR)/lib/lua/5.1
TEST_PREFIX:=/opt/api-umbrella/test-env
TEST_STAGE_PREFIX:=$(STAGE_DIR)$(TEST_PREFIX)
TEST_VENDOR_DIR:=$(WORK_DIR)/test-env/vendor
TEST_LUAROCKS_DIR:=$(TEST_VENDOR_DIR)/lib/luarocks/rocks
TEST_LUA_SHARE_DIR:=$(TEST_VENDOR_DIR)/share/lua/5.1
TEST_LUA_LIB_DIR:=$(TEST_VENDOR_DIR)/lib/lua/5.1
VERSION_SEP:=-version-
RELEASE_TIMESTAMP:=$(shell date -u +%Y%m%d%H%M%S)

#
# Dependencies
#
API_UMBRELLA_STATIC_SITE_VERSION:=265714dbee04efa14f4d83e1f78f06ec492d9c6e
API_UMBRELLA_STATIC_SITE_NAME:=api-umbrella-static-site
API_UMBRELLA_STATIC_SITE:=$(API_UMBRELLA_STATIC_SITE_NAME)-$(API_UMBRELLA_STATIC_SITE_VERSION)
API_UMBRELLA_STATIC_SITE_DIGEST:=md5
API_UMBRELLA_STATIC_SITE_CHECKSUM:=500d14f7417bee84169b2591f2d7722f
API_UMBRELLA_STATIC_SITE_URL:=https://github.com/NREL/api-umbrella-static-site/archive/$(API_UMBRELLA_STATIC_SITE_VERSION).tar.gz
API_UMBRELLA_STATIC_SITE_INSTALL_MARKER:=$(API_UMBRELLA_STATIC_SITE_NAME)$(VERSION_SEP)$(API_UMBRELLA_STATIC_SITE_VERSION)

BUNDLER_VERSION:=1.11.2
BUNDLER_NAME:=bundler
BUNDLER:=$(BUNDLER_NAME)-$(BUNDLER_VERSION)
BUNDLER_INSTALL_MARKER:=$(BUNDLER_NAME)$(VERSION_SEP)$(BUNDLER_VERSION)

ELASTICSEARCH_VERSION:=1.7.4
ELASTICSEARCH_NAME:=elasticsearch
ELASTICSEARCH:=$(ELASTICSEARCH_NAME)-$(ELASTICSEARCH_VERSION)
ELASTICSEARCH_DIGEST:=sha1
ELASTICSEARCH_CHECKSUM:=867457ac2f7b52295b7896766fa12f1171cd4617
ELASTICSEARCH_URL:=https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$(ELASTICSEARCH_VERSION).tar.gz
ELASTICSEARCH_INSTALL_MARKER:=$(ELASTICSEARCH_NAME)$(VERSION_SEP)$(ELASTICSEARCH_VERSION)

GLIDE_VERSION:=0.8.3
GLIDE_NAME:=glide
GLIDE:=$(GLIDE_NAME)-$(GLIDE_VERSION)
GLIDE_DIGEST:=md5
GLIDE_CHECKSUM:=7ba5bc7407dab2d463d12659450cdea8
GLIDE_URL:=https://github.com/Masterminds/glide/archive/$(GLIDE_VERSION).tar.gz
GLIDE_INSTALL_MARKER:=$(GLIDE_NAME)$(VERSION_SEP)$(GLIDE_VERSION)

GOLANG_VERSION:=1.5.4
GOLANG_NAME:=golang
GOLANG:=$(GOLANG_NAME)-$(GOLANG_VERSION)
GOLANG_DIGEST:=sha256
GOLANG_CHECKSUM:=a3358721210787dc1e06f5ea1460ae0564f22a0fbd91be9dcd947fb1d19b9560
GOLANG_URL:=https://storage.googleapis.com/golang/go$(GOLANG_VERSION).linux-amd64.tar.gz
GOLANG_INSTALL_MARKER:=$(GOLANG_NAME)$(VERSION_SEP)$(GOLANG_VERSION)

HEKA_VERSION:=0.9.2
HEKA_VERSION_UNDERSCORE:=$(shell echo $(HEKA_VERSION) | sed -e 's/\./_/g')
HEKA_NAME:=heka
HEKA:=$(HEKA_NAME)-$(HEKA_VERSION)
HEKA_DIGEST:=md5
HEKA_CHECKSUM:=864625dff702306eba1494149ff903ee
HEKA_URL:=https://github.com/mozilla-services/heka/releases/download/v$(HEKA_VERSION)/heka-$(HEKA_VERSION_UNDERSCORE)-linux-amd64.tar.gz
HEKA_INSTALL_MARKER:=$(HEKA_NAME)$(VERSION_SEP)$(HEKA_VERSION)

LIBCIDR_VERSION:=1.2.3
LIBCIDR_NAME:=libcidr
LIBCIDR:=$(LIBCIDR_NAME)-$(LIBCIDR_VERSION)
LIBCIDR_DIGEST:=md5
LIBCIDR_CHECKSUM:=c5efcc7ae114fdaa5583f58dacecd9de
LIBCIDR_URL:=https://www.over-yonder.net/~fullermd/projects/libcidr/libcidr-$(LIBCIDR_VERSION).tar.xz
LIBCIDR_INSTALL_MARKER:=$(LIBCIDR_NAME)$(VERSION_SEP)$(LIBCIDR_VERSION)

LIBGEOIP_VERSION:=1.6.9
LIBGEOIP_NAME:=libgeoip
LIBGEOIP:=$(LIBGEOIP_NAME)-$(LIBGEOIP_VERSION)
LIBGEOIP_DIGEST:=md5
LIBGEOIP_CHECKSUM:=7475942dc8155046dddb4846f587a7e6
LIBGEOIP_URL:=https://github.com/maxmind/geoip-api-c/releases/download/v$(LIBGEOIP_VERSION)/GeoIP-$(LIBGEOIP_VERSION).tar.gz
LIBGEOIP_INSTALL_MARKER:=$(LIBGEOIP_NAME)$(VERSION_SEP)$(LIBGEOIP_VERSION)

LUA_RESTY_DNS_CACHE_VERSION:=691613739a32f8405e56e56547270b9f72e77c34
LUA_RESTY_DNS_CACHE_NAME:=lua-resty-dns-cache
LUA_RESTY_DNS_CACHE:=$(LUA_RESTY_DNS_CACHE_NAME)-$(LUA_RESTY_DNS_CACHE_VERSION)
LUA_RESTY_DNS_CACHE_DIGEST:=md5
LUA_RESTY_DNS_CACHE_CHECKSUM:=c7304c1f434ac251246904db51423d5e
LUA_RESTY_DNS_CACHE_URL:=https://github.com/hamishforbes/lua-resty-dns-cache/archive/$(LUA_RESTY_DNS_CACHE_VERSION).tar.gz
LUA_RESTY_DNS_CACHE_INSTALL_MARKER:=$(LUA_RESTY_DNS_CACHE_NAME)$(VERSION_SEP)$(LUA_RESTY_DNS_CACHE_VERSION)

LUA_RESTY_HTTP_VERSION:=0.06
LUA_RESTY_HTTP_NAME:=lua-resty-http
LUA_RESTY_HTTP:=$(LUA_RESTY_HTTP_NAME)-$(LUA_RESTY_HTTP_VERSION)
LUA_RESTY_HTTP_DIGEST:=md5
LUA_RESTY_HTTP_CHECKSUM:=d828ba0da7bc8f39e0ce0565912aa597
LUA_RESTY_HTTP_URL:=https://github.com/pintsized/lua-resty-http/archive/v$(LUA_RESTY_HTTP_VERSION).tar.gz
LUA_RESTY_HTTP_INSTALL_MARKER:=$(LUA_RESTY_HTTP_NAME)$(VERSION_SEP)$(LUA_RESTY_HTTP_VERSION)

LUA_RESTY_LOGGER_SOCKET_VERSION:=d435ea6052c0d252cf7f89fe4b7cb9c69306de93
LUA_RESTY_LOGGER_SOCKET_NAME:=lua-resty-logger-socket
LUA_RESTY_LOGGER_SOCKET:=$(LUA_RESTY_LOGGER_SOCKET_NAME)-$(LUA_RESTY_LOGGER_SOCKET_VERSION)
LUA_RESTY_LOGGER_SOCKET_DIGEST:=md5
LUA_RESTY_LOGGER_SOCKET_CHECKSUM:=6d7273438100ddcdfa57bdbf1a8c3a01
LUA_RESTY_LOGGER_SOCKET_URL:=https://github.com/cloudflare/lua-resty-logger-socket/archive/$(LUA_RESTY_LOGGER_SOCKET_VERSION).tar.gz
LUA_RESTY_LOGGER_SOCKET_INSTALL_MARKER:=$(LUA_RESTY_LOGGER_SOCKET_NAME)$(VERSION_SEP)$(LUA_RESTY_LOGGER_SOCKET_VERSION)

LUA_RESTY_SHCACHE_VERSION:=fb2e275c2cdca08eaa34a7b73375e41ac3eff200
LUA_RESTY_SHCACHE_NAME:=lua-resty-shcache
LUA_RESTY_SHCACHE:=$(LUA_RESTY_SHCACHE_NAME)-$(LUA_RESTY_SHCACHE_VERSION)
LUA_RESTY_SHCACHE_DIGEST:=md5
LUA_RESTY_SHCACHE_CHECKSUM:=5d3cbcf8fbad1954cdcb3826afa41afe
LUA_RESTY_SHCACHE_URL:=https://github.com/cloudflare/lua-resty-shcache/archive/$(LUA_RESTY_SHCACHE_VERSION).tar.gz
LUA_RESTY_SHCACHE_INSTALL_MARKER:=$(LUA_RESTY_SHCACHE_NAME)$(VERSION_SEP)$(LUA_RESTY_SHCACHE_VERSION)

LUA_RESTY_UUID_VERSION:=70a01d8a6c2cd7ef8bbe622658b58ec30b6b90d4
LUA_RESTY_UUID_NAME:=lua-resty-uuid
LUA_RESTY_UUID:=$(LUA_RESTY_UUID_NAME)-$(LUA_RESTY_UUID_VERSION)
LUA_RESTY_UUID_DIGEST:=md5
LUA_RESTY_UUID_CHECKSUM:=33166f03a573c0381299eae939d48a0e
LUA_RESTY_UUID_URL:=https://github.com/bungle/lua-resty-uuid/archive/$(LUA_RESTY_UUID_VERSION).tar.gz
LUA_RESTY_UUID_INSTALL_MARKER:=$(LUA_RESTY_UUID_NAME)$(VERSION_SEP)$(LUA_RESTY_UUID_VERSION)

LUAROCKS_VERSION:=2.2.2
LUAROCKS_NAME:=luarocks
LUAROCKS:=$(LUAROCKS_NAME)-$(LUAROCKS_VERSION)
LUAROCKS_DIGEST:=md5
LUAROCKS_CHECKSUM:=5a830953d27715cc955119609f8096e6
LUAROCKS_URL:=http://luarocks.org/releases/luarocks-$(LUAROCKS_VERSION).tar.gz
LUAROCKS_INSTALL_MARKER:=$(LUAROCKS_NAME)$(VERSION_SEP)$(LUAROCKS_VERSION)

LUSTACHE_VERSION:=c2e7573a1d19e93f5498143d95d9fa705ee512fd
LUSTACHE_NAME:=lustache
LUSTACHE:=$(LUSTACHE_NAME)-$(LUSTACHE_VERSION)
LUSTACHE_DIGEST:=md5
LUSTACHE_CHECKSUM:=f247df62b30c17f5dfbc60203b1c2510
LUSTACHE_URL:=https://github.com/Olivine-Labs/lustache/archive/$(LUSTACHE_VERSION).tar.gz
LUSTACHE_INSTALL_MARKER:=$(LUSTACHE_NAME)$(VERSION_SEP)$(LUSTACHE_VERSION)

MONGODB_VERSION:=3.0.8
MONGODB_NAME:=mongodb
MONGODB:=$(MONGODB_NAME)-$(MONGODB_VERSION)
MONGODB_DIGEST:=md5
MONGODB_CHECKSUM:=587185c36a4cd3128abae2416b969371
MONGODB_URL:=https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-$(MONGODB_VERSION).tgz
MONGODB_INSTALL_MARKER:=$(MONGODB_NAME)$(VERSION_SEP)$(MONGODB_VERSION)

MORA_VERSION:=0c409c9cbb283708e92cc69a50281ac536f97874
MORA_NAME:=mora
MORA:=$(MORA_NAME)-$(MORA_VERSION)
MORA_DIGEST:=md5
MORA_CHECKSUM:=563945c899b30099543254df84b487d7
MORA_URL:=https://github.com/emicklei/mora/archive/$(MORA_VERSION).tar.gz
MORA_DEPENDENCIES_CHECKSUM:=$(shell openssl md5 $(BUILD_DIR)/mora_glide.yaml | sed 's/^.* //')
MORA_INSTALL_MARKER:=$(MORA_NAME)$(VERSION_SEP)$(MORA_VERSION)-$(MORA_DEPENDENCIES_CHECKSUM)

NGX_TXID_VERSION:=f1c197cb9c42e364a87fbb28d5508e486592ca42
NGX_TXID_NAME:=ngx_txid
NGX_TXID:=$(NGX_TXID_NAME)-$(NGX_TXID_VERSION)
NGX_TXID_DIGEST:=md5
NGX_TXID_CHECKSUM:=408ee86eb6e42e27a51514f711c41d6b
NGX_TXID_URL:=https://github.com/streadway/ngx_txid/archive/$(NGX_TXID_VERSION).tar.gz
NGX_TXID_INSTALL_MARKER:=$(NGX_TXID_NAME)$(VERSION_SEP)$(NGX_TXID_VERSION)

NGX_DYUPS_VERSION:=3683b0031c86d5d240bc0b7caf215dff29597fb2
NGX_DYUPS_NAME:=ngx_http_dyups_module
NGX_DYUPS:=$(NGX_DYUPS_NAME)-$(NGX_DYUPS_VERSION)
NGX_DYUPS_DIGEST:=md5
NGX_DYUPS_CHECKSUM:=3e5580abad9cc45f52c2e2ccc3c35e48
NGX_DYUPS_URL:=https://github.com/yzprofile/ngx_http_dyups_module/archive/$(NGX_DYUPS_VERSION).tar.gz
NGX_DYUPS_INSTALL_MARKER:=$(NGX_DYUPS_NAME)$(VERSION_SEP)$(NGX_DYUPS_VERSION)

OPENRESTY_VERSION:=1.9.7.4
OPENRESTY_BUILD_REVISION:=1
OPENRESTY_NAME:=openresty
OPENRESTY:=$(OPENRESTY_NAME)-$(OPENRESTY_VERSION)-$(OPENRESTY_BUILD_REVISION)
OPENRESTY_DIGEST:=md5
OPENRESTY_CHECKSUM:=6e2d4a39c530524111ea50e3de67043a
OPENRESTY_URL:=http://openresty.org/download/openresty-$(OPENRESTY_VERSION).tar.gz
OPENRESTY_INSTALL_MARKER:=$(OPENRESTY_NAME)$(VERSION_SEP)$(OPENRESTY_VERSION)

PCRE_VERSION:=8.38
PCRE_NAME:=pcre
PCRE:=$(PCRE_NAME)-$(PCRE_VERSION)
PCRE_DIGEST:=md5
PCRE_CHECKSUM:=00aabbfe56d5a48b270f999b508c5ad2
PCRE_URL:=http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-$(PCRE_VERSION).tar.bz2
PCRE_INSTALL_MARKER:=$(PCRE_NAME)$(VERSION_SEP)$(PCRE_VERSION)

PERP_VERSION:=2.07
PERP_NAME:=perp
PERP:=$(PERP_NAME)-$(PERP_VERSION)
PERP_DIGEST:=md5
PERP_CHECKSUM:=a2acc7425d556d9635a25addcee9edb5
PERP_URL:=http://b0llix.net/perp/distfiles/perp-$(PERP_VERSION).tar.gz
PERP_INSTALL_MARKER:=$(PERP_NAME)$(VERSION_SEP)$(PERP_VERSION)

RUBY_VERSION:=2.2.4
RUBY_NAME:=ruby
RUBY:=$(RUBY_NAME)-$(RUBY_VERSION)
RUBY_DIGEST:=sha256
RUBY_CHECKSUM:=31203696adbfdda6f2874a2de31f7c5a1f3bcb6628f4d1a241de21b158cd5c76
RUBY_URL:=https://cache.ruby-lang.org/pub/ruby/2.2/ruby-$(RUBY_VERSION).tar.bz2
RUBY_INSTALL_MARKER:=$(RUBY_NAME)$(VERSION_SEP)$(RUBY_VERSION)

RUNIT_VERSION:=2.1.2
RUNIT_NAME:=runit
RUNIT:=$(RUNIT_NAME)-$(RUNIT_VERSION)
RUNIT_DIGEST:=md5
RUNIT_CHECKSUM:=6c985fbfe3a34608eb3c53dc719172c4
RUNIT_URL:=http://smarden.org/runit/runit-$(RUNIT_VERSION).tar.gz
RUNIT_INSTALL_MARKER:=$(RUNIT_NAME)$(VERSION_SEP)$(RUNIT_VERSION)

# Don't move to 6.0.0 quite yet until we have a better sense of this issue:
# http://mail-archives.apache.org/mod_mbox/trafficserver-users/201510.mbox/%3c1443975393.1364867.400869481.2BFF6EEF@webmail.messagingengine.com%3e
TRAFFICSERVER_VERSION:=5.3.2
TRAFFICSERVER_NAME:=trafficserver
TRAFFICSERVER:=$(TRAFFICSERVER_NAME)-$(TRAFFICSERVER_VERSION)
TRAFFICSERVER_DIGEST:=md5
TRAFFICSERVER_CHECKSUM:=c8e5f3e81da643ea79cba0494ed37d45
TRAFFICSERVER_URL:=http://mirror.olnevhost.net/pub/apache/trafficserver/trafficserver-$(TRAFFICSERVER_VERSION).tar.bz2
TRAFFICSERVER_INSTALL_MARKER:=$(TRAFFICSERVER_NAME)$(VERSION_SEP)$(TRAFFICSERVER_VERSION)

#
# LuaRocks Dependencies
#
ARGPARSE:=argparse
ARGPARSE_VERSION:=0.4.1-1
INSPECT:=inspect
INSPECT_VERSION:=3.0-3
LIBCIDR_FFI:=libcidr-ffi
LIBCIDR_FFI_VERSION:=0.1.0-1
LUA_CMSGPACK:=lua-cmsgpack
LUA_CMSGPACK_VERSION:=0.4.0-0
LUA_ICONV:=lua-iconv
LUA_ICONV_VERSION:=7-1
LUAPOSIX:=luaposix
LUAPOSIX_VERSION:=33.3.1-1
LUASOCKET:=luasocket
LUASOCKET_VERSION:=2.0.2-6
LYAML:=lyaml
LYAML_VERSION:=6.0-1
PENLIGHT:=penlight
PENLIGHT_VERSION:=1.3.2-2

#
# Test Dependencies
#
UNBOUND_VERSION:=1.5.7
UNBOUND_NAME:=unbound
UNBOUND:=$(UNBOUND_NAME)-$(UNBOUND_VERSION)
UNBOUND_DIGEST:=sha256
UNBOUND_CHECKSUM:=4b2088e5aa81a2d48f6337c30c1cf7e99b2e2dc4f92e463b3bee626eee731ca8
UNBOUND_URL:=https://www.unbound.net/downloads/unbound-$(UNBOUND_VERSION).tar.gz
UNBOUND_INSTALL_MARKER:=$(UNBOUND_NAME)$(VERSION_SEP)$(UNBOUND_VERSION)

#
# LuaRocks Test Dependencies
#
LUACHECK:=luacheck
LUACHECK_VERSION:=0.11.1-1

# Define non-file/folder targets
.PHONY: \
	all \
	clean \
	dependencies \
	install \
	after_install \
	local_work_dir \
	install_lua_vendor_deps \
	stage \
	stage_dependencies \
	test_dependencies \
	lint \
	test \
	check_shared_objects \
	download_deps \
	download_verify_package_deps \
	package \
	verify_package \
	package_docker_centos6 \
	verify_package_docker_centos6 \
	package_docker_centos7 \
	verify_package_docker_centos7 \
	package_docker_ubuntu1204 \
	verify_package_docker_ubuntu1204 \
	package_docker_ubuntu1404 \
	verify_package_docker_ubuntu1404 \
	package_docker_debian7 \
	verify_package_docker_debian7 \
	package_docker_debian8 \
	verify_package_docker_debian8 \
	all_packages

define download
	$(eval DOWNLOAD_PATH:=$@)
	$(eval DOWNLOAD_URL:=$($(1)_URL))
	curl -L -o $(DOWNLOAD_PATH) $(DOWNLOAD_URL)
	touch $(DOWNLOAD_PATH)
endef

define decompress
	$(eval DOWNLOAD_PATH:=$<)
	$(eval DIR:=$@)
	$(eval CHECKSUM_TYPE:=$($(1)_DIGEST))
	$(eval CHECKSUM:=$($(1)_CHECKSUM))
	$(eval ARCHIVE_DEPTH:=$(if $(2),$(2),1))
	openssl $(CHECKSUM_TYPE) $(DOWNLOAD_PATH) | grep $(CHECKSUM) || (echo "checksum mismatch $(DOWNLOAD_PATH)" && exit 1)
	mkdir -p $(DIR)
	tar --strip-components $(ARCHIVE_DEPTH) -C $(DIR) -xf $(DOWNLOAD_PATH)
	touch $(DIR)
endef

define luarocks_install
	$(eval PACKAGE:=$($(1)))
	$(eval PACKAGE_VERSION:=$($(1)_VERSION))
	$(LUAROCKS_CMD) --tree=$(VENDOR_DIR) install $(PACKAGE) $(PACKAGE_VERSION)
	touch $@
endef

define test_luarocks_install
	$(eval PACKAGE:=$($(1)))
	$(eval PACKAGE_VERSION:=$($(1)_VERSION))
	$(LUAROCKS_CMD) --tree=$(TEST_VENDOR_DIR) install $(PACKAGE) $(PACKAGE_VERSION)
	touch $@
endef

all: stage

$(DEPS_DIR):
	mkdir -p $@
	touch $@

$(EMBEDDED_DIR)/bin:
	mkdir -p $@
	touch $@

$(EMBEDDED_DIR)/sbin:
	mkdir -p $@
	touch $@

$(STAGE_MARKERS_DIR):
	mkdir -p $@
	touch $@

$(LUA_SHARE_MARKERS_DIR):
	mkdir -p $@
	touch $@

# api-umbrella-core
$(STAGE_MARKERS_DIR)/api-umbrella-core-web-bundled: $(ROOT_DIR)/src/api-umbrella/web-app/Gemfile $(ROOT_DIR)/src/api-umbrella/web-app/Gemfile.lock | $(VENDOR_DIR) $(STAGE_MARKERS_DIR) $(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER)
	rm -rf $(ROOT_DIR)/src/api-umbrella/web-app/.bundle
	env
	cd $(ROOT_DIR)/src/api-umbrella/web-app && PATH=$(EMBEDDED_DIR)/bin:$(PATH) bundle install --path=$(BUNDLE_DIR)
	touch $@

# Rebuild when the contents of any of the asset files change. We base this on a
# checksum of all the files, rather than timestamps, so that in our CI
# environment we skip precompiling (it's slow), if none of the files changed
# (but since the CI does a fresh checkout, all the timestamps on the files
# change, so make's normal checking would trigger changes).
WEB_ASSETS_CHECKSUM:=$(shell find $(ROOT_DIR)/src/api-umbrella/web-app/app/assets $(ROOT_DIR)/src/api-umbrella/web-app/Gemfile.lock -type f -exec cksum {} \; | sort | openssl md5 | sed 's/^.* //')
$(STAGE_MARKERS_DIR)/api-umbrella-core-web-assets$(VERSION_SEP)$(WEB_ASSETS_CHECKSUM): | $(STAGE_MARKERS_DIR)/api-umbrella-core-web-bundled $(STAGE_MARKERS_DIR)
	# Compile the assets, but then move them to a temporary build directory so
	# they aren't used when working in development mode.
	cd $(ROOT_DIR)/src/api-umbrella/web-app && PATH=$(EMBEDDED_DIR)/bin:$(PATH) DEVISE_SECRET_KEY=temp RAILS_SECRET_TOKEN=temp bundle exec rake assets:precompile
	mkdir -p $(WORK_DIR)/tmp/web-assets
	cd $(ROOT_DIR)/src/api-umbrella/web-app && rsync -a --delete-after public/web-assets/ $(WORK_DIR)/tmp/web-assets/
	rm -rf $(ROOT_DIR)/src/api-umbrella/web-app/public/web-assets
	rm -f $(STAGE_MARKERS_DIR)/api-umbrella-core-web-assets$(VERSION_SEP)*
	touch $@

$(STAGE_MARKERS_DIR)/api-umbrella-core: $(STAGE_MARKERS_DIR)/api-umbrella-core-dependencies | $(STAGE_MARKERS_DIR)
	# Create a new release directory, copying the relevant source code from the
	# current repo checkout into the release (but excluding tests, etc).
	rm -rf $(EMBEDDED_DIR)/apps/core/releases
	mkdir -p $(EMBEDDED_DIR)/apps/core/releases/$(RELEASE_TIMESTAMP)
	rsync -a \
		--filter=":- $(ROOT_DIR)/.gitignore" \
		--include="/templates/etc/perp/.boot" \
		--exclude=".*" \
		--exclude="/templates/etc/test-env*" \
		--exclude="/templates/etc/perp/test-env*" \
		--exclude="/src/api-umbrella/web-app/spec" \
		--exclude="/src/api-umbrella/web-app/app/assets" \
		--include="/bin/***" \
		--include="/config/***" \
		--include="/LICENSE.txt" \
		--include="/templates/***" \
		--include="/src/***" \
		--exclude="*" \
		$(ROOT_DIR)/ $(EMBEDDED_DIR)/apps/core/releases/$(RELEASE_TIMESTAMP)/
	cd $(EMBEDDED_DIR)/apps/core && ln -snf releases/$(RELEASE_TIMESTAMP) ./current
	# Symlink the main api-umbrella binary into place.
	mkdir -p $(STAGE_PREFIX)/bin
	cd $(STAGE_PREFIX)/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella ./api-umbrella
	# Copy all of the vendor files into place.
	mkdir -p $(EMBEDDED_DIR)/apps/core/shared/vendor
	rsync -a --delete-after $(VENDOR_DIR)/ $(EMBEDDED_DIR)/apps/core/shared/vendor/
	cd $(EMBEDDED_DIR)/apps/core/releases/$(RELEASE_TIMESTAMP) && ln -snf ../../shared/vendor ./vendor
	# Copy the precompiled assets into place.
	mkdir -p $(EMBEDDED_DIR)/apps/core/shared/src/api-umbrella/web-app/public/web-assets
	rsync -a --delete-after $(WORK_DIR)/tmp/web-assets/ $(EMBEDDED_DIR)/apps/core/shared/src/api-umbrella/web-app/public/web-assets/
	cd $(EMBEDDED_DIR)/apps/core/releases/$(RELEASE_TIMESTAMP)/src/api-umbrella/web-app/public && ln -snf ../../../../../../shared/src/api-umbrella/web-app/public/web-assets ./web-assets
	# Re-run the bundle install inside the release directory, but disabling
	# non-production gem groups. Combined with the clean flag, this deletes all
	# the test/development/asset gems we don't need for a release.
	cd $(EMBEDDED_DIR)/apps/core/releases/$(RELEASE_TIMESTAMP)/src/api-umbrella/web-app && PATH=$(EMBEDDED_DIR)/bin:$(PATH) bundle install --path=../../../vendor/bundle --clean --without="development test assets" --deployment
	# Purge a bunch of content out of the bundler results to make for a lighter
	# release distribution. Purge gem caches, embedded test files, and
	# intermediate files used when compiling C gems from source. Also delete some
	# of the duplicate .so library files for C extensions (we should only need
	# the ones in the "extensions" directory, the rest are duplicates for legacy
	# purposes).
	cd $(EMBEDDED_DIR)/apps/core/shared/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec
	#cd $(EMBEDDED_DIR)/apps/core/shared/vendor/bundle && find ruby/*/gems -name "*.so" -delete
	# Setup a shared symlink for web-app temp files.
	mkdir -p $(EMBEDDED_DIR)/apps/core/shared/src/api-umbrella/web-app/tmp
	cd $(EMBEDDED_DIR)/apps/core/releases/$(RELEASE_TIMESTAMP)/src/api-umbrella/web-app && ln -snf ../../../../../shared/src/api-umbrella/web-app/tmp ./tmp
	touch $@

# api-umbrella-static-site
$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz: | $(DEPS_DIR)
	$(call download,API_UMBRELLA_STATIC_SITE)

$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE): $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz
	$(call decompress,API_UMBRELLA_STATIC_SITE)

$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/.built: $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE) | $(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER)
	cd $< && PATH=$(EMBEDDED_DIR)/bin:$(PATH) bundle install --path=$(BUNDLE_DIR)
	cd $< && PATH=$(EMBEDDED_DIR)/bin:$(PATH) bundle exec middleman build
	touch $@

$(STAGE_MARKERS_DIR)/$(API_UMBRELLA_STATIC_SITE_INSTALL_MARKER): $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/.built | $(STAGE_MARKERS_DIR)
	rm -rf $(EMBEDDED_DIR)/apps/static-site/releases
	mkdir -p $(EMBEDDED_DIR)/apps/static-site/releases/$(RELEASE_TIMESTAMP)/build
	rsync -a $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/build/ $(EMBEDDED_DIR)/apps/static-site/releases/$(RELEASE_TIMESTAMP)/build/
	cd $(EMBEDDED_DIR)/apps/static-site && ln -snf releases/$(RELEASE_TIMESTAMP) ./current
	rm -f $(STAGE_MARKERS_DIR)/$(API_UMBRELLA_STATIC_SITE_NAME)$(VERSION_SEP)*
	touch $@

# Bundler
$(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER): | $(STAGE_MARKERS_DIR) $(STAGE_MARKERS_DIR)/$(RUBY_INSTALL_MARKER)
	PATH=$(EMBEDDED_DIR)/bin:$(PATH) gem install bundler -v '$(BUNDLER_VERSION)' --no-rdoc --no-ri --env-shebang
	rm -f $(STAGE_MARKERS_DIR)/$(BUNDLER_NAME)$(VERSION_SEP)*
	touch $@

# ElasticSearch
$(DEPS_DIR)/$(ELASTICSEARCH).tar.gz: | $(DEPS_DIR)
	$(call download,ELASTICSEARCH)

$(DEPS_DIR)/$(ELASTICSEARCH): $(DEPS_DIR)/$(ELASTICSEARCH).tar.gz
	$(call decompress,ELASTICSEARCH)

$(STAGE_MARKERS_DIR)/$(ELASTICSEARCH_INSTALL_MARKER): $(DEPS_DIR)/$(ELASTICSEARCH) | $(STAGE_MARKERS_DIR)
	mkdir -p $(EMBEDDED_DIR)/elasticsearch
	rsync -a $(DEPS_DIR)/$(ELASTICSEARCH)/ $(EMBEDDED_DIR)/elasticsearch/
	cd $(EMBEDDED_DIR)/bin && ln -snf ../elasticsearch/bin/plugin ./plugin
	cd $(EMBEDDED_DIR)/bin && ln -snf ../elasticsearch/bin/elasticsearch ./elasticsearch
	rm -f $(STAGE_MARKERS_DIR)/$(ELASTICSEARCH_NAME)$(VERSION_SEP)*
	touch $@

# GeoLiteCityv6.dat
$(DEPS_DIR)/GeoLiteCityv6.dat.gz: | $(DEPS_DIR)
	# FIXME: The 20160412 version of the GeoLiteCityv6.dat file is corrupt. This
	# replaces it with the 20160405 version that we happened to still have a copy
	# of. See https://github.com/18F/api.data.gov/issues/327
	#
	# This isn't ideal, and this doesn't fix the auto-updater, but this at least
	# lets us build packages that won't be broken on initial run. We've contacted
	# MaxMind, so hopefully the next release will be fixed.
	curl -L -o $@ https://www.dropbox.com/s/h23d5ef9chulgxf/GeoLiteCityv6.dat.gz?dl=0
	touch $@

$(DEPS_DIR)/GeoLiteCityv6.dat: $(DEPS_DIR)/GeoLiteCityv6.dat.gz
	gunzip -c $< > $@
	touch $@

$(STAGE_MARKERS_DIR)/GeoLiteCityv6.dat: $(DEPS_DIR)/GeoLiteCityv6.dat | $(STAGE_MARKERS_DIR)
	mkdir -p $(EMBEDDED_DIR)/var/db/geoip
	rsync -a $(DEPS_DIR)/GeoLiteCityv6.dat $(EMBEDDED_DIR)/var/db/geoip/city-v6.dat
	touch $@

# Glide
$(DEPS_DIR)/$(GLIDE).tar.gz: | $(DEPS_DIR)
	$(call download,GLIDE)

$(DEPS_DIR)/$(GLIDE): $(DEPS_DIR)/$(GLIDE).tar.gz
	$(call decompress,GLIDE)

$(DEPS_DIR)/gocode/src/github.com/Masterminds/glide: | $(DEPS_DIR)/$(GLIDE)
	mkdir -p $@
	rsync -a --delete-after $(DEPS_DIR)/$(GLIDE)/ $@/
	touch $@

$(DEPS_DIR)/$(GLIDE)/.built: $(DEPS_DIR)/gocode/src/github.com/Masterminds/glide $(DEPS_DIR)/$(GOLANG)
	cd $< && PATH=$(DEPS_DIR)/$(GOLANG)/bin:$(PATH) GOPATH=$(DEPS_DIR)/gocode GOROOT=$(DEPS_DIR)/$(GOLANG) go get
	cd $< && PATH=$(DEPS_DIR)/$(GOLANG)/bin:$(PATH) GOPATH=$(DEPS_DIR)/gocode GOROOT=$(DEPS_DIR)/$(GOLANG) go build
	touch $@

# Go
$(DEPS_DIR)/$(GOLANG).tar.gz: | $(DEPS_DIR)
	$(call download,GOLANG)

$(DEPS_DIR)/$(GOLANG): $(DEPS_DIR)/$(GOLANG).tar.gz
	$(call decompress,GOLANG)

# Heka
$(DEPS_DIR)/$(HEKA).tar.gz: | $(DEPS_DIR)
	$(call download,HEKA)

$(DEPS_DIR)/$(HEKA): $(DEPS_DIR)/$(HEKA).tar.gz
	$(call decompress,HEKA)

$(STAGE_MARKERS_DIR)/$(HEKA_INSTALL_MARKER): $(DEPS_DIR)/$(HEKA) | $(STAGE_MARKERS_DIR)
	mkdir -p $(EMBEDDED_DIR)
	rsync -a $(DEPS_DIR)/$(HEKA)/ $(EMBEDDED_DIR)/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(EMBEDDED_DIR)/bin/heka-cat \
		$(EMBEDDED_DIR)/bin/heka-flood \
		$(EMBEDDED_DIR)/bin/heka-inject \
		$(EMBEDDED_DIR)/bin/heka-sbmgr
	rm -f $(STAGE_MARKERS_DIR)/$(HEKA_NAME)$(VERSION_SEP)*
	touch $@

# libcidr
$(DEPS_DIR)/$(LIBCIDR).tar.xz: | $(DEPS_DIR)
	$(call download,LIBCIDR)

$(DEPS_DIR)/$(LIBCIDR): $(DEPS_DIR)/$(LIBCIDR).tar.xz
	$(call decompress,LIBCIDR)

$(DEPS_DIR)/$(LIBCIDR)/.built: $(DEPS_DIR)/$(LIBCIDR)
	cd $< && make PREFIX=$(PREFIX)/embedded
	touch $@

$(STAGE_MARKERS_DIR)/$(LIBCIDR_INSTALL_MARKER): $(DEPS_DIR)/$(LIBCIDR)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(LIBCIDR) && make install NO_DOCS=1 NO_EXAMPLES=1 PREFIX=$(PREFIX)/embedded DESTDIR=$(STAGE_DIR)
	rm -f $(EMBEDDED_DIR)/bin/cidrcalc
	rm -f $(STAGE_MARKERS_DIR)/$(LIBCIDR_NAME)$(VERSION_SEP)*
	touch $@

# libgeoip
$(DEPS_DIR)/$(LIBGEOIP).tar.gz: | $(DEPS_DIR)
	$(call download,LIBGEOIP)

$(DEPS_DIR)/$(LIBGEOIP): $(DEPS_DIR)/$(LIBGEOIP).tar.gz
	$(call decompress,LIBGEOIP)

$(DEPS_DIR)/$(LIBGEOIP)/.built: $(DEPS_DIR)/$(LIBGEOIP)
	cd $< && LDFLAGS="-Wl,-rpath,$(EMBEDDED_DIR)/lib" ./configure \
		--prefix=$(PREFIX)/embedded
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(LIBGEOIP_INSTALL_MARKER): $(DEPS_DIR)/$(LIBGEOIP)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(LIBGEOIP) && make install DESTDIR=$(STAGE_DIR)
	rm -f $(STAGE_MARKERS_DIR)/$(LIBGEOIP_NAME)$(VERSION_SEP)*
	touch $@

# LuaRocks
$(DEPS_DIR)/$(LUAROCKS).tar.gz: | $(DEPS_DIR)
	$(call download,LUAROCKS)

$(DEPS_DIR)/$(LUAROCKS): $(DEPS_DIR)/$(LUAROCKS).tar.gz
	$(call decompress,LUAROCKS)

$(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER): $(DEPS_DIR)/$(LUAROCKS) | $(STAGE_MARKERS_DIR) $(STAGE_MARKERS_DIR)/$(OPENRESTY_INSTALL_MARKER)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty/luajit \
		--with-lua=$(EMBEDDED_DIR)/openresty/luajit \
		--with-lua-include=$(EMBEDDED_DIR)/openresty/luajit/include/luajit-2.1 \
		--lua-suffix=jit-2.1.0-beta1
	cd $< && make build
	cd $< && make install DESTDIR=$(STAGE_DIR)
	cd $(EMBEDDED_DIR)/bin && ln -snf ../openresty/luajit/bin/luarocks ./luarocks
	rm -f $(STAGE_MARKERS_DIR)/$(LUAROCKS_NAME)$(VERSION_SEP)*
	touch $@

# lua-resty-dns-cache
$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_DNS_CACHE)

$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE): $(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE).tar.gz
	$(call decompress,LUA_RESTY_DNS_CACHE)

$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_DNS_CACHE_INSTALL_MARKER): $(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE) | $(VENDOR_DIR) $(LUA_SHARE_MARKERS_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	rm -f $(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_DNS_CACHE_NAME)$(VERSION_SEP)*
	touch $@

# lua-resty-http
$(DEPS_DIR)/$(LUA_RESTY_HTTP).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_HTTP)

$(DEPS_DIR)/$(LUA_RESTY_HTTP): $(DEPS_DIR)/$(LUA_RESTY_HTTP).tar.gz
	$(call decompress,LUA_RESTY_HTTP)

$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_HTTP_INSTALL_MARKER): $(DEPS_DIR)/$(LUA_RESTY_HTTP) | $(VENDOR_DIR) $(LUA_SHARE_MARKERS_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_HTTP)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	rm -f $(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_HTTP_NAME)$(VERSION_SEP)*
	touch $@

# lua-resty-logger-socket
$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_LOGGER_SOCKET)

$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET): $(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET).tar.gz
	$(call decompress,LUA_RESTY_LOGGER_SOCKET)

$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_LOGGER_SOCKET_INSTALL_MARKER): $(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET) | $(VENDOR_DIR) $(LUA_SHARE_MARKERS_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	rm -f $(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_LOGGER_SOCKET_NAME)$(VERSION_SEP)*
	touch $@

# lua-resty-shcache
$(DEPS_DIR)/$(LUA_RESTY_SHCACHE).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_SHCACHE)

$(DEPS_DIR)/$(LUA_RESTY_SHCACHE): $(DEPS_DIR)/$(LUA_RESTY_SHCACHE).tar.gz
	$(call decompress,LUA_RESTY_SHCACHE)

$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_SHCACHE_INSTALL_MARKER): $(DEPS_DIR)/$(LUA_RESTY_SHCACHE) | $(VENDOR_DIR) $(LUA_SHARE_MARKERS_DIR)
	mkdir -p $(LUA_SHARE_DIR)
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_SHCACHE)/*.lua $(LUA_SHARE_DIR)/
	rm -f $(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_SHCACHE_NAME)$(VERSION_SEP)*
	touch $@

# lua-resty-uuid
$(DEPS_DIR)/$(LUA_RESTY_UUID).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_UUID)

$(DEPS_DIR)/$(LUA_RESTY_UUID): $(DEPS_DIR)/$(LUA_RESTY_UUID).tar.gz
	$(call decompress,LUA_RESTY_UUID)

$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_UUID_INSTALL_MARKER): $(DEPS_DIR)/$(LUA_RESTY_UUID) | $(VENDOR_DIR) $(LUA_SHARE_MARKERS_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_UUID)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	rm -f $(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_UUID_NAME)$(VERSION_SEP)*
	touch $@

# lustache
$(DEPS_DIR)/$(LUSTACHE).tar.gz: | $(DEPS_DIR)
	$(call download,LUSTACHE)

$(DEPS_DIR)/$(LUSTACHE): $(DEPS_DIR)/$(LUSTACHE).tar.gz
	$(call decompress,LUSTACHE)

$(LUA_SHARE_MARKERS_DIR)/$(LUSTACHE_INSTALL_MARKER): $(DEPS_DIR)/$(LUSTACHE) | $(VENDOR_DIR) $(LUA_SHARE_MARKERS_DIR)
	mkdir -p $(LUA_SHARE_DIR)
	rsync -a $(DEPS_DIR)/$(LUSTACHE)/src/ $(LUA_SHARE_DIR)/
	rm -f $(LUA_SHARE_MARKERS_DIR)/$(LUSTACHE_NAME)$(VERSION_SEP)*
	touch $@

# MongoDB
$(DEPS_DIR)/$(MONGODB).tar.gz: | $(DEPS_DIR)
	$(call download,MONGODB)

$(DEPS_DIR)/$(MONGODB): $(DEPS_DIR)/$(MONGODB).tar.gz
	$(call decompress,MONGODB)

$(STAGE_MARKERS_DIR)/$(MONGODB_INSTALL_MARKER): $(DEPS_DIR)/$(MONGODB) | $(STAGE_MARKERS_DIR)
	mkdir -p $(EMBEDDED_DIR)
	rsync -a $(DEPS_DIR)/$(MONGODB)/ $(EMBEDDED_DIR)/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(EMBEDDED_DIR)/bin/bsondump \
		$(EMBEDDED_DIR)/bin/mongoexport \
		$(EMBEDDED_DIR)/bin/mongofiles \
		$(EMBEDDED_DIR)/bin/mongoimport \
		$(EMBEDDED_DIR)/bin/mongooplog \
		$(EMBEDDED_DIR)/bin/mongoperf \
		$(EMBEDDED_DIR)/bin/mongos
	rm -f $(STAGE_MARKERS_DIR)/$(MONGODB_NAME)$(VERSION_SEP)*
	touch $@

# Mora
$(DEPS_DIR)/$(MORA).tar.gz: | $(DEPS_DIR)
	$(call download,MORA)

$(DEPS_DIR)/$(MORA): $(DEPS_DIR)/$(MORA).tar.gz
	$(call decompress,MORA)

$(DEPS_DIR)/gocode/src/github.com/emicklei/mora: | $(DEPS_DIR)/$(MORA)
	mkdir -p $@
	rsync -a --delete-after $(DEPS_DIR)/$(MORA)/ $@/
	touch $@

$(DEPS_DIR)/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM): $(DEPS_DIR)/gocode/src/github.com/emicklei/mora $(DEPS_DIR)/$(GLIDE)/.built $(DEPS_DIR)/$(GOLANG)
	cp $(BUILD_DIR)/mora_glide.yaml $</glide.yaml
	cd $< && PATH=$(DEPS_DIR)/$(GOLANG)/bin:$(DEPS_DIR)/gocode/bin:$(PATH) GOPATH=$(DEPS_DIR)/gocode GOROOT=$(DEPS_DIR)/$(GOLANG) GO15VENDOREXPERIMENT=1 glide update
	cd $< && PATH=$(DEPS_DIR)/$(GOLANG)/bin:$(DEPS_DIR)/gocode/bin:$(PATH) GOPATH=$(DEPS_DIR)/gocode GOROOT=$(DEPS_DIR)/$(GOLANG) GO15VENDOREXPERIMENT=1 go install
	touch $@

$(STAGE_MARKERS_DIR)/$(MORA_INSTALL_MARKER): $(DEPS_DIR)/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM) | $(STAGE_MARKERS_DIR)
	cp $(DEPS_DIR)/gocode/bin/mora $(EMBEDDED_DIR)/bin/
	rm -f $(STAGE_MARKERS_DIR)/$(MORA_NAME)$(VERSION_SEP)*
	touch $@

# ngx_dyups
$(DEPS_DIR)/$(NGX_DYUPS).tar.gz: | $(DEPS_DIR)
	$(call download,NGX_DYUPS)

$(DEPS_DIR)/$(NGX_DYUPS): $(DEPS_DIR)/$(NGX_DYUPS).tar.gz
	$(call decompress,NGX_DYUPS)

# ngx_txid
$(DEPS_DIR)/$(NGX_TXID).tar.gz: | $(DEPS_DIR)
	$(call download,NGX_TXID)

$(DEPS_DIR)/$(NGX_TXID): $(DEPS_DIR)/$(NGX_TXID).tar.gz
	$(call decompress,NGX_TXID)

# OpenResty
$(DEPS_DIR)/$(OPENRESTY).tar.gz: | $(DEPS_DIR)
	$(call download,OPENRESTY)

$(DEPS_DIR)/$(OPENRESTY): $(DEPS_DIR)/$(OPENRESTY).tar.gz
	$(call decompress,OPENRESTY)

$(DEPS_DIR)/$(OPENRESTY)/.built: $(DEPS_DIR)/$(OPENRESTY) $(DEPS_DIR)/$(NGX_DYUPS) $(DEPS_DIR)/$(NGX_TXID) $(STAGE_MARKERS_DIR)/$(LIBGEOIP_INSTALL_MARKER) $(DEPS_DIR)/$(PCRE)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty \
		--with-cc-opt="-I$(EMBEDDED_DIR)/include" \
		--with-ld-opt="-L$(EMBEDDED_DIR)/lib -Wl,-rpath,$(PREFIX)/embedded/lib,-rpath,$(EMBEDDED_DIR)/openresty/luajit/lib,-rpath,$(EMBEDDED_DIR)/lib" \
		--error-log-path=stderr \
		--with-ipv6 \
		--with-pcre=$(DEPS_DIR)/$(PCRE) \
		--with-pcre-opt="-g" \
		--with-pcre-conf-opt="--enable-unicode-properties" \
		--with-pcre-jit \
		--with-http_geoip_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_realip_module \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--add-module=../$(NGX_DYUPS) \
		--add-module=../$(NGX_TXID)
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(OPENRESTY_INSTALL_MARKER): $(DEPS_DIR)/$(OPENRESTY)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(OPENRESTY) && make install DESTDIR=$(STAGE_DIR)
	cd $(EMBEDDED_DIR)/bin && ln -snf ../openresty/bin/resty ./resty
	cd $(EMBEDDED_DIR)/bin && ln -snf ../openresty/luajit/bin/luajit-2.1.0-beta1 ./luajit
	cd $(EMBEDDED_DIR)/sbin && ln -snf ../openresty/nginx/sbin/nginx ./nginx
	rm -f $(STAGE_MARKERS_DIR)/$(OPENRESTY_NAME)$(VERSION_SEP)*
	touch $@

# PCRE
$(DEPS_DIR)/$(PCRE).tar.gz: | $(DEPS_DIR)
	$(call download,PCRE)

$(DEPS_DIR)/$(PCRE): $(DEPS_DIR)/$(PCRE).tar.gz
	$(call decompress,PCRE)

# Perp
$(DEPS_DIR)/$(PERP).tar.gz: | $(DEPS_DIR)
	$(call download,PERP)

$(DEPS_DIR)/$(PERP): $(DEPS_DIR)/$(PERP).tar.gz
	$(call decompress,PERP)

$(DEPS_DIR)/$(PERP)/.built: $(DEPS_DIR)/$(PERP)
	sed -i -e 's#BINDIR.*#BINDIR = $(PREFIX)/embedded/bin#' $</conf.mk
	sed -i -e 's#SBINDIR.*#SBINDIR = $(PREFIX)/embedded/sbin#' $</conf.mk
	sed -i -e 's#MANDIR.*#MANDIR = $(PREFIX)/embedded/share/man#' $</conf.mk
	cd $< && make && make strip
	touch $@

$(STAGE_MARKERS_DIR)/$(PERP_INSTALL_MARKER): $(DEPS_DIR)/$(PERP)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(PERP) && make install DESTDIR=$(STAGE_DIR)
	rm -f $(STAGE_MARKERS_DIR)/$(PERP_NAME)$(VERSION_SEP)*
	touch $@

# Ruby
$(DEPS_DIR)/$(RUBY).tar.bz2: | $(DEPS_DIR)
	$(call download,RUBY)

$(DEPS_DIR)/$(RUBY): $(DEPS_DIR)/$(RUBY).tar.bz2
	$(call decompress,RUBY)

$(DEPS_DIR)/$(RUBY)/.built: | $(DEPS_DIR)/$(RUBY)
	cd $(DEPS_DIR)/$(RUBY) && ./configure \
		--prefix=$(PREFIX)/embedded \
		--enable-load-relative \
		--disable-install-doc
	cd $(DEPS_DIR)/$(RUBY) && make
	touch $@

$(STAGE_MARKERS_DIR)/$(RUBY_INSTALL_MARKER): $(DEPS_DIR)/$(RUBY)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(RUBY) && make install DESTDIR=$(STAGE_DIR)
	rm -f $(STAGE_MARKERS_DIR)/$(RUBY_NAME)$(VERSION_SEP)*
	touch $@

# runit
$(DEPS_DIR)/$(RUNIT).tar.gz: | $(DEPS_DIR)
	$(call download,RUNIT)

$(DEPS_DIR)/$(RUNIT): $(DEPS_DIR)/$(RUNIT).tar.gz
	$(call decompress,RUNIT,2)

$(DEPS_DIR)/$(RUNIT)/.built: | $(DEPS_DIR)/$(RUNIT)
	cd $(DEPS_DIR)/$(RUNIT)/src && make svlogd
	touch $@

$(STAGE_MARKERS_DIR)/$(RUNIT_INSTALL_MARKER): $(DEPS_DIR)/$(RUNIT)/.built | $(STAGE_MARKERS_DIR)
	mkdir -p $(EMBEDDED_DIR)/bin
	rsync -a $(DEPS_DIR)/$(RUNIT)/src/svlogd $(EMBEDDED_DIR)/bin/svlogd
	touch $@

# TrafficServer
$(DEPS_DIR)/$(TRAFFICSERVER).tar.gz: | $(DEPS_DIR)
	$(call download,TRAFFICSERVER)

$(DEPS_DIR)/$(TRAFFICSERVER): $(DEPS_DIR)/$(TRAFFICSERVER).tar.gz
	$(call decompress,TRAFFICSERVER)

$(DEPS_DIR)/$(TRAFFICSERVER)/.built: $(DEPS_DIR)/$(TRAFFICSERVER)
	cd $< && PATH=$(STANDARD_PATH) LDFLAGS="-Wl,-rpath,$(EMBEDDED_DIR)/lib" ./configure \
		--prefix=$(PREFIX)/embedded \
		--enable-experimental-plugins
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(TRAFFICSERVER_INSTALL_MARKER): $(DEPS_DIR)/$(TRAFFICSERVER)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(TRAFFICSERVER) && make install DESTDIR=$(STAGE_DIR)
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(EMBEDDED_DIR)/bin/traffic_sac
	rm -f $(STAGE_MARKERS_DIR)/$(TRAFFICSERVER_NAME)$(VERSION_SEP)*
	touch $@

# Unbound
$(DEPS_DIR)/$(UNBOUND).tar.gz: | $(DEPS_DIR)
	$(call download,UNBOUND)

$(DEPS_DIR)/$(UNBOUND): $(DEPS_DIR)/$(UNBOUND).tar.gz
	$(call decompress,UNBOUND)

$(DEPS_DIR)/$(UNBOUND)/.built: $(DEPS_DIR)/$(UNBOUND)
	cd $< && ./configure \
		--prefix=$(TEST_PREFIX)
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(UNBOUND_INSTALL_MARKER): $(DEPS_DIR)/$(UNBOUND)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(UNBOUND) && make install DESTDIR=$(STAGE_DIR)
	touch $@

# LuaRocks - argparse
$(LUAROCKS_DIR)/$(ARGPARSE)/$(ARGPARSE_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,ARGPARSE)

# LuaRocks - inspect
$(LUAROCKS_DIR)/$(INSPECT)/$(INSPECT_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,INSPECT)

# LuaRocks - libcidr-ffi
$(LUAROCKS_DIR)/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION): | $(VENDOR_DIR)
	$(LUAROCKS_CMD) --tree=$(VENDOR_DIR) install $(LIBCIDR_FFI) $(LIBCIDR_FFI_VERSION) CIDR_DIR=$(EMBEDDED_DIR)
	touch $@

# LuaRocks - lua-cmsgpack
$(LUAROCKS_DIR)/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,LUA_CMSGPACK)

# LuaRocks - lua-iconv
$(LUAROCKS_DIR)/$(LUA_ICONV)/$(LUA_ICONV_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,LUA_ICONV)

# LuaRocks - luacheck
$(TEST_LUAROCKS_DIR)/$(LUACHECK)/$(LUACHECK_VERSION): | $(TEST_VENDOR_DIR)
	$(call test_luarocks_install,LUACHECK)

# LuaRocks - luaposix
$(LUAROCKS_DIR)/$(LUAPOSIX)/$(LUAPOSIX_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,LUAPOSIX)

# LuaRocks - luasocket
$(LUAROCKS_DIR)/$(LUASOCKET)/$(LUASOCKET_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,LUASOCKET)

# LuaRocks - lyaml
$(LUAROCKS_DIR)/$(LYAML)/$(LYAML_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,LYAML)

# LuaRocks - penlight
$(LUAROCKS_DIR)/$(PENLIGHT)/$(PENLIGHT_VERSION): | $(VENDOR_DIR)
	$(call luarocks_install,PENLIGHT)

.SECONDARY: \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE) \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/.built \
	$(DEPS_DIR)/$(ELASTICSEARCH).tar.gz \
	$(DEPS_DIR)/$(ELASTICSEARCH) \
	$(DEPS_DIR)/GeoLiteCityv6.dat.gz \
	$(DEPS_DIR)/GeoLiteCityv6.dat \
	$(DEPS_DIR)/$(GLIDE).tar.gz \
	$(DEPS_DIR)/$(GLIDE) \
	$(DEPS_DIR)/gocode/src/github.com/Masterminds/glide \
	$(DEPS_DIR)/$(GLIDE)/.built \
	$(DEPS_DIR)/$(GOLANG).tar.gz \
	$(DEPS_DIR)/$(GOLANG) \
	$(DEPS_DIR)/$(HEKA).tar.gz \
	$(DEPS_DIR)/$(HEKA) \
	$(DEPS_DIR)/$(LIBCIDR).tar.xz \
	$(DEPS_DIR)/$(LIBCIDR) \
	$(DEPS_DIR)/$(LIBCIDR)/.built \
	$(DEPS_DIR)/$(LIBGEOIP).tar.gz \
	$(DEPS_DIR)/$(LIBGEOIP) \
	$(DEPS_DIR)/$(LIBGEOIP)/.built \
	$(DEPS_DIR)/$(LUAROCKS).tar.gz \
	$(DEPS_DIR)/$(LUAROCKS) \
	$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE) \
	$(DEPS_DIR)/$(LUA_RESTY_HTTP).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_HTTP) \
	$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET) \
	$(DEPS_DIR)/$(LUA_RESTY_SHCACHE).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_SHCACHE) \
	$(DEPS_DIR)/$(LUA_RESTY_UUID).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_UUID) \
	$(DEPS_DIR)/$(LUSTACHE).tar.gz \
	$(DEPS_DIR)/$(LUSTACHE) \
	$(DEPS_DIR)/$(MONGODB).tar.gz \
	$(DEPS_DIR)/$(MONGODB) \
	$(DEPS_DIR)/$(MORA).tar.gz \
	$(DEPS_DIR)/$(MORA) \
	$(DEPS_DIR)/gocode/src/github.com/emicklei/mora \
	$(DEPS_DIR)/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM) \
	$(DEPS_DIR)/$(NGX_DYUPS).tar.gz \
	$(DEPS_DIR)/$(NGX_DYUPS) \
	$(DEPS_DIR)/$(NGX_TXID).tar.gz \
	$(DEPS_DIR)/$(NGX_TXID) \
	$(DEPS_DIR)/$(OPENRESTY).tar.gz \
	$(DEPS_DIR)/$(OPENRESTY) \
	$(DEPS_DIR)/$(OPENRESTY)/.built \
	$(DEPS_DIR)/$(PCRE).tar.gz \
	$(DEPS_DIR)/$(PCRE) \
	$(DEPS_DIR)/$(PERP).tar.gz \
	$(DEPS_DIR)/$(PERP) \
	$(DEPS_DIR)/$(PERP)/.built \
	$(DEPS_DIR)/$(RUBY).tar.bz2 \
	$(DEPS_DIR)/$(RUBY) \
	$(DEPS_DIR)/$(RUBY)/.built \
	$(DEPS_DIR)/$(RUNIT).tar.gz \
	$(DEPS_DIR)/$(RUNIT) \
	$(DEPS_DIR)/$(RUNIT)/.built \
	$(DEPS_DIR)/$(TRAFFICSERVER).tar.gz \
	$(DEPS_DIR)/$(TRAFFICSERVER) \
	$(DEPS_DIR)/$(TRAFFICSERVER)/.built \
	$(DEPS_DIR)/$(UNBOUND).tar.gz \
	$(DEPS_DIR)/$(UNBOUND) \
	$(DEPS_DIR)/$(UNBOUND)/.built

download_deps: \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz \
	$(DEPS_DIR)/$(ELASTICSEARCH).tar.gz \
	$(DEPS_DIR)/GeoLiteCityv6.dat.gz \
	$(DEPS_DIR)/$(GLIDE).tar.gz \
	$(DEPS_DIR)/$(GOLANG).tar.gz \
	$(DEPS_DIR)/$(HEKA).tar.gz \
	$(DEPS_DIR)/$(LIBCIDR).tar.xz \
	$(DEPS_DIR)/$(LIBGEOIP).tar.gz \
	$(DEPS_DIR)/$(LUAROCKS).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_HTTP).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_SHCACHE).tar.gz \
	$(DEPS_DIR)/$(LUA_RESTY_UUID).tar.gz \
	$(DEPS_DIR)/$(LUSTACHE).tar.gz \
	$(DEPS_DIR)/$(MONGODB).tar.gz \
	$(DEPS_DIR)/$(MORA).tar.gz \
	$(DEPS_DIR)/$(NGX_DYUPS).tar.gz \
	$(DEPS_DIR)/$(NGX_TXID).tar.gz \
	$(DEPS_DIR)/$(OPENRESTY).tar.gz \
	$(DEPS_DIR)/$(PCRE).tar.gz \
	$(DEPS_DIR)/$(PERP).tar.gz \
	$(DEPS_DIR)/$(RUBY).tar.bz2 \
	$(DEPS_DIR)/$(RUNIT).tar.gz \
	$(DEPS_DIR)/$(TRAFFICSERVER).tar.gz

$(VENDOR_DIR):
	mkdir -p $@

$(ROOT_DIR)/vendor: | $(VENDOR_DIR)
	ln -snf $(VENDOR_DIR) $(ROOT_DIR)/vendor

$(TEST_VENDOR_DIR):
	mkdir -p $@

$(WORK_DIR):
	mkdir -p $@

$(BUILD_DIR)/local: | $(WORK_DIR)
	ln -snf $(WORK_DIR) $(BUILD_DIR)/local

LUA_VENDOR_DEPS:= $(LUAROCKS_DIR)/$(ARGPARSE)/$(ARGPARSE_VERSION) \
	$(LUAROCKS_DIR)/$(INSPECT)/$(INSPECT_VERSION) \
	$(LUAROCKS_DIR)/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION) \
	$(LUAROCKS_DIR)/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION) \
	$(LUAROCKS_DIR)/$(LUA_ICONV)/$(LUA_ICONV_VERSION) \
	$(LUAROCKS_DIR)/$(LUAPOSIX)/$(LUAPOSIX_VERSION) \
	$(LUAROCKS_DIR)/$(LUASOCKET)/$(LUASOCKET_VERSION) \
	$(LUAROCKS_DIR)/$(LYAML)/$(LYAML_VERSION) \
	$(LUAROCKS_DIR)/$(PENLIGHT)/$(PENLIGHT_VERSION) \
	$(LUAROCKS_DIR)/$(UUID)/$(UUID_VERSION) \
	$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_DNS_CACHE_INSTALL_MARKER) \
	$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_HTTP_INSTALL_MARKER) \
	$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_LOGGER_SOCKET_INSTALL_MARKER) \
	$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_SHCACHE_INSTALL_MARKER) \
	$(LUA_SHARE_MARKERS_DIR)/$(LUA_RESTY_UUID_INSTALL_MARKER) \
	$(LUA_SHARE_MARKERS_DIR)/$(LUSTACHE_INSTALL_MARKER)

install_lua_vendor_deps: $(LUA_VENDOR_DEPS) | $(VENDOR_DIR)

$(STAGE_MARKERS_DIR)/api-umbrella-core-lua-dependencies: \
	$(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LIBCIDR_INSTALL_MARKER) \
	$(LUA_VENDOR_DEPS) | $(VENDOR_DIR)
	touch $@

$(STAGE_MARKERS_DIR)/api-umbrella-core-dependencies: \
	$(STAGE_MARKERS_DIR)/api-umbrella-core-web-assets$(VERSION_SEP)$(WEB_ASSETS_CHECKSUM) \
	$(STAGE_MARKERS_DIR)/api-umbrella-core-web-bundled \
	$(STAGE_MARKERS_DIR)/api-umbrella-core-lua-dependencies \
	$(ROOT_DIR)/vendor | $(STAGE_MARKERS_DIR)
	touch $@

stage: \
	$(EMBEDDED_DIR)/bin \
	$(EMBEDDED_DIR)/sbin \
	$(STAGE_MARKERS_DIR)/api-umbrella-core \
	$(STAGE_MARKERS_DIR)/$(API_UMBRELLA_STATIC_SITE_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(ELASTICSEARCH_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/GeoLiteCityv6.dat \
	$(STAGE_MARKERS_DIR)/$(HEKA_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LIBCIDR_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LIBGEOIP_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(MONGODB_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(MORA_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(OPENRESTY_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(PERP_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(RUBY_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(RUNIT_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(TRAFFICSERVER_INSTALL_MARKER) \
	$(BUILD_DIR)/local

install: stage
	mkdir -p $(DESTDIR)/usr/bin $(DESTDIR)/var/log $(DESTDIR)$(PREFIX)/etc $(DESTDIR)$(PREFIX)/var/db $(DESTDIR)$(PREFIX)/var/log $(DESTDIR)$(PREFIX)/var/run $(DESTDIR)$(PREFIX)/var/tmp
	rsync -rltDv $(STAGE_PREFIX)/bin/ $(DESTDIR)$(PREFIX)/bin/
	rsync -rltDv $(EMBEDDED_DIR)/ $(DESTDIR)$(PREFIX)/embedded/
	sed -i 's#$(STAGE_DIR)##g' $(DESTDIR)$(PREFIX)/embedded/openresty/luajit/bin/luarocks-5.1 $(DESTDIR)$(PREFIX)/embedded/openresty/luajit/bin/luarocks-admin-5.1 $(DESTDIR)$(PREFIX)/embedded/openresty/luajit/share/lua/5.1/luarocks/site_config.lua
	install --backup=numbered -D -m 644 $(BUILD_DIR)/package/files/etc/api-umbrella/api-umbrella.yml $(DESTDIR)/etc/api-umbrella/api-umbrella.yml
	install -D -m 755 $(BUILD_DIR)/package/files/etc/init.d/api-umbrella $(DESTDIR)/etc/init.d/api-umbrella
	install -D -m 644 $(BUILD_DIR)/package/files/etc/logrotate.d/api-umbrella $(DESTDIR)/etc/logrotate.d/api-umbrella
	install -D -m 440 $(BUILD_DIR)/package/files/etc/sudoers.d/api-umbrella $(DESTDIR)/etc/sudoers.d/api-umbrella
	cd $(DESTDIR)/usr/bin && ln -snf ../..$(PREFIX)/bin/api-umbrella ./api-umbrella
	cd $(DESTDIR)/var/log && ln -snf ../..$(PREFIX)/var/log ./api-umbrella
	chmod 1777 $(DESTDIR)$(PREFIX)/var/tmp
	chmod 775 $(DESTDIR)$(PREFIX)/embedded/apps/core/shared/src/api-umbrella/web-app/tmp

after_install:
	$(BUILD_DIR)/package/scripts/after-install

# Node test dependencies
$(ROOT_DIR)/test/node_modules/.installed: $(ROOT_DIR)/test/package.json
	mkdir -p $(WORK_DIR)/test-env/node_modules
	cd $(ROOT_DIR)/test && ln -snf $(WORK_DIR)/test-env/node_modules ./node_modules
	cd $(ROOT_DIR)/test && npm install
	cd $(ROOT_DIR)/test && npm prune
	touch $@

# Python test dependencies (mongo-orchestration)
$(TEST_STAGE_PREFIX)/bin/pip:
	virtualenv $(TEST_STAGE_PREFIX)
	touch $@

$(STAGE_MARKERS_DIR)/test-python-requirements: $(ROOT_DIR)/test/requirements.txt $(TEST_STAGE_PREFIX)/bin/pip | $(STAGE_MARKERS_DIR)
	$(TEST_STAGE_PREFIX)/bin/pip install -r $(ROOT_DIR)/test/requirements.txt
	touch $@

test_dependencies: \
	$(ROOT_DIR)/test/node_modules/.installed \
	$(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) \
	$(TEST_LUAROCKS_DIR)/$(LUACHECK)/$(LUACHECK_VERSION) \
	$(STAGE_MARKERS_DIR)/test-python-requirements \
	$(STAGE_MARKERS_DIR)/$(UNBOUND_INSTALL_MARKER)

lint: test_dependencies
	LUA_PATH="$(TEST_LUA_SHARE_DIR)/?.lua;$(TEST_LUA_SHARE_DIR)/?/init.lua;;" LUA_CPATH="$(TEST_LUA_LIB_DIR)/?.so;;" $(TEST_VENDOR_DIR)/bin/luacheck $(ROOT_DIR)/src

test: stage test_dependencies lint
	cd test && MOCHA_FILES="$(MOCHA_FILES)" npm test

clean:
	rm -rf $(WORK_DIR) $(ROOT_DIR)/vendor $(BUILD_DIR)/local $(ROOT_DIR)/test/node_modules $(ROOT_DIR)/src/api-umbrella/web-app/.bundle $(ROOT_DIR)/src/api-umbrella/web-app/tmp $(ROOT_DIR)/src/api-umbrella/web-app/log

check_shared_objects:
	find $(EMBEDDED_DIR) -type f | xargs ldd 2>&1 | grep " => " | grep -o "^[^(]*" | sort | uniq

$(DEPS_DIR)/verify_package/centos-6/api-umbrella-0.8.0-1.el6.x86_64.rpm:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ http://sourceforge.net/projects/api-umbrella/files/el/6/api-umbrella-0.8.0-1.el6.x86_64.rpm/download

$(DEPS_DIR)/verify_package/centos-6/api-umbrella-0.9.0-1.el6.x86_64.rpm:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-el6/api-umbrella-0.9.0-1.el6.x86_64.rpm

$(DEPS_DIR)/verify_package/centos-6/api-umbrella-0.10.0-1.el6.x86_64.rpm:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-el6/api-umbrella-0.10.0-1.el6.x86_64.rpm

$(DEPS_DIR)/verify_package/centos-7/api-umbrella-0.8.0-1.el7.x86_64.rpm:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ http://sourceforge.net/projects/api-umbrella/files/el/7/api-umbrella-0.8.0-1.el7.x86_64.rpm/download

$(DEPS_DIR)/verify_package/centos-7/api-umbrella-0.9.0-1.el7.x86_64.rpm:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-el7/api-umbrella-0.9.0-1.el7.x86_64.rpm

$(DEPS_DIR)/verify_package/centos-7/api-umbrella-0.10.0-1.el7.x86_64.rpm:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-el7/api-umbrella-0.10.0-1.el7.x86_64.rpm

$(DEPS_DIR)/verify_package/ubuntu-12.04/api-umbrella_0.8.0-1_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ http://sourceforge.net/projects/api-umbrella/files/ubuntu/12.04/api-umbrella_0.8.0-1_amd64.deb/download

$(DEPS_DIR)/verify_package/ubuntu-12.04/api-umbrella_0.9.0-1~precise_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-ubuntu/pool/main/a/api-umbrella/api-umbrella_0.9.0-1%7Eprecise_amd64.deb

$(DEPS_DIR)/verify_package/ubuntu-12.04/api-umbrella_0.10.0-1~precise_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-ubuntu/pool/main/a/api-umbrella/api-umbrella_0.10.0-1%7Eprecise_amd64.deb

$(DEPS_DIR)/verify_package/ubuntu-14.04/api-umbrella_0.8.0-1_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ http://sourceforge.net/projects/api-umbrella/files/ubuntu/14.04/api-umbrella_0.8.0-1_amd64.deb/download

$(DEPS_DIR)/verify_package/ubuntu-14.04/api-umbrella_0.9.0-1~trusty_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-ubuntu/pool/main/a/api-umbrella/api-umbrella_0.9.0-1%7Etrusty_amd64.deb

$(DEPS_DIR)/verify_package/ubuntu-14.04/api-umbrella_0.10.0-1~trusty_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-ubuntu/pool/main/a/api-umbrella/api-umbrella_0.10.0-1%7Etrusty_amd64.deb

$(DEPS_DIR)/verify_package/debian-7/api-umbrella_0.8.0-1_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ http://sourceforge.net/projects/api-umbrella/files/debian/7/api-umbrella_0.8.0-1_amd64.deb/download

$(DEPS_DIR)/verify_package/debian-7/api-umbrella_0.9.0-1~wheezy_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-debian/pool/main/a/api-umbrella/api-umbrella_0.9.0-1%7Ewheezy_amd64.deb

$(DEPS_DIR)/verify_package/debian-7/api-umbrella_0.10.0-1~wheezy_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-debian/pool/main/a/api-umbrella/api-umbrella_0.10.0-1%7Ewheezy_amd64.deb

$(DEPS_DIR)/verify_package/debian-8/api-umbrella_0.9.0-1~jessie_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-debian/pool/main/a/api-umbrella/api-umbrella_0.9.0-1%7Ejessie_amd64.deb

$(DEPS_DIR)/verify_package/debian-8/api-umbrella_0.10.0-1~jessie_amd64.deb:
	mkdir -p $(shell dirname $@)
	curl -L -o $@ https://bintray.com/artifact/download/nrel/api-umbrella-debian/pool/main/a/api-umbrella/api-umbrella_0.10.0-1%7Ejessie_amd64.deb

download_verify_package_deps: \
	$(DEPS_DIR)/verify_package/centos-6/api-umbrella-0.8.0-1.el6.x86_64.rpm \
	$(DEPS_DIR)/verify_package/centos-6/api-umbrella-0.9.0-1.el6.x86_64.rpm \
	$(DEPS_DIR)/verify_package/centos-6/api-umbrella-0.10.0-1.el6.x86_64.rpm \
	$(DEPS_DIR)/verify_package/centos-7/api-umbrella-0.8.0-1.el7.x86_64.rpm \
	$(DEPS_DIR)/verify_package/centos-7/api-umbrella-0.9.0-1.el7.x86_64.rpm \
	$(DEPS_DIR)/verify_package/centos-7/api-umbrella-0.10.0-1.el7.x86_64.rpm \
	$(DEPS_DIR)/verify_package/ubuntu-12.04/api-umbrella_0.8.0-1_amd64.deb \
	$(DEPS_DIR)/verify_package/ubuntu-12.04/api-umbrella_0.9.0-1~precise_amd64.deb \
	$(DEPS_DIR)/verify_package/ubuntu-12.04/api-umbrella_0.10.0-1~precise_amd64.deb \
	$(DEPS_DIR)/verify_package/ubuntu-14.04/api-umbrella_0.8.0-1_amd64.deb \
	$(DEPS_DIR)/verify_package/ubuntu-14.04/api-umbrella_0.9.0-1~trusty_amd64.deb \
	$(DEPS_DIR)/verify_package/ubuntu-14.04/api-umbrella_0.10.0-1~trusty_amd64.deb \
	$(DEPS_DIR)/verify_package/debian-7/api-umbrella_0.8.0-1_amd64.deb \
	$(DEPS_DIR)/verify_package/debian-7/api-umbrella_0.9.0-1~wheezy_amd64.deb \
	$(DEPS_DIR)/verify_package/debian-7/api-umbrella_0.10.0-1~wheezy_amd64.deb \
	$(DEPS_DIR)/verify_package/debian-8/api-umbrella_0.9.0-1~jessie_amd64.deb \
	$(DEPS_DIR)/verify_package/debian-8/api-umbrella_0.10.0-1~jessie_amd64.deb

package:
	$(BUILD_DIR)/package/build

verify_package: download_verify_package_deps
	$(BUILD_DIR)/verify_package/run

package_docker_centos6: download_deps download_verify_package_deps
	DIST=centos-6 $(BUILD_DIR)/package/build_and_verify_with_docker

package_docker_centos6_logged:
	DIST=centos-6 $(BUILD_DIR)/package/build_and_verify_with_docker_logged

verify_package_docker_centos6: download_deps download_verify_package_deps
	DIST=centos-6 $(BUILD_DIR)/verify_package/run_with_docker

package_docker_centos7: download_deps download_verify_package_deps
	DIST=centos-7 $(BUILD_DIR)/package/build_and_verify_with_docker

package_docker_centos7_logged:
	DIST=centos-7 $(BUILD_DIR)/package/build_and_verify_with_docker_logged

verify_package_docker_centos7: download_deps download_verify_package_deps
	DIST=centos-7 $(BUILD_DIR)/verify_package/run_with_docker

package_docker_ubuntu1204: download_deps download_verify_package_deps
	DIST=ubuntu-12.04 $(BUILD_DIR)/package/build_and_verify_with_docker

package_docker_ubuntu1204_logged:
	DIST=ubuntu-12.04 $(BUILD_DIR)/package/build_and_verify_with_docker_logged

verify_package_docker_ubuntu1204: download_deps download_verify_package_deps
	DIST=ubuntu-12.04 $(BUILD_DIR)/verify_package/run_with_docker

package_docker_ubuntu1404: download_deps download_verify_package_deps
	DIST=ubuntu-14.04 $(BUILD_DIR)/package/build_and_verify_with_docker

package_docker_ubuntu1404_logged: download_deps download_verify_package_deps
	DIST=ubuntu-14.04 $(BUILD_DIR)/package/build_and_verify_with_docker_logged

verify_package_docker_ubuntu1404: download_deps download_verify_package_deps
	DIST=ubuntu-14.04 $(BUILD_DIR)/verify_package/run_with_docker

package_docker_debian7: download_deps download_verify_package_deps
	DIST=debian-7 $(BUILD_DIR)/package/build_and_verify_with_docker

package_docker_debian7_logged: download_deps download_verify_package_deps
	DIST=debian-7 $(BUILD_DIR)/package/build_and_verify_with_docker_logged

verify_package_docker_debian7: download_deps download_verify_package_deps
	DIST=debian-7 $(BUILD_DIR)/verify_package/run_with_docker

package_docker_debian8: download_deps download_verify_package_deps
	DIST=debian-8 $(BUILD_DIR)/package/build_and_verify_with_docker

package_docker_debian8_logged: download_deps download_verify_package_deps
	DIST=debian-8 $(BUILD_DIR)/package/build_and_verify_with_docker_logged

verify_package_docker_debian8: download_deps download_verify_package_deps
	DIST=debian-8 $(BUILD_DIR)/verify_package/run_with_docker

all_packages: \
	download_deps \
	package_docker_centos6_logged \
	package_docker_centos7_logged \
	package_docker_ubuntu1204_logged \
	package_docker_ubuntu1404_logged \
	package_docker_debian7_logged \
	package_docker_debian8_logged

publish_all_packages:
	$(BUILD_DIR)/package/publish

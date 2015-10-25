# Unexport all make variables to prevent passing our own make variables down to
# sub-processes.
#
# Since the bulk of what we're doing is building other projects, this prevents
# odd issues from cropping up when building other projects and those picking up
# our own DESTDIR or other variables that the child projects might happen to
# use (BUILD_DIR, etc).
unexport
MAKEOVERRIDES=

STANDARD_PATH:=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin
PREFIX:=/opt/api-umbrella
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR:=$(ROOT_DIR)/build
WORK_DIR:=$(BUILD_DIR)/work
DEPS_DIR:=$(WORK_DIR)/deps
STAGE_DIR:=$(WORK_DIR)/stage
STAGE_PREFIX:=$(STAGE_DIR)$(PREFIX)
STAGE_MARKERS_DIR:=$(STAGE_DIR)/.installed
VENDOR_DIR:=$(WORK_DIR)/vendor
BUNDLE_DIR:=$(VENDOR_DIR)/bundle
LUAROCKS_DIR:=$(VENDOR_DIR)/lib/luarocks/rocks
LUAROCKS_CMD:=LUA_PATH="$(STAGE_PREFIX)/embedded/openresty/luajit/share/lua/5.1/?.lua;$(STAGE_PREFIX)/embedded/openresty/luajit/share/lua/5.1/?/init.lua;;" $(STAGE_PREFIX)/embedded/bin/luarocks
LUA_SHARE_DIR:=$(VENDOR_DIR)/share/lua/5.1
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
API_UMBRELLA_STATIC_SITE_VERSION:=48d3d4379bb29ca37cd4e25900e793aafe0ca414
API_UMBRELLA_STATIC_SITE_NAME:=api-umbrella-static-site
API_UMBRELLA_STATIC_SITE:=$(API_UMBRELLA_STATIC_SITE_NAME)-$(API_UMBRELLA_STATIC_SITE_VERSION)
API_UMBRELLA_STATIC_SITE_DIGEST:=md5
API_UMBRELLA_STATIC_SITE_CHECKSUM:=9bcc73c1febd6d7a5aec3a6cc5e940e9
API_UMBRELLA_STATIC_SITE_URL:=https://github.com/NREL/api-umbrella-static-site/archive/$(API_UMBRELLA_STATIC_SITE_VERSION).tar.gz
API_UMBRELLA_STATIC_SITE_INSTALL_MARKER:=$(API_UMBRELLA_STATIC_SITE_NAME)$(VERSION_SEP)$(API_UMBRELLA_STATIC_SITE_VERSION)

BUNDLER_VERSION:=1.10.6
BUNDLER_NAME:=bundler
BUNDLER:=$(BUNDLER_NAME)-$(BUNDLER_VERSION)
BUNDLER_INSTALL_MARKER:=$(BUNDLER_NAME)$(VERSION_SEP)$(BUNDLER_VERSION)

ELASTICSEARCH_VERSION:=1.7.3
ELASTICSEARCH_NAME:=elasticsearch
ELASTICSEARCH:=$(ELASTICSEARCH_NAME)-$(ELASTICSEARCH_VERSION)
ELASTICSEARCH_DIGEST:=sha1
ELASTICSEARCH_CHECKSUM:=754b089ec0a1aae5b36b39391d5385ed7428d8f5
ELASTICSEARCH_URL:=https://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-$(ELASTICSEARCH_VERSION).tar.gz
ELASTICSEARCH_INSTALL_MARKER:=$(ELASTICSEARCH_NAME)$(VERSION_SEP)$(ELASTICSEARCH_VERSION)

GLIDE_VERSION:=0.6.1
GLIDE_NAME:=glide
GLIDE:=$(GLIDE_NAME)-$(GLIDE_VERSION)
GLIDE_DIGEST:=md5
GLIDE_CHECKSUM:=9067182f14b510015ffc30eae9a5329e
GLIDE_URL:=https://github.com/Masterminds/glide/archive/$(GLIDE_VERSION).tar.gz
GLIDE_INSTALL_MARKER:=$(GLIDE_NAME)$(VERSION_SEP)$(GLIDE_VERSION)

GOLANG_VERSION:=1.5.1
GOLANG_NAME:=golang
GOLANG:=$(GOLANG_NAME)-$(GOLANG_VERSION)
GOLANG_DIGEST:=sha1
GOLANG_CHECKSUM:=46eecd290d8803887dec718c691cc243f2175fe0
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

LIBMAXMINDDB_VERSION:=1.1.1
LIBMAXMINDDB_NAME:=libmaxminddb
LIBMAXMINDDB:=$(LIBMAXMINDDB_NAME)-$(LIBMAXMINDDB_VERSION)
LIBMAXMINDDB_DIGEST:=md5
LIBMAXMINDDB_CHECKSUM:=36c31f0814dbf71b210ee57c2b9ef98c
LIBMAXMINDDB_URL:=https://github.com/maxmind/libmaxminddb/releases/download/$(LIBMAXMINDDB_VERSION)/libmaxminddb-$(LIBMAXMINDDB_VERSION).tar.gz
LIBMAXMINDDB_INSTALL_MARKER:=$(LIBMAXMINDDB_NAME)$(VERSION_SEP)$(LIBMAXMINDDB_VERSION)

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

LUA_RESTY_UUID_VERSION:=834e69c1603b796ffb3ec2921f720f3059cb62c0
LUA_RESTY_UUID_NAME:=lua-resty-uuid
LUA_RESTY_UUID:=$(LUA_RESTY_UUID_NAME)-$(LUA_RESTY_UUID_VERSION)
LUA_RESTY_UUID_DIGEST:=md5
LUA_RESTY_UUID_CHECKSUM:=044bb66af54bbf11f2f53eb62535e4ff
LUA_RESTY_UUID_URL:=https://github.com/bungle/lua-resty-uuid/archive/$(LUA_RESTY_UUID_VERSION).tar.gz
LUA_RESTY_UUID_INSTALL_MARKER:=$(LUA_RESTY_UUID_NAME)$(VERSION_SEP)$(LUA_RESTY_UUID_VERSION)

LUAROCKS_VERSION:=2.2.2
LUAROCKS_NAME:=luarocks
LUAROCKS:=$(LUAROCKS_NAME)-$(LUAROCKS_VERSION)
LUAROCKS_DIGEST:=md5
LUAROCKS_CHECKSUM:=5a830953d27715cc955119609f8096e6
LUAROCKS_URL:=http://luarocks.org/releases/luarocks-$(LUAROCKS_VERSION).tar.gz
LUAROCKS_INSTALL_MARKER:=$(LUAROCKS_NAME)$(VERSION_SEP)$(LUAROCKS_VERSION)

LUSTACHE_VERSION:=241b3a16f358035887c2c05c6e151c1f48401a42
LUSTACHE_NAME:=lustache
LUSTACHE:=$(LUSTACHE_NAME)-$(LUSTACHE_VERSION)
LUSTACHE_DIGEST:=md5
LUSTACHE_CHECKSUM:=7c64dd36bbb02e71a0e60e847b70d561
LUSTACHE_URL:=https://github.com/Olivine-Labs/lustache/archive/$(LUSTACHE_VERSION).tar.gz
LUSTACHE_INSTALL_MARKER:=$(LUSTACHE_NAME)$(VERSION_SEP)$(LUSTACHE_VERSION)

MONGODB_VERSION:=3.0.7
MONGODB_NAME:=mongodb
MONGODB:=$(MONGODB_NAME)-$(MONGODB_VERSION)
MONGODB_DIGEST:=md5
MONGODB_CHECKSUM:=e3894b76089fa9d38901c96bc5516a14
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

NGX_DYUPS_VERSION:=0.2.8
NGX_DYUPS_NAME:=ngx_http_dyups_module
NGX_DYUPS:=$(NGX_DYUPS_NAME)-$(NGX_DYUPS_VERSION)
NGX_DYUPS_DIGEST:=md5
NGX_DYUPS_CHECKSUM:=295b7cb202de069b313f4da50d6952e0
NGX_DYUPS_URL:=https://github.com/yzprofile/ngx_http_dyups_module/archive/v$(NGX_DYUPS_VERSION).tar.gz
NGX_DYUPS_INSTALL_MARKER:=$(NGX_DYUPS_NAME)$(VERSION_SEP)$(NGX_DYUPS_VERSION)

NGX_GEOIP2_VERSION:=1.0
NGX_GEOIP2_NAME:=ngx_http_geoip2_module
NGX_GEOIP2:=$(NGX_GEOIP2_NAME)-$(NGX_GEOIP2_VERSION)
NGX_GEOIP2_DIGEST:=md5
NGX_GEOIP2_CHECKSUM:=4c89eea53ce8318f940c03adfe0b502b
NGX_GEOIP2_URL:=https://github.com/leev/ngx_http_geoip2_module/archive/1.0.tar.gz
NGX_GEOIP2_INSTALL_MARKER:=$(NGX_GEOIP2_NAME)$(VERSION_SEP)$(NGX_GEOIP2_VERSION)

OPENRESTY_VERSION:=1.9.3.1
OPENRESTY_NAME:=openresty
OPENRESTY:=$(OPENRESTY_NAME)-$(OPENRESTY_VERSION)
OPENRESTY_DIGEST:=md5
OPENRESTY_CHECKSUM:=cde1f7127f6ba413ee257003e49d6d0a
OPENRESTY_URL:=http://openresty.org/download/ngx_openresty-$(OPENRESTY_VERSION).tar.gz
OPENRESTY_INSTALL_MARKER:=$(OPENRESTY_NAME)$(VERSION_SEP)$(OPENRESTY_VERSION)

PCRE_VERSION:=8.37
PCRE_NAME:=pcre
PCRE:=$(PCRE_NAME)-$(PCRE_VERSION)
PCRE_DIGEST:=md5
PCRE_CHECKSUM:=ed91be292cb01d21bc7e526816c26981
PCRE_URL:=http://ftp.cs.stanford.edu/pub/exim/pcre/pcre-$(PCRE_VERSION).tar.bz2
PCRE_INSTALL_MARKER:=$(PCRE_NAME)$(VERSION_SEP)$(PCRE_VERSION)

PERP_VERSION:=2.07
PERP_NAME:=perp
PERP:=$(PERP_NAME)-$(PERP_VERSION)
PERP_DIGEST:=md5
PERP_CHECKSUM:=a2acc7425d556d9635a25addcee9edb5
PERP_URL:=http://b0llix.net/perp/distfiles/perp-$(PERP_VERSION).tar.gz
PERP_INSTALL_MARKER:=$(PERP_NAME)$(VERSION_SEP)$(PERP_VERSION)

RUBY_VERSION:=2.2.3
RUBY_NAME:=ruby
RUBY:=$(RUBY_NAME)-$(RUBY_VERSION)
RUBY_DIGEST:=sha256
RUBY_CHECKSUM:=df795f2f99860745a416092a4004b016ccf77e8b82dec956b120f18bdc71edce
RUBY_URL:=https://cache.ruby-lang.org/pub/ruby/2.2/ruby-$(RUBY_VERSION).tar.gz
RUBY_INSTALL_MARKER:=$(RUBY_NAME)$(VERSION_SEP)$(RUBY_VERSION)

# Don't move to 6.0.0 quite yet until we have a better sense of this issue:
# http://mail-archives.apache.org/mod_mbox/trafficserver-users/201510.mbox/%3c1443975393.1364867.400869481.2BFF6EEF@webmail.messagingengine.com%3e
TRAFFICSERVER_VERSION:=5.3.1
TRAFFICSERVER_NAME:=trafficserver
TRAFFICSERVER:=$(TRAFFICSERVER_NAME)-$(TRAFFICSERVER_VERSION)
TRAFFICSERVER_DIGEST:=md5
TRAFFICSERVER_CHECKSUM:=9c0e2450b1dd1bbdd63ebcc344b5a813
TRAFFICSERVER_URL:=http://mirror.olnevhost.net/pub/apache/trafficserver/trafficserver-$(TRAFFICSERVER_VERSION).tar.bz2
TRAFFICSERVER_INSTALL_MARKER:=$(TRAFFICSERVER_NAME)$(VERSION_SEP)$(TRAFFICSERVER_VERSION)

#
# LuaRocks Dependencies
#
INSPECT:=inspect
INSPECT_VERSION:=3.0-1
LIBCIDR_FFI:=libcidr-ffi
LIBCIDR_FFI_VERSION:=0.1.0-1
LIBCIDR_FFI_URL:=https://raw.githubusercontent.com/GUI/lua-libcidr-ffi/master/libcidr-ffi-git-1.rockspec
LUA_CMSGPACK:=lua-cmsgpack
LUA_CMSGPACK_VERSION:=0.4.0-0
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
UNBOUND_VERSION:=1.5.6
UNBOUND_NAME:=unbound
UNBOUND:=$(UNBOUND_NAME)-$(UNBOUND_VERSION)
UNBOUND_DIGEST:=sha256
UNBOUND_CHECKSUM:=ad3823f5895f59da9e408ea273fcf81d8a76914c18864fba256d7f140b83e404
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
	local_work_dir \
	stage \
	stage_dependencies \
	test_dependencies \
	lint \
	test

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
	openssl $(CHECKSUM_TYPE) $(DOWNLOAD_PATH) | grep $(CHECKSUM) || (echo "checksum mismatch $(DOWNLOAD_PATH)" && exit 1)
	mkdir -p $(DIR)
	tar --strip-components 1 -C $(DIR) -xf $(DOWNLOAD_PATH)
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

$(STAGE_PREFIX)/embedded/bin:
	mkdir -p $@
	touch $@

$(STAGE_PREFIX)/embedded/sbin:
	mkdir -p $@
	touch $@

$(STAGE_MARKERS_DIR):
	mkdir -p $@
	touch $@

# api-umbrella-core
$(STAGE_MARKERS_DIR)/api-umbrella-core-web-bundled: $(ROOT_DIR)/src/api-umbrella/web-app/Gemfile $(ROOT_DIR)/src/api-umbrella/web-app/Gemfile.lock | $(VENDOR_DIR) $(STAGE_MARKERS_DIR) $(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER)
	rm -rf $(ROOT_DIR)/src/api-umbrella/web-app/.bundle
	cd $(ROOT_DIR)/src/api-umbrella/web-app && PATH=$(STAGE_PREFIX)/embedded/bin:$(PATH) bundle install --path=$(BUNDLE_DIR)
	touch $@

# Rebuild when the contents of any of the asset files change. We base this on a
# checksum of all the files, rather than timestamps, so that in our CI
# environment we skip precompiling (it's slow), if none of the files changed
# (but since the CI does a fresh checkout, all the timestamps on the files
# change, so make's normal checking would trigger changes).
WEB_ASSETS_CHECKSUM:=$(shell find $(ROOT_DIR)/src/api-umbrella/web-app/app/assets $(ROOT_DIR)/src/api-umbrella/web-app/Gemfile.lock -type f -exec cksum {} \; | sort | openssl md5 | sed 's/^.* //')
$(STAGE_MARKERS_DIR)/api-umbrella-core-web-assets-$(WEB_ASSETS_CHECKSUM): $(STAGE_MARKERS_DIR)/api-umbrella-core-web-bundled | $(STAGE_MARKERS_DIR)
	# Compile the assets, but then move them to a temporary build directory so
	# they aren't used when working in development mode.
	cd $(ROOT_DIR)/src/api-umbrella/web-app && PATH=$(STAGE_PREFIX)/embedded/bin:$(PATH) DEVISE_SECRET_KEY=temp RAILS_SECRET_TOKEN=temp bundle exec rake assets:precompile
	mkdir -p $(WORK_DIR)/tmp/web-assets
	cd $(ROOT_DIR)/src/api-umbrella/web-app && rsync -a --delete-after public/web-assets/ $(WORK_DIR)/tmp/web-assets/
	rm -rf $(ROOT_DIR)/src/api-umbrella/web-app/public/web-assets
	touch $@

$(STAGE_MARKERS_DIR)/api-umbrella-core: $(STAGE_MARKERS_DIR)/api-umbrella-core-dependencies | $(STAGE_MARKERS_DIR)
	# Create a new release directory, copying the relevant source code from the
	# current repo checkout into the release (but excluding tests, etc).
	rm -rf $(STAGE_PREFIX)/embedded/apps/core/releases
	mkdir -p $(STAGE_PREFIX)/embedded/apps/core/releases/$(RELEASE_TIMESTAMP)
	rsync -a \
		--filter=":- $(ROOT_DIR)/.gitignore" \
		--include="/templates/etc/perp/.boot" \
		--exclude=".*" \
		--exclude="/src/api-umbrella/web-app/spec" \
		--exclude="/src/api-umbrella/web-app/app/assets" \
		--include="/bin/***" \
		--include="/config/***" \
		--include="/LICENSE.txt" \
		--include="/templates/***" \
		--include="/src/***" \
		--exclude="*" \
		$(ROOT_DIR)/ $(STAGE_PREFIX)/embedded/apps/core/releases/$(RELEASE_TIMESTAMP)/
	cd $(STAGE_PREFIX)/embedded/apps/core && ln -snf releases/$(RELEASE_TIMESTAMP) ./current
	# Symlink the main api-umbrella binary into place.
	mkdir -p $(STAGE_PREFIX)/bin
	cd $(STAGE_PREFIX)/bin && ln -snf ../embedded/apps/core/current/bin/api-umbrella ./api-umbrella
	# Copy all of the vendor files into place.
	mkdir -p $(STAGE_PREFIX)/embedded/apps/core/shared/vendor
	rsync -a --delete-after $(VENDOR_DIR)/ $(STAGE_PREFIX)/embedded/apps/core/shared/vendor/
	cd $(STAGE_PREFIX)/embedded/apps/core/releases/$(RELEASE_TIMESTAMP) && ln -snf ../../shared/vendor ./vendor
	# Copy the precompiled assets into place.
	mkdir -p $(STAGE_PREFIX)/embedded/apps/core/shared/public/web-assets
	rsync -a --delete-after $(WORK_DIR)/tmp/web-assets/ $(STAGE_PREFIX)/embedded/apps/core/shared/public/web-assets/
	cd $(STAGE_PREFIX)/embedded/apps/core/releases/$(RELEASE_TIMESTAMP)/src/api-umbrella/web-app/public && ln -snf ../../../../../../shared/public/web-assets ./web-assets
	# Re-run the bundle install inside the release directory, but disabling
	# non-production gem groups. Combined with the clean flag, this deletes all
	# the test/development/asset gems we don't need for a release.
	cd $(STAGE_PREFIX)/embedded/apps/core/releases/$(RELEASE_TIMESTAMP)/src/api-umbrella/web-app && PATH=$(STAGE_PREFIX)/embedded/bin:$(PATH) bundle install --path=../../../vendor/bundle --clean --without="development test assets" --deployment
	# Purge a bunch of content out of the bundler results to make for a lighter
	# release distribution. Purge gem caches, embedded test files, and
	# intermediate files used when compiling C gems from source. Also delete some
	# of the duplicate .so library files for C extensions (we should only need
	# the ones in the "extensions" directory, the rest are duplicates for legacy
	# purposes).
	cd $(STAGE_PREFIX)/embedded/apps/core/shared/vendor/bundle && rm -rf ruby/*/cache ruby/*/gems/*/test* ruby/*/gems/*/spec ruby/*/bundler/gems/*/test* ruby/*/bundler/gems/*/spec
	#cd $(STAGE_PREFIX)/embedded/apps/core/shared/vendor/bundle && find ruby/*/gems -name "*.so" -delete
	# Setup a shared symlink for web-app temp files.
	mkdir -p $(STAGE_PREFIX)/embedded/apps/core/shared/web-tmp
	cd $(STAGE_PREFIX)/embedded/apps/core/releases/$(RELEASE_TIMESTAMP)/src/api-umbrella/web-app && ln -snf ../../../../../shared/web-tmp ./tmp
	touch $@

# api-umbrella-static-site
$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz: | $(DEPS_DIR)
	$(call download,API_UMBRELLA_STATIC_SITE)

$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE): $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz
	$(call decompress,API_UMBRELLA_STATIC_SITE)

$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/.built: $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE) | $(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER)
	cd $< && PATH=$(STAGE_PREFIX)/embedded/bin:$(PATH) bundle install --path=$(BUNDLE_DIR)
	cd $< && PATH=$(STAGE_PREFIX)/embedded/bin:$(PATH) bundle exec middleman build
	touch $@

$(STAGE_MARKERS_DIR)/$(API_UMBRELLA_STATIC_SITE_INSTALL_MARKER): $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/.built | $(STAGE_MARKERS_DIR)
	rm -rf $(STAGE_PREFIX)/embedded/apps/static-site/releases
	mkdir -p $(STAGE_PREFIX)/embedded/apps/static-site/releases/$(RELEASE_TIMESTAMP)/build
	rsync -a $(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/build/ $(STAGE_PREFIX)/embedded/apps/static-site/releases/$(RELEASE_TIMESTAMP)/build/
	cd $(STAGE_PREFIX)/embedded/apps/static-site && ln -snf releases/$(RELEASE_TIMESTAMP) ./current
	touch $@

# Bundler
$(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER): | $(STAGE_MARKERS_DIR) $(STAGE_MARKERS_DIR)/$(RUBY_INSTALL_MARKER)
	PATH=$(STAGE_PREFIX)/embedded/bin:$(PATH) gem install bundler -v '$(BUNDLER_VERSION)' --no-rdoc --no-ri --env-shebang
	rm -f $(STAGE_MARKERS_DIR)/$(BUNDLER_NAME)$(VERSION_SEP)*
	touch $@

# ElasticSearch
$(DEPS_DIR)/$(ELASTICSEARCH).tar.gz: | $(DEPS_DIR)
	$(call download,ELASTICSEARCH)

$(DEPS_DIR)/$(ELASTICSEARCH): $(DEPS_DIR)/$(ELASTICSEARCH).tar.gz
	$(call decompress,ELASTICSEARCH)

$(STAGE_MARKERS_DIR)/$(ELASTICSEARCH_INSTALL_MARKER): $(DEPS_DIR)/$(ELASTICSEARCH) | $(STAGE_MARKERS_DIR)
	mkdir -p $(STAGE_PREFIX)/embedded/elasticsearch
	rsync -a $(DEPS_DIR)/$(ELASTICSEARCH)/ $(STAGE_PREFIX)/embedded/elasticsearch/
	cd $(STAGE_PREFIX)/embedded/bin && ln -snf ../elasticsearch/bin/plugin ./plugin
	cd $(STAGE_PREFIX)/embedded/bin && ln -snf ../elasticsearch/bin/elasticsearch ./elasticsearch
	rm -f $(STAGE_MARKERS_DIR)/$(ELASTICSEARCH_NAME)$(VERSION_SEP)*
	touch $@

# GeoLite2-City.mmdb
$(DEPS_DIR)/GeoLite2-City.md5: | $(DEPS_DIR)
	curl -L -o $@ https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.md5
	touch $@

$(DEPS_DIR)/GeoLite2-City.mmdb.gz: | $(DEPS_DIR)
	curl -L -o $@ https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz
	touch $@

$(DEPS_DIR)/GeoLite2-City.mmdb: $(DEPS_DIR)/GeoLite2-City.mmdb.gz $(DEPS_DIR)/GeoLite2-City.md5
	gunzip -c $< > $@
	openssl md5 $@ | grep `cat $(DEPS_DIR)/GeoLite2-City.md5` || (echo "checksum mismatch $@" && exit 1)
	touch $@

$(STAGE_MARKERS_DIR)/GeoLite2-City.mmdb: $(DEPS_DIR)/GeoLite2-City.mmdb | $(STAGE_MARKERS_DIR)
	mkdir -p $(STAGE_PREFIX)/embedded/var/db/geoip2
	rsync -a $(DEPS_DIR)/GeoLite2-City.mmdb $(STAGE_PREFIX)/embedded/var/db/geoip2/city.mmdb
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
	mkdir -p $(STAGE_PREFIX)/embedded
	rsync -a $(DEPS_DIR)/$(HEKA)/ $(STAGE_PREFIX)/embedded/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(STAGE_PREFIX)/embedded/bin/heka-cat \
		$(STAGE_PREFIX)/embedded/bin/heka-flood \
		$(STAGE_PREFIX)/embedded/bin/heka-inject \
		$(STAGE_PREFIX)/embedded/bin/heka-sbmgr
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
	rm -f $(STAGE_PREFIX)/embedded/bin/cidrcalc
	rm -f $(STAGE_MARKERS_DIR)/$(LIBCIDR_NAME)$(VERSION_SEP)*
	touch $@

# libmaxminddb
$(DEPS_DIR)/$(LIBMAXMINDDB).tar.gz: | $(DEPS_DIR)
	$(call download,LIBMAXMINDDB)

$(DEPS_DIR)/$(LIBMAXMINDDB): $(DEPS_DIR)/$(LIBMAXMINDDB).tar.gz
	$(call decompress,LIBMAXMINDDB)

$(DEPS_DIR)/$(LIBMAXMINDDB)/.built: $(DEPS_DIR)/$(LIBMAXMINDDB)
	cd $< && LDFLAGS="-Wl,-rpath,$(STAGE_PREFIX)/embedded/lib" ./configure \
		--prefix=$(PREFIX)/embedded
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(LIBMAXMINDDB_INSTALL_MARKER): $(DEPS_DIR)/$(LIBMAXMINDDB)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(LIBMAXMINDDB) && make install DESTDIR=$(STAGE_DIR)
	rm -f $(STAGE_MARKERS_DIR)/$(LIBMAXMINDDB_NAME)$(VERSION_SEP)*
	touch $@

# LuaRocks
$(DEPS_DIR)/$(LUAROCKS).tar.gz: | $(DEPS_DIR)
	$(call download,LUAROCKS)

$(DEPS_DIR)/$(LUAROCKS): $(DEPS_DIR)/$(LUAROCKS).tar.gz
	$(call decompress,LUAROCKS)

$(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER): $(DEPS_DIR)/$(LUAROCKS) | $(STAGE_MARKERS_DIR) $(STAGE_MARKERS_DIR)/$(OPENRESTY_INSTALL_MARKER)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty/luajit \
		--with-lua=$(STAGE_PREFIX)/embedded/openresty/luajit/ \
		--with-lua-include=$(STAGE_PREFIX)/embedded/openresty/luajit/include/luajit-2.1 \
		--lua-suffix=jit-2.1.0-alpha
	cd $< && make build
	cd $< && make install DESTDIR=$(STAGE_DIR)
	cd $(STAGE_PREFIX)/embedded/bin && ln -snf ../openresty/luajit/bin/luarocks ./luarocks
	rm -f $(STAGE_MARKERS_DIR)/$(LUAROCKS_NAME)$(VERSION_SEP)*
	touch $@

# lua-resty-dns-cache
$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_DNS_CACHE)

$(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE): $(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE).tar.gz
	$(call decompress,LUA_RESTY_DNS_CACHE)

$(LUA_SHARE_DIR)/resty/dns/cache.lua: $(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE) | $(VENDOR_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_DNS_CACHE)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	touch $@

# lua-resty-http
$(DEPS_DIR)/$(LUA_RESTY_HTTP).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_HTTP)

$(DEPS_DIR)/$(LUA_RESTY_HTTP): $(DEPS_DIR)/$(LUA_RESTY_HTTP).tar.gz
	$(call decompress,LUA_RESTY_HTTP)

$(LUA_SHARE_DIR)/resty/http.lua: $(DEPS_DIR)/$(LUA_RESTY_HTTP) | $(VENDOR_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_HTTP)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	touch $@

# lua-resty-logger-socket
$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_LOGGER_SOCKET)

$(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET): $(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET).tar.gz
	$(call decompress,LUA_RESTY_LOGGER_SOCKET)

$(LUA_SHARE_DIR)/resty/logger/socket.lua: $(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET) | $(VENDOR_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_LOGGER_SOCKET)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	touch $@

# lua-resty-shcache
$(DEPS_DIR)/$(LUA_RESTY_SHCACHE).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_SHCACHE)

$(DEPS_DIR)/$(LUA_RESTY_SHCACHE): $(DEPS_DIR)/$(LUA_RESTY_SHCACHE).tar.gz
	$(call decompress,LUA_RESTY_SHCACHE)

$(LUA_SHARE_DIR)/shcache.lua: $(DEPS_DIR)/$(LUA_RESTY_SHCACHE) | $(VENDOR_DIR)
	mkdir -p $(LUA_SHARE_DIR)
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_SHCACHE)/*.lua $(LUA_SHARE_DIR)/
	touch $@

# lua-resty-uuid
$(DEPS_DIR)/$(LUA_RESTY_UUID).tar.gz: | $(DEPS_DIR)
	$(call download,LUA_RESTY_UUID)

$(DEPS_DIR)/$(LUA_RESTY_UUID): $(DEPS_DIR)/$(LUA_RESTY_UUID).tar.gz
	$(call decompress,LUA_RESTY_UUID)

$(LUA_SHARE_DIR)/resty/uuid.lua: $(DEPS_DIR)/$(LUA_RESTY_UUID) | $(VENDOR_DIR)
	mkdir -p $(LUA_SHARE_DIR)/resty
	rsync -a $(DEPS_DIR)/$(LUA_RESTY_UUID)/lib/resty/ $(LUA_SHARE_DIR)/resty/
	touch $@

# lustache
$(DEPS_DIR)/$(LUSTACHE).tar.gz: | $(DEPS_DIR)
	$(call download,LUSTACHE)

$(DEPS_DIR)/$(LUSTACHE): $(DEPS_DIR)/$(LUSTACHE).tar.gz
	$(call decompress,LUSTACHE)

$(LUA_SHARE_DIR)/lustache.lua: $(DEPS_DIR)/$(LUSTACHE) | $(VENDOR_DIR)
	mkdir -p $(LUA_SHARE_DIR)
	rsync -a $(DEPS_DIR)/$(LUSTACHE)/src/ $(LUA_SHARE_DIR)/
	touch $@

# MongoDB
$(DEPS_DIR)/$(MONGODB).tar.gz: | $(DEPS_DIR)
	$(call download,MONGODB)

$(DEPS_DIR)/$(MONGODB): $(DEPS_DIR)/$(MONGODB).tar.gz
	$(call decompress,MONGODB)

$(STAGE_MARKERS_DIR)/$(MONGODB_INSTALL_MARKER): $(DEPS_DIR)/$(MONGODB) | $(STAGE_MARKERS_DIR)
	mkdir -p $(STAGE_PREFIX)/embedded
	rsync -a $(DEPS_DIR)/$(MONGODB)/ $(STAGE_PREFIX)/embedded/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(STAGE_PREFIX)/embedded/bin/bsondump \
		$(STAGE_PREFIX)/embedded/bin/mongoexport \
		$(STAGE_PREFIX)/embedded/bin/mongofiles \
		$(STAGE_PREFIX)/embedded/bin/mongoimport \
		$(STAGE_PREFIX)/embedded/bin/mongooplog \
		$(STAGE_PREFIX)/embedded/bin/mongoperf \
		$(STAGE_PREFIX)/embedded/bin/mongos
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
	cp $(DEPS_DIR)/gocode/bin/mora $(STAGE_PREFIX)/embedded/bin/
	rm -f $(STAGE_MARKERS_DIR)/$(MORA_NAME)$(VERSION_SEP)*
	touch $@

# ngx_dyups
$(DEPS_DIR)/$(NGX_DYUPS).tar.gz: | $(DEPS_DIR)
	$(call download,NGX_DYUPS)

$(DEPS_DIR)/$(NGX_DYUPS): $(DEPS_DIR)/$(NGX_DYUPS).tar.gz
	$(call decompress,NGX_DYUPS)

# ngx_geoip2
$(DEPS_DIR)/$(NGX_GEOIP2).tar.gz: | $(DEPS_DIR)
	$(call download,NGX_GEOIP2)

$(DEPS_DIR)/$(NGX_GEOIP2): $(DEPS_DIR)/$(NGX_GEOIP2).tar.gz
	$(call decompress,NGX_GEOIP2)

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

$(DEPS_DIR)/$(OPENRESTY)/.built: $(DEPS_DIR)/$(OPENRESTY) $(DEPS_DIR)/$(NGX_DYUPS) $(DEPS_DIR)/$(NGX_GEOIP2) $(DEPS_DIR)/$(NGX_TXID) $(STAGE_MARKERS_DIR)/$(LIBMAXMINDDB_INSTALL_MARKER) $(DEPS_DIR)/$(PCRE)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty \
		--with-cc-opt="-I$(STAGE_PREFIX)/embedded/include" \
		--with-ld-opt="-L$(STAGE_PREFIX)/embedded/lib -Wl,-rpath,$(PREFIX)/embedded/lib,-rpath,$(STAGE_PREFIX)/embedded/openresty/luajit/lib,-rpath,$(STAGE_PREFIX)/embedded/lib" \
		--error-log-path=stderr \
		--with-ipv6 \
		--with-pcre=$(DEPS_DIR)/$(PCRE) \
		--with-pcre-conf-opt="--enable-unicode-properties" \
		--with-pcre-jit \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_realip_module \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--add-module=../$(NGX_DYUPS) \
		--add-module=../$(NGX_GEOIP2) \
		--add-module=../$(NGX_TXID)
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(OPENRESTY_INSTALL_MARKER): $(DEPS_DIR)/$(OPENRESTY)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(OPENRESTY) && make install DESTDIR=$(STAGE_DIR)
	cd $(STAGE_PREFIX)/embedded/bin && ln -snf ../openresty/bin/resty ./resty
	cd $(STAGE_PREFIX)/embedded/bin && ln -snf ../openresty/luajit/bin/luajit-2.1.0-alpha ./luajit
	cd $(STAGE_PREFIX)/embedded/sbin && ln -snf ../openresty/nginx/sbin/nginx ./nginx
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
$(DEPS_DIR)/$(RUBY).tar.gz: | $(DEPS_DIR)
	$(call download,RUBY)

$(DEPS_DIR)/$(RUBY): $(DEPS_DIR)/$(RUBY).tar.gz
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

# TrafficServer
$(DEPS_DIR)/$(TRAFFICSERVER).tar.gz: | $(DEPS_DIR)
	$(call download,TRAFFICSERVER)

$(DEPS_DIR)/$(TRAFFICSERVER): $(DEPS_DIR)/$(TRAFFICSERVER).tar.gz
	$(call decompress,TRAFFICSERVER)

$(DEPS_DIR)/$(TRAFFICSERVER)/.built: $(DEPS_DIR)/$(TRAFFICSERVER)
	cd $< && PATH=$(STANDARD_PATH) LDFLAGS="-Wl,-rpath,$(STAGE_PREFIX)/embedded/lib" ./configure \
		--prefix=$(PREFIX)/embedded \
		--enable-experimental-plugins
	cd $< && make
	touch $@

$(STAGE_MARKERS_DIR)/$(TRAFFICSERVER_INSTALL_MARKER): $(DEPS_DIR)/$(TRAFFICSERVER)/.built | $(STAGE_MARKERS_DIR)
	cd $(DEPS_DIR)/$(TRAFFICSERVER) && make install DESTDIR=$(STAGE_DIR)
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(STAGE_PREFIX)/embedded/bin/traffic_sac
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

# LuaRocks - inspect
$(LUAROCKS_DIR)/$(INSPECT)/$(INSPECT_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(call luarocks_install,INSPECT)

# LuaRocks - libcidr-ffi
$(LUAROCKS_DIR)/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(LUAROCKS_CMD) --tree=$(VENDOR_DIR) install https://raw.githubusercontent.com/GUI/lua-libcidr-ffi/master/libcidr-ffi-git-1.rockspec CIDR_DIR=$(STAGE_PREFIX)/embedded
	touch $@

# LuaRocks - lua-cmsgpack
$(LUAROCKS_DIR)/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(call luarocks_install,LUA_CMSGPACK)

# LuaRocks - luacheck
$(TEST_LUAROCKS_DIR)/$(LUACHECK)/$(LUACHECK_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(TEST_VENDOR_DIR)
	$(call test_luarocks_install,LUACHECK)

# LuaRocks - luaposix
$(LUAROCKS_DIR)/$(LUAPOSIX)/$(LUAPOSIX_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(call luarocks_install,LUAPOSIX)

# LuaRocks - luasocket
$(LUAROCKS_DIR)/$(LUASOCKET)/$(LUASOCKET_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(call luarocks_install,LUASOCKET)

# LuaRocks - lyaml
$(LUAROCKS_DIR)/$(LYAML)/$(LYAML_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(call luarocks_install,LYAML)

# LuaRocks - penlight
$(LUAROCKS_DIR)/$(PENLIGHT)/$(PENLIGHT_VERSION): | $(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) $(VENDOR_DIR)
	$(call luarocks_install,PENLIGHT)

.SECONDARY: \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE).tar.gz \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE) \
	$(DEPS_DIR)/$(API_UMBRELLA_STATIC_SITE)/.built \
	$(DEPS_DIR)/$(ELASTICSEARCH).tar.gz \
	$(DEPS_DIR)/$(ELASTICSEARCH) \
	$(DEPS_DIR)/GeoLite2-City.md5 \
	$(DEPS_DIR)/GeoLite2-City.mmdb.gz \
	$(DEPS_DIR)/GeoLite2-City.mmdb \
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
	$(DEPS_DIR)/$(LIBMAXMINDDB).tar.gz \
	$(DEPS_DIR)/$(LIBMAXMINDDB) \
	$(DEPS_DIR)/$(LIBMAXMINDDB)/.built \
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
	$(DEPS_DIR)/$(NGX_GEOIP2).tar.gz \
	$(DEPS_DIR)/$(NGX_GEOIP2) \
	$(DEPS_DIR)/$(NGX_TXID).tar.gz \
	$(DEPS_DIR)/$(NGX_TXID) \
	$(DEPS_DIR)/$(OPENRESTY).tar.gz \
	$(DEPS_DIR)/$(OPENRESTY) \
	$(DEPS_DIR)/$(OPENRESTY)/.built \
	$(DEPS_DIR)/$(PERP).tar.gz \
	$(DEPS_DIR)/$(PERP) \
	$(DEPS_DIR)/$(PERP)/.built \
	$(DEPS_DIR)/$(RUBY).tar.gz \
	$(DEPS_DIR)/$(RUBY) \
	$(DEPS_DIR)/$(RUBY)/.built \
	$(DEPS_DIR)/$(TRAFFICSERVER).tar.gz \
	$(DEPS_DIR)/$(TRAFFICSERVER) \
	$(DEPS_DIR)/$(TRAFFICSERVER)/.built \
	$(DEPS_DIR)/$(UNBOUND).tar.gz \
	$(DEPS_DIR)/$(UNBOUND) \
	$(DEPS_DIR)/$(UNBOUND)/.built

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

$(STAGE_MARKERS_DIR)/api-umbrella-core-dependencies: \
	$(STAGE_MARKERS_DIR)/api-umbrella-core-web-assets-$(WEB_ASSETS_CHECKSUM) \
	$(STAGE_MARKERS_DIR)/api-umbrella-core-web-bundled \
	$(LUAROCKS_DIR)/$(INSPECT)/$(INSPECT_VERSION) \
	$(LUAROCKS_DIR)/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION) \
	$(LUAROCKS_DIR)/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION) \
	$(LUAROCKS_DIR)/$(LUAPOSIX)/$(LUAPOSIX_VERSION) \
	$(LUAROCKS_DIR)/$(LUASOCKET)/$(LUASOCKET_VERSION) \
	$(LUAROCKS_DIR)/$(LYAML)/$(LYAML_VERSION) \
	$(LUAROCKS_DIR)/$(PENLIGHT)/$(PENLIGHT_VERSION) \
	$(LUAROCKS_DIR)/$(UUID)/$(UUID_VERSION) \
	$(LUA_SHARE_DIR)/lustache.lua \
	$(LUA_SHARE_DIR)/resty/dns/cache.lua \
	$(LUA_SHARE_DIR)/resty/http.lua \
	$(LUA_SHARE_DIR)/resty/logger/socket.lua \
	$(LUA_SHARE_DIR)/shcache.lua \
	$(LUA_SHARE_DIR)/resty/uuid.lua \
	$(ROOT_DIR)/vendor | $(STAGE_MARKERS_DIR)
	touch $@

stage: \
	$(STAGE_PREFIX)/embedded/bin \
	$(STAGE_PREFIX)/embedded/sbin \
	$(STAGE_MARKERS_DIR)/api-umbrella-core \
	$(STAGE_MARKERS_DIR)/$(API_UMBRELLA_STATIC_SITE_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(BUNDLER_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(ELASTICSEARCH_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/GeoLite2-City.mmdb \
	$(STAGE_MARKERS_DIR)/$(HEKA_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LIBCIDR_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LIBMAXMINDDB_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(LUAROCKS_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(MONGODB_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(MORA_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(OPENRESTY_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(PERP_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(RUBY_INSTALL_MARKER) \
	$(STAGE_MARKERS_DIR)/$(TRAFFICSERVER_INSTALL_MARKER) \
	$(BUILD_DIR)/local

install: stage
	mkdir -p $(DESTDIR)/usr/bin $(DESTDIR)/var/log $(DESTDIR)$(PREFIX)/etc $(DESTDIR)$(PREFIX)/var/db $(DESTDIR)$(PREFIX)/var/log $(DESTDIR)$(PREFIX)/var/run $(DESTDIR)$(PREFIX)/var/tmp
	rsync -av $(STAGE_PREFIX)/bin/ $(DESTDIR)$(PREFIX)/bin/
	rsync -av $(STAGE_PREFIX)/embedded/ $(DESTDIR)$(PREFIX)/embedded/
	rsync -av --backup --suffix=".new" --exclude=".*" $(BUILD_DIR)/package/files/etc/ $(DESTDIR)/etc/
	cd $(DESTDIR)/usr/bin && ln -snf ../..$(PREFIX)/bin/api-umbrella ./api-umbrella
	cd $(DESTDIR)/var/log && ln -snf ../..$(PREFIX)/var/log ./api-umbrella
	chmod 440 $(DESTDIR)/etc/sudoers.d/api-umbrella
	chmod 1777 $(DESTDIR)$(PREFIX)/var/tmp
	chmod 775 $(DESTDIR)$(PREFIX)/embedded/apps/core/shared/web-tmp

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
	$(TEST_LUAROCKS_DIR)/$(LUACHECK)/$(LUACHECK_VERSION) \
	$(STAGE_MARKERS_DIR)/test-python-requirements \
	$(STAGE_MARKERS_DIR)/$(UNBOUND_INSTALL_MARKER)

lint: test_dependencies
	LUA_PATH="$(TEST_LUA_SHARE_DIR)/?.lua;$(TEST_LUA_SHARE_DIR)/?/init.lua;;" LUA_CPATH="$(TEST_LUA_LIB_DIR)/?.so;;" $(TEST_VENDOR_DIR)/bin/luacheck $(ROOT_DIR)/src

test: stage test_dependencies lint
	cd test && MOCHA_FILES="$(MOCHA_FILES)" npm test

clean:
	rm -rf $(WORK_DIR) $(ROOT_DIR)/bundle $(BUILD_DIR)/local $(ROOT_DIR)/test/node_modules $(ROOT_DIR)/src/api-umbrella/web-app/.bundle $(ROOT_DIR)/src/api-umbrella/web-app/tmp $(ROOT_DIR)/src/api-umbrella/web-app/log

check_shared_objects:
	find $(STAGE_PREFIX)/embedded -type f | xargs ldd 2>&1 | grep " => " | grep -o "^[^(]*" | sort | uniq

package:
	$(BUILD_DIR)/package/build

package_all:
	$(BUILD_DIR)/package/build_all

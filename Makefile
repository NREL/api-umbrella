# Unset some environment variables that come from RVM and may interfere with
# gem installation in some environments (eg, CircleCI).
unexport GEM_HOME
unexport GEM_PATH
unexport IRBRC
unexport MY_RUBY_HOME
unexport RUBY_VERSION

STANDARD_PATH:=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin
PREFIX:=/tmp/api-umbrella-build
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
INSTALLED_DIR:=$(PREFIX)/embedded/.installed
LUAROCKS_DIR:=vendor/lib/luarocks/rocks
VERSION_SEP:=-version-

BUNDLER_VERSION:=1.10.6
BUNDLER_NAME:=bundler
BUNDLER:=$(BUNDLER_NAME)-$(BUNDLER_VERSION)
BUNDLER_INSTALL_MARKER:=$(BUNDLER_NAME)$(VERSION_SEP)$(BUNDLER_VERSION)

ELASTICSEARCH_VERSION:=1.7.2
ELASTICSEARCH_NAME:=elasticsearch
ELASTICSEARCH:=$(ELASTICSEARCH_NAME)-$(ELASTICSEARCH_VERSION)
ELASTICSEARCH_DIGEST:=sha1
ELASTICSEARCH_CHECKSUM:=a7c0536bd660b2921a96a37b814f9accc76f5cd9
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

MONGODB_VERSION:=3.0.6
MONGODB_NAME:=mongodb
MONGODB:=$(MONGODB_NAME)-$(MONGODB_VERSION)
MONGODB_DIGEST:=md5
MONGODB_CHECKSUM:=68f58028bb98ff7b97c4b37ebc20380c
MONGODB_URL:=https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-$(MONGODB_VERSION).tgz
MONGODB_INSTALL_MARKER:=$(MONGODB_NAME)$(VERSION_SEP)$(MONGODB_VERSION)

MORA_VERSION:=0c409c9cbb283708e92cc69a50281ac536f97874
MORA_NAME:=mora
MORA:=$(MORA_NAME)-$(MORA_VERSION)
MORA_DIGEST:=md5
MORA_CHECKSUM:=563945c899b30099543254df84b487d7
MORA_URL:=https://github.com/emicklei/mora/archive/$(MORA_VERSION).tar.gz
MORA_DEPENDENCIES_CHECKSUM:=$(shell openssl md5 build/mora_glide.yaml | sed 's/^.* //')
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

UNBOUND_VERSION:=1.5.4
UNBOUND_NAME:=unbound
UNBOUND:=$(UNBOUND_NAME)-$(UNBOUND_VERSION)
UNBOUND_DIGEST:=sha256
UNBOUND_CHECKSUM:=a1e1c1a578cf8447cb51f6033714035736a0f04444854a983123c094cc6fb137
UNBOUND_URL:=https://www.unbound.net/downloads/unbound-$(UNBOUND_VERSION).tar.gz
UNBOUND_INSTALL_MARKER:=$(UNBOUND_NAME)$(VERSION_SEP)$(UNBOUND_VERSION)

# Define non-file/folder targets
.PHONY: \
	all \
	clean \
	dependencies \
	install \
	install_app_dependencies \
	install_dependencies \
	install_test_dependencies \
	lint \
	test

all: dependencies

deps:
	mkdir -p $@

deps/GeoLite2-City.md5: | deps
	curl -L -o $@ https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.md5
	touch $@

deps/GeoLite2-City.mmdb.gz: | deps
	curl -L -o $@ https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz
	touch $@

deps/GeoLite2-City.mmdb: deps/GeoLite2-City.mmdb.gz deps/GeoLite2-City.md5
	gunzip -c $< > $@
	openssl md5 $@ | grep `cat deps/GeoLite2-City.md5` || (echo "checksum mismatch $@" && exit 1)
	touch $@

# ngx_dyups
deps/$(NGX_DYUPS).tar.gz: | deps
	curl -L -o $@ $(NGX_DYUPS_URL)

deps/$(NGX_DYUPS): deps/$(NGX_DYUPS).tar.gz
	openssl $(NGX_DYUPS_DIGEST) $< | grep $(NGX_DYUPS_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# ngx_geoip2
deps/$(NGX_GEOIP2).tar.gz: | deps
	curl -L -o $@ $(NGX_GEOIP2_URL)

deps/$(NGX_GEOIP2): deps/$(NGX_GEOIP2).tar.gz
	openssl $(NGX_GEOIP2_DIGEST) $< | grep $(NGX_GEOIP2_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# ngx_txid
deps/$(NGX_TXID).tar.gz: | deps
	curl -L -o $@ $(NGX_TXID_URL)

deps/$(NGX_TXID): deps/$(NGX_TXID).tar.gz
	openssl $(NGX_TXID_DIGEST) $< | grep $(NGX_TXID_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# OpenResty
deps/$(OPENRESTY).tar.gz: | deps
	curl -L -o $@ $(OPENRESTY_URL)

deps/$(OPENRESTY): deps/$(OPENRESTY).tar.gz
	openssl $(OPENRESTY_DIGEST) $< | grep $(OPENRESTY_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(OPENRESTY)/.built: deps/$(OPENRESTY) deps/$(NGX_DYUPS) deps/$(NGX_GEOIP2) deps/$(NGX_TXID) deps/$(LIBMAXMINDDB)/.built
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty \
		--with-cc-opt="-I$(PWD)/deps/$(LIBMAXMINDDB)/include" \
		--with-ld-opt="-L$(PWD)/deps/$(LIBMAXMINDDB)/src/.libs -Wl,-rpath,$(PREFIX)/embedded/lib" \
		--error-log-path=stderr \
		--with-ipv6 \
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

# libcidr
deps/$(LIBCIDR).tar.xz: | deps
	curl -L -o $@ $(LIBCIDR_URL)

deps/$(LIBCIDR): deps/$(LIBCIDR).tar.xz
	openssl $(LIBCIDR_DIGEST) $< | grep $(LIBCIDR_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(LIBCIDR)/.built: deps/$(LIBCIDR)
	cd $< && make PREFIX=$(PREFIX)/embedded
	touch $@

# libmaxminddb
deps/$(LIBMAXMINDDB).tar.gz: | deps
	curl -L -o $@ $(LIBMAXMINDDB_URL)

deps/$(LIBMAXMINDDB): deps/$(LIBMAXMINDDB).tar.gz
	openssl $(LIBMAXMINDDB_DIGEST) $< | grep $(LIBMAXMINDDB_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(LIBMAXMINDDB)/.built: deps/$(LIBMAXMINDDB)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded
	cd $< && make
	touch $@

# LuaRocks
deps/$(LUAROCKS).tar.gz: | deps
	curl -L -o $@ $(LUAROCKS_URL)

deps/$(LUAROCKS): deps/$(LUAROCKS).tar.gz
	openssl $(LUAROCKS_DIGEST) $< | grep $(LUAROCKS_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# lua-resty-dns-cache
deps/$(LUA_RESTY_DNS_CACHE).tar.gz: | deps
	curl -L -o $@ $(LUA_RESTY_DNS_CACHE_URL)

deps/$(LUA_RESTY_DNS_CACHE): deps/$(LUA_RESTY_DNS_CACHE).tar.gz
	openssl $(LUA_RESTY_DNS_CACHE_DIGEST) $< | grep $(LUA_RESTY_DNS_CACHE_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# lua-resty-http
deps/$(LUA_RESTY_HTTP).tar.gz: | deps
	curl -L -o $@ $(LUA_RESTY_HTTP_URL)

deps/$(LUA_RESTY_HTTP): deps/$(LUA_RESTY_HTTP).tar.gz
	openssl $(LUA_RESTY_HTTP_DIGEST) $< | grep $(LUA_RESTY_HTTP_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# lua-resty-logger-socket
deps/$(LUA_RESTY_LOGGER_SOCKET).tar.gz: | deps
	curl -L -o $@ $(LUA_RESTY_LOGGER_SOCKET_URL)

deps/$(LUA_RESTY_LOGGER_SOCKET): deps/$(LUA_RESTY_LOGGER_SOCKET).tar.gz
	openssl $(LUA_RESTY_LOGGER_SOCKET_DIGEST) $< | grep $(LUA_RESTY_LOGGER_SOCKET_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# lua-resty-shcache
deps/$(LUA_RESTY_SHCACHE).tar.gz: | deps
	curl -L -o $@ $(LUA_RESTY_SHCACHE_URL)

deps/$(LUA_RESTY_SHCACHE): deps/$(LUA_RESTY_SHCACHE).tar.gz
	openssl $(LUA_RESTY_SHCACHE_DIGEST) $< | grep $(LUA_RESTY_SHCACHE_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# lustache
deps/$(LUSTACHE).tar.gz: | deps
	curl -L -o $@ $(LUSTACHE_URL)

deps/$(LUSTACHE): deps/$(LUSTACHE).tar.gz
	openssl $(LUSTACHE_DIGEST) $< | grep $(LUSTACHE_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# Mora
deps/$(MORA).tar.gz: | deps
	curl -L -o $@ $(MORA_URL)

deps/$(MORA): deps/$(MORA).tar.gz
	openssl $(MORA_DIGEST) $< | grep $(MORA_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/gocode/src/github.com/emicklei/mora: | deps/$(MORA)
	mkdir -p $@
	rsync -a --delete-after deps/$(MORA)/ $@/
	touch $@

deps/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM): deps/gocode/src/github.com/emicklei/mora deps/$(GLIDE)/.built deps/$(GOLANG)
	cp build/mora_glide.yaml $</glide.yaml
	cd $< && PATH=$(ROOT_DIR)/deps/$(GOLANG)/bin:$(ROOT_DIR)/deps/gocode/bin:$(PATH) GOPATH=$(ROOT_DIR)/deps/gocode GOROOT=$(ROOT_DIR)/deps/$(GOLANG) GO15VENDOREXPERIMENT=1 glide update
	cd $< && PATH=$(ROOT_DIR)/deps/$(GOLANG)/bin:$(ROOT_DIR)/deps/gocode/bin:$(PATH) GOPATH=$(ROOT_DIR)/deps/gocode GOROOT=$(ROOT_DIR)/deps/$(GOLANG) GO15VENDOREXPERIMENT=1 go install
	touch $@

# Perp
deps/$(PERP).tar.gz: | deps
	curl -L -o $@ $(PERP_URL)

deps/$(PERP): deps/$(PERP).tar.gz
	openssl $(PERP_DIGEST) $< | grep $(PERP_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(PERP)/.built: deps/$(PERP)
	sed -i -e 's#BINDIR.*#BINDIR = $(PREFIX)/embedded/bin#' $</conf.mk
	sed -i -e 's#SBINDIR.*#SBINDIR = $(PREFIX)/embedded/sbin#' $</conf.mk
	sed -i -e 's#MANDIR.*#MANDIR = $(PREFIX)/embedded/share/man#' $</conf.mk
	cd $< && make && make strip
	touch $@

# Ruby
deps/$(RUBY).tar.gz: | deps
	curl -L -o $@ $(RUBY_URL)

deps/$(RUBY): deps/$(RUBY).tar.gz
	openssl $(RUBY_DIGEST) $< | grep $(RUBY_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(RUBY)/.built: | deps/$(RUBY)
	cd deps/$(RUBY) && ./configure \
		--prefix=$(PREFIX)/embedded \
		--enable-load-relative \
		--disable-install-doc
	cd deps/$(RUBY) && make
	touch $@

# ElasticSearch
deps/$(ELASTICSEARCH).tar.gz: | deps
	curl -L -o $@ $(ELASTICSEARCH_URL)

deps/$(ELASTICSEARCH): deps/$(ELASTICSEARCH).tar.gz
	openssl $(ELASTICSEARCH_DIGEST) $< | grep $(ELASTICSEARCH_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# Glide
deps/$(GLIDE).tar.gz: | deps
	curl -L -o $@ $(GLIDE_URL)

deps/$(GLIDE): deps/$(GLIDE).tar.gz
	openssl $(GLIDE_DIGEST) $< | grep $(GLIDE_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/gocode/src/github.com/Masterminds/glide: | deps/$(GLIDE)
	mkdir -p $@
	rsync -a --delete-after deps/$(GLIDE)/ $@/
	touch $@

deps/$(GLIDE)/.built: deps/gocode/src/github.com/Masterminds/glide deps/$(GOLANG)
	cd $< && PATH=$(ROOT_DIR)/deps/$(GOLANG)/bin:$(PATH) GOPATH=$(ROOT_DIR)/deps/gocode GOROOT=$(ROOT_DIR)/deps/$(GOLANG) go get
	cd $< && PATH=$(ROOT_DIR)/deps/$(GOLANG)/bin:$(PATH) GOPATH=$(ROOT_DIR)/deps/gocode GOROOT=$(ROOT_DIR)/deps/$(GOLANG) go build
	touch $@

# Go
deps/$(GOLANG).tar.gz: | deps
	curl -L -o $@ $(GOLANG_URL)

deps/$(GOLANG): deps/$(GOLANG).tar.gz
	openssl $(GOLANG_DIGEST) $< | grep $(GOLANG_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# Heka
deps/$(HEKA).tar.gz: | deps
	curl -L -o $@ $(HEKA_URL)

deps/$(HEKA): deps/$(HEKA).tar.gz
	openssl $(HEKA_DIGEST) $< | grep $(HEKA_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# MongoDB
deps/$(MONGODB).tar.gz: | deps
	curl -L -o $@ $(MONGODB_URL)

deps/$(MONGODB): deps/$(MONGODB).tar.gz
	openssl $(MONGODB_DIGEST) $< | grep $(MONGODB_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# TrafficServer
deps/$(TRAFFICSERVER).tar.gz: | deps
	curl -L -o $@ $(TRAFFICSERVER_URL)

deps/$(TRAFFICSERVER): deps/$(TRAFFICSERVER).tar.gz
	openssl $(TRAFFICSERVER_DIGEST) $< | grep $(TRAFFICSERVER_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(TRAFFICSERVER)/.built: deps/$(TRAFFICSERVER)
	cd $< && PATH=$(STANDARD_PATH) ./configure \
		--prefix=$(PREFIX)/embedded \
		--enable-experimental-plugins
	cd $< && make
	touch $@

# Unbound
deps/$(UNBOUND).tar.gz: | deps
	curl -L -o $@ $(UNBOUND_URL)

deps/$(UNBOUND): deps/$(UNBOUND).tar.gz
	openssl $(UNBOUND_DIGEST) $< | grep $(UNBOUND_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(UNBOUND)/.built: deps/$(UNBOUND)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded
	cd $< && make
	touch $@

dependencies: \
	deps/$(ELASTICSEARCH) \
	deps/GeoLite2-City.mmdb \
	deps/$(HEKA) \
	deps/$(LIBCIDR)/.built \
	deps/$(LIBMAXMINDDB)/.built \
	deps/$(LUAROCKS) \
	deps/$(MONGODB) \
	deps/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM) \
	deps/$(OPENRESTY)/.built \
	deps/$(PERP)/.built \
	deps/$(RUBY)/.built \
	deps/$(TRAFFICSERVER)/.built

clean:
	rm -rf deps

$(PREFIX)/embedded/bin:
	mkdir -p $(PREFIX)/embedded/bin
	touch $@

$(PREFIX)/embedded/sbin:
	mkdir -p $(PREFIX)/embedded/sbin
	touch $@

$(INSTALLED_DIR):
	mkdir -p $@
	touch $@

$(INSTALLED_DIR)/$(BUNDLER_INSTALL_MARKER): | $(INSTALLED_DIR) $(INSTALLED_DIR)/$(RUBY_INSTALL_MARKER)
	PATH=$(PREFIX)/embedded/bin:$(PATH) gem install bundler -v '$(BUNDLER_VERSION)' --no-rdoc --no-ri
	rm -f $(INSTALLED_DIR)/$(BUNDLER_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(ELASTICSEARCH_INSTALL_MARKER): deps/$(ELASTICSEARCH) | $(INSTALLED_DIR)
	rsync -a deps/$(ELASTICSEARCH)/ $(PREFIX)/embedded/elasticsearch/
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/plugin $(PREFIX)/embedded/bin/plugin
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/elasticsearch $(PREFIX)/embedded/bin/elasticsearch
	rm -f $(INSTALLED_DIR)/$(ELASTICSEARCH_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/GeoLite2-City.mmdb: deps/GeoLite2-City.mmdb | $(INSTALLED_DIR)
	mkdir -p $(PREFIX)/embedded/var/db/geoip2
	rsync -a deps/GeoLite2-City.mmdb $(PREFIX)/embedded/var/db/geoip2/city.mmdb
	touch $@

$(INSTALLED_DIR)/$(HEKA_INSTALL_MARKER): deps/$(HEKA) | $(INSTALLED_DIR)
	rsync -a deps/$(HEKA)/ $(PREFIX)/embedded/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(PREFIX)/embedded/bin/heka-cat \
		$(PREFIX)/embedded/bin/heka-flood \
		$(PREFIX)/embedded/bin/heka-inject \
		$(PREFIX)/embedded/bin/heka-sbmgr
	rm -f $(INSTALLED_DIR)/$(HEKA_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(LIBCIDR_INSTALL_MARKER): deps/$(LIBCIDR)/.built | $(INSTALLED_DIR)
	cd deps/$(LIBCIDR) && make install PREFIX=$(PREFIX)/embedded
	rm -f $(INSTALLED_DIR)/$(LIBCIDR_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(LIBMAXMINDDB_INSTALL_MARKER): deps/$(LIBMAXMINDDB)/.built | $(INSTALLED_DIR)
	cd deps/$(LIBMAXMINDDB) && make install
	rm -f $(INSTALLED_DIR)/$(LIBMAXMINDDB_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER): deps/$(LUAROCKS) | $(INSTALLED_DIR) $(INSTALLED_DIR)/$(OPENRESTY_INSTALL_MARKER)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty/luajit \
		--with-lua=$(PREFIX)/embedded/openresty/luajit/ \
		--with-lua-include=$(PREFIX)/embedded/openresty/luajit/include/luajit-2.1 \
		--lua-suffix=jit-2.1.0-alpha
	cd $< && env -i make build && env -i make install
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luarocks $(PREFIX)/embedded/bin/luarocks
	rm -f $(INSTALLED_DIR)/$(LUAROCKS_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(MONGODB_INSTALL_MARKER): deps/$(MONGODB) | $(INSTALLED_DIR)
	rsync -a deps/$(MONGODB)/ $(PREFIX)/embedded/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(PREFIX)/embedded/bin/bsondump \
		$(PREFIX)/embedded/bin/mongoexport \
		$(PREFIX)/embedded/bin/mongofiles \
		$(PREFIX)/embedded/bin/mongoimport \
		$(PREFIX)/embedded/bin/mongooplog \
		$(PREFIX)/embedded/bin/mongoperf \
		$(PREFIX)/embedded/bin/mongos
	rm -f $(INSTALLED_DIR)/$(MONGODB_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(MORA_INSTALL_MARKER): deps/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM) | $(INSTALLED_DIR)
	cp deps/gocode/bin/mora $(PREFIX)/embedded/bin/
	rm -f $(INSTALLED_DIR)/$(MORA_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(OPENRESTY_INSTALL_MARKER): deps/$(OPENRESTY)/.built | $(INSTALLED_DIR)
	cd deps/$(OPENRESTY) && make install
	ln -sf $(PREFIX)/embedded/openresty/bin/resty $(PREFIX)/embedded/bin/resty
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luajit-2.1.0-alpha $(PREFIX)/embedded/bin/luajit
	ln -sf $(PREFIX)/embedded/openresty/nginx/sbin/nginx $(PREFIX)/embedded/sbin/nginx
	rm -f $(INSTALLED_DIR)/$(OPENRESTY_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(PERP_INSTALL_MARKER): deps/$(PERP)/.built | $(INSTALLED_DIR)
	cd deps/$(PERP) && make install
	rm -f $(INSTALLED_DIR)/$(PERP_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(RUBY_INSTALL_MARKER): deps/$(RUBY)/.built | $(INSTALLED_DIR)
	cd deps/$(RUBY) && make install
	rm -f $(INSTALLED_DIR)/$(RUBY_NAME)$(VERSION_SEP)*
	touch $@

$(INSTALLED_DIR)/$(TRAFFICSERVER_INSTALL_MARKER): deps/$(TRAFFICSERVER)/.built | $(INSTALLED_DIR)
	cd deps/$(TRAFFICSERVER) && make install
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(PREFIX)/embedded/bin/traffic_sac
	rm -f $(INSTALLED_DIR)/$(TRAFFICSERVER_NAME)$(VERSION_SEP)*
	touch $@

.SECONDARY: \
	deps/$(ELASTICSEARCH).tar.gz \
	deps/$(ELASTICSEARCH) \
	deps/GeoLite2-City.md5 \
	deps/GeoLite2-City.mmdb.gz \
	deps/GeoLite2-City.mmdb \
	deps/$(GLIDE).tar.gz \
	deps/$(GLIDE) \
	deps/gocode/src/github.com/Masterminds/glide \
	deps/$(GLIDE)/.built \
	deps/$(GOLANG).tar.gz \
	deps/$(GOLANG) \
	deps/$(HEKA).tar.gz \
	deps/$(HEKA) \
	deps/$(LIBCIDR).tar.xz \
	deps/$(LIBCIDR) \
	deps/$(LIBCIDR)/.built \
	deps/$(LIBMAXMINDDB).tar.gz \
	deps/$(LIBMAXMINDDB) \
	deps/$(LIBMAXMINDDB)/.built \
	deps/$(LUAROCKS).tar.gz \
	deps/$(LUAROCKS) \
	deps/$(LUA_RESTY_DNS_CACHE).tar.gz \
	deps/$(LUA_RESTY_DNS_CACHE) \
	deps/$(LUA_RESTY_HTTP).tar.gz \
	deps/$(LUA_RESTY_HTTP) \
	deps/$(LUA_RESTY_LOGGER_SOCKET).tar.gz \
	deps/$(LUA_RESTY_LOGGER_SOCKET) \
	deps/$(LUA_RESTY_SHCACHE).tar.gz \
	deps/$(LUA_RESTY_SHCACHE) \
	deps/$(LUSTACHE).tar.gz \
	deps/$(LUSTACHE) \
	deps/$(MONGODB).tar.gz \
	deps/$(MONGODB) \
	deps/$(MORA).tar.gz \
	deps/$(MORA) \
	deps/gocode/src/github.com/emicklei/mora \
	deps/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM) \
	deps/$(NGX_DYUPS).tar.gz \
	deps/$(NGX_DYUPS) \
	deps/$(NGX_GEOIP2).tar.gz \
	deps/$(NGX_GEOIP2) \
	deps/$(NGX_TXID).tar.gz \
	deps/$(NGX_TXID) \
	deps/$(OPENRESTY).tar.gz \
	deps/$(OPENRESTY) \
	deps/$(OPENRESTY)/.built \
	deps/$(LUAROCKS).tar.gz \
	deps/$(LUAROCKS) \
	deps/$(PERP).tar.gz \
	deps/$(PERP) \
	deps/$(PERP)/.built \
	deps/$(RUBY).tar.gz \
	deps/$(RUBY) \
	deps/$(RUBY)/.built \
	deps/$(TRAFFICSERVER).tar.gz \
	deps/$(TRAFFICSERVER) \
	deps/$(TRAFFICSERVER)/.built \
	deps/$(UNBOUND).tar.gz \
	deps/$(UNBOUND) \
	deps/$(UNBOUND)/.built

install_dependencies: \
	$(PREFIX)/embedded/bin \
	$(PREFIX)/embedded/sbin \
	$(INSTALLED_DIR)/$(BUNDLER_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(ELASTICSEARCH_INSTALL_MARKER) \
	$(INSTALLED_DIR)/GeoLite2-City.mmdb \
	$(INSTALLED_DIR)/$(HEKA_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(LIBCIDR_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(LIBMAXMINDDB_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(MONGODB_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(MORA_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(OPENRESTY_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(PERP_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(RUBY_INSTALL_MARKER) \
	$(INSTALLED_DIR)/$(TRAFFICSERVER_INSTALL_MARKER)

vendor:
	mkdir -p $@

INSPECT:=inspect
INSPECT_VERSION:=3.0-1
LIBCIDR_FFI:=libcidr-ffi
LIBCIDR_FFI_VERSION:=0.1.0-1
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

vendor/bundle: src/api-umbrella/web-app/Gemfile src/api-umbrella/web-app/Gemfile.lock | vendor $(INSTALLED_DIR)/$(BUNDLER_INSTALL_MARKER)
	cd src/api-umbrella/web-app && PATH=$(PREFIX)/embedded/bin:$(PATH) bundle install --path=$(PWD)/vendor/bundle
	cd src/api-umbrella/web-app && PATH=$(PREFIX)/embedded/bin:$(PATH) bundle clean
	touch $@

$(LUAROCKS_DIR)/$(INSPECT)/$(INSPECT_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(INSPECT)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(INSPECT) $(INSPECT_VERSION)
	touch $@

$(LUAROCKS_DIR)/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(LIBCIDR_FFI)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install https://raw.githubusercontent.com/GUI/lua-libcidr-ffi/master/libcidr-ffi-git-1.rockspec CIDR_DIR=$(PREFIX)/embedded
	touch $@

$(LUAROCKS_DIR)/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(LUA_CMSGPACK)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUA_CMSGPACK) $(LUA_CMSGPACK_VERSION)
	touch $@

$(LUAROCKS_DIR)/$(LUAPOSIX)/$(LUAPOSIX_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(LUAPOSIX)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUAPOSIX) $(LUAPOSIX_VERSION)
	touch $@

$(LUAROCKS_DIR)/$(LUASOCKET)/$(LUASOCKET_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(LUASOCKET)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUASOCKET) $(LUASOCKET_VERSION)
	touch $@

$(LUAROCKS_DIR)/$(LYAML)/$(LYAML_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(LYAML)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LYAML) $(LYAML_VERSION)
	touch $@

$(LUAROCKS_DIR)/$(PENLIGHT)/$(PENLIGHT_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(PENLIGHT)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(PENLIGHT) $(PENLIGHT_VERSION)
	touch $@

vendor/share/lua/5.1/resty/dns/cache.lua: deps/$(LUA_RESTY_DNS_CACHE) | vendor
	rsync -a deps/$(LUA_RESTY_DNS_CACHE)/lib/resty/ vendor/share/lua/5.1/resty/
	touch $@

vendor/share/lua/5.1/resty/http.lua: deps/$(LUA_RESTY_HTTP) | vendor
	rsync -a deps/$(LUA_RESTY_HTTP)/lib/resty/ vendor/share/lua/5.1/resty/
	touch $@

vendor/share/lua/5.1/resty/logger/socket.lua: deps/$(LUA_RESTY_LOGGER_SOCKET) | vendor
	rsync -a deps/$(LUA_RESTY_LOGGER_SOCKET)/lib/resty/ vendor/share/lua/5.1/resty/
	touch $@

vendor/share/lua/5.1/shcache.lua: deps/$(LUA_RESTY_SHCACHE) | vendor
	rsync -a deps/$(LUA_RESTY_SHCACHE)/*.lua vendor/share/lua/5.1/
	touch $@

vendor/share/lua/5.1/lustache.lua: deps/$(LUSTACHE) | vendor
	rsync -a deps/$(LUSTACHE)/src/ vendor/share/lua/5.1/
	touch $@

install_app_dependencies: \
	vendor/bundle \
	$(LUAROCKS_DIR)/$(INSPECT)/$(INSPECT_VERSION) \
	$(LUAROCKS_DIR)/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION) \
	$(LUAROCKS_DIR)/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION) \
	$(LUAROCKS_DIR)/$(LUAPOSIX)/$(LUAPOSIX_VERSION) \
	$(LUAROCKS_DIR)/$(LUASOCKET)/$(LUASOCKET_VERSION) \
	$(LUAROCKS_DIR)/$(LYAML)/$(LYAML_VERSION) \
	$(LUAROCKS_DIR)/$(PENLIGHT)/$(PENLIGHT_VERSION) \
	vendor/share/lua/5.1/lustache.lua \
	vendor/share/lua/5.1/resty/dns/cache.lua \
	vendor/share/lua/5.1/resty/http.lua \
	vendor/share/lua/5.1/resty/logger/socket.lua \
	vendor/share/lua/5.1/shcache.lua

install: install_dependencies install_app_dependencies

LUACHECK:=luacheck
LUACHECK_VERSION:=0.11.1-1

# luacheck
$(LUAROCKS_DIR)/$(LUACHECK)/$(LUACHECK_VERSION): | $(INSTALLED_DIR)/$(LUAROCKS_INSTALL_MARKER) vendor
	rm -rf $(LUAROCKS_DIR)/$(LUACHECK)
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUACHECK) $(LUACHECK_VERSION)
	touch $@

# Node test dependencies
node_modules/.installed: package.json
	npm install
	npm prune
	touch $@

# Python test dependencies (mongo-orchestration)
$(PREFIX)/embedded/bin/pip:
	virtualenv $(PREFIX)/embedded
	touch $@

$(INSTALLED_DIR)/test-python-requirements: test/requirements.txt $(PREFIX)/embedded/bin/pip | $(INSTALLED_DIR)
	$(PREFIX)/embedded/bin/pip install -r test/requirements.txt
	touch $@

$(INSTALLED_DIR)/$(UNBOUND_INSTALL_MARKER): deps/$(UNBOUND)/.built | $(INSTALLED_DIR)
	cd deps/$(UNBOUND) && make install
	touch $@

install_test_dependencies: \
	node_modules/.installed \
	$(LUAROCKS_DIR)/$(LUACHECK)/$(LUACHECK_VERSION) \
	$(INSTALLED_DIR)/test-python-requirements \
	$(INSTALLED_DIR)/$(UNBOUND_INSTALL_MARKER)

lint: install_test_dependencies
	LUA_PATH="vendor/share/lua/5.1/?.lua;vendor/share/lua/5.1/?/init.lua;;" LUA_CPATH="vendor/lib/lua/5.1/?.so;;" ./vendor/bin/luacheck src

test: install install_test_dependencies lint
	API_UMBRELLA_INSTALL_ROOT=$(PREFIX) MOCHA_FILES="$(MOCHA_FILES)" npm test

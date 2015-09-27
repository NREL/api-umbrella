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

BUNDLER_VERSION:=1.10.6
BUNDLER:=bundler-$(BUNDLER_VERSION)

ELASTICSEARCH_VERSION:=1.7.1
ELASTICSEARCH:=elasticsearch-$(ELASTICSEARCH_VERSION)
ELASTICSEARCH_DIGEST:=sha1
ELASTICSEARCH_CHECKSUM:=0984ae27624e57c12c33d4a559c3ebae25e74508
ELASTICSEARCH_URL:=https://download.elastic.co/elasticsearch/elasticsearch/$(ELASTICSEARCH).tar.gz

GLIDE_VERSION:=0.5.1
GLIDE:=glide-$(GLIDE_VERSION)
GLIDE_DIGEST:=md5
GLIDE_CHECKSUM:=aa42b90eab0b23c47283ad4f9de8dc8f
GLIDE_URL:=https://github.com/Masterminds/glide/archive/$(GLIDE_VERSION).tar.gz

GOLANG_VERSION:=1.5
GOLANG:=golang-$(GOLANG_VERSION)
GOLANG_DIGEST:=sha1
GOLANG_CHECKSUM:=5817fa4b2252afdb02e11e8b9dc1d9173ef3bd5a
GOLANG_URL:=https://storage.googleapis.com/golang/go$(GOLANG_VERSION).linux-amd64.tar.gz

HEKA_VERSION:=0.9.2
HEKA_VERSION_UNDERSCORE:=$(shell echo $(HEKA_VERSION) | sed -e 's/\./_/g')
HEKA:=heka-$(HEKA_VERSION)
HEKA_DIGEST:=md5
HEKA_CHECKSUM:=864625dff702306eba1494149ff903ee
HEKA_URL:=https://github.com/mozilla-services/heka/releases/download/v$(HEKA_VERSION)/heka-$(HEKA_VERSION_UNDERSCORE)-linux-amd64.tar.gz

LIBCIDR_VERSION:=1.2.3
LIBCIDR:=libcidr-$(LIBCIDR_VERSION)
LIBCIDR_DIGEST:=md5
LIBCIDR_CHECKSUM:=c5efcc7ae114fdaa5583f58dacecd9de
LIBCIDR_URL:=https://www.over-yonder.net/~fullermd/projects/libcidr/$(LIBCIDR).tar.xz

LIBMAXMINDDB_VERSION:=1.1.1
LIBMAXMINDDB:=libmaxminddb-$(LIBMAXMINDDB_VERSION)
LIBMAXMINDDB_DIGEST:=md5
LIBMAXMINDDB_CHECKSUM:=36c31f0814dbf71b210ee57c2b9ef98c
LIBMAXMINDDB_URL:=https://github.com/maxmind/libmaxminddb/releases/download/$(LIBMAXMINDDB_VERSION)/$(LIBMAXMINDDB).tar.gz

LIBYAML_VERSION:=0.1.6
LIBYAML:=libyaml-$(LIBYAML_VERSION)
LIBYAML_DIGEST:=md5
LIBYAML_CHECKSUM:=5fe00cda18ca5daeb43762b80c38e06e
LIBYAML_URL:=http://pyyaml.org/download/libyaml/yaml-$(LIBYAML_VERSION).tar.gz

LUA_RESTY_DNS_CACHE_VERSION:=691613739a32f8405e56e56547270b9f72e77c34
LUA_RESTY_DNS_CACHE:=lua-resty-dns-cache-$(LUA_RESTY_DNS_CACHE_VERSION)
LUA_RESTY_DNS_CACHE_DIGEST:=md5
LUA_RESTY_DNS_CACHE_CHECKSUM:=c7304c1f434ac251246904db51423d5e
LUA_RESTY_DNS_CACHE_URL:=https://github.com/hamishforbes/lua-resty-dns-cache/archive/$(LUA_RESTY_DNS_CACHE_VERSION).tar.gz

LUA_RESTY_HTTP_VERSION:=0.06
LUA_RESTY_HTTP:=lua-resty-http-$(LUA_RESTY_HTTP_VERSION)
LUA_RESTY_HTTP_DIGEST:=md5
LUA_RESTY_HTTP_CHECKSUM:=d828ba0da7bc8f39e0ce0565912aa597
LUA_RESTY_HTTP_URL:=https://github.com/pintsized/lua-resty-http/archive/v$(LUA_RESTY_HTTP_VERSION).tar.gz

LUA_RESTY_LOGGER_SOCKET_VERSION:=89864590fea7273bff37925d11e7fc4239bb2f8c
LUA_RESTY_LOGGER_SOCKET:=lua-resty-logger-socket-$(LUA_RESTY_LOGGER_SOCKET_VERSION)
LUA_RESTY_LOGGER_SOCKET_DIGEST:=md5
LUA_RESTY_LOGGER_SOCKET_CHECKSUM:=847c220a6d93262fc001e9761de9bcf0
LUA_RESTY_LOGGER_SOCKET_URL:=https://github.com/cloudflare/lua-resty-logger-socket/archive/$(LUA_RESTY_LOGGER_SOCKET_VERSION).tar.gz

LUA_RESTY_SHCACHE_VERSION:=fb2e275c2cdca08eaa34a7b73375e41ac3eff200
LUA_RESTY_SHCACHE:=lua-resty-shcache-$(LUA_RESTY_SHCACHE_VERSION)
LUA_RESTY_SHCACHE_DIGEST:=md5
LUA_RESTY_SHCACHE_CHECKSUM:=5d3cbcf8fbad1954cdcb3826afa41afe
LUA_RESTY_SHCACHE_URL:=https://github.com/cloudflare/lua-resty-shcache/archive/$(LUA_RESTY_SHCACHE_VERSION).tar.gz

LUAROCKS_VERSION:=2.0.13
LUAROCKS:=luarocks-$(LUAROCKS_VERSION)
LUAROCKS_DIGEST:=md5
LUAROCKS_CHECKSUM:=b46809e44648875e8234c2fef79783f9
LUAROCKS_URL:=http://pkgs.fedoraproject.org/repo/pkgs/luarocks/$(LUAROCKS).tar.gz/$(LUAROCKS_CHECKSUM)/$(LUAROCKS).tar.gz

LUSTACHE_VERSION:=241b3a16f358035887c2c05c6e151c1f48401a42
LUSTACHE:=lustache-$(LUSTACHE_VERSION)
LUSTACHE_DIGEST:=md5
LUSTACHE_CHECKSUM:=7c64dd36bbb02e71a0e60e847b70d561
LUSTACHE_URL:=https://github.com/Olivine-Labs/lustache/archive/$(LUSTACHE_VERSION).tar.gz

MONGODB_VERSION:=3.0.6
MONGODB:=mongodb-$(MONGODB_VERSION)
MONGODB_DIGEST:=md5
MONGODB_CHECKSUM:=68f58028bb98ff7b97c4b37ebc20380c
MONGODB_URL:=https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-$(MONGODB_VERSION).tgz

MORA_VERSION:=0c409c9cbb283708e92cc69a50281ac536f97874
MORA:=mora-$(MORA_VERSION)
MORA_DIGEST:=md5
MORA_CHECKSUM:=563945c899b30099543254df84b487d7
MORA_URL:=https://github.com/emicklei/mora/archive/$(MORA_VERSION).tar.gz
MORA_DEPENDENCIES_CHECKSUM:=$(shell openssl md5 build/mora_glide.yaml | sed 's/^.* //')

NGX_TXID_VERSION:=f1c197cb9c42e364a87fbb28d5508e486592ca42
NGX_TXID:=ngx_txid-$(NGX_TXID_VERSION)
NGX_TXID_DIGEST:=md5
NGX_TXID_CHECKSUM:=408ee86eb6e42e27a51514f711c41d6b
NGX_TXID_URL:=https://github.com/streadway/ngx_txid/archive/$(NGX_TXID_VERSION).tar.gz

NGX_DYUPS_VERSION:=0.2.8
NGX_DYUPS:=ngx_http_dyups_module-v$(NGX_DYUPS_VERSION)
NGX_DYUPS_DIGEST:=md5
NGX_DYUPS_CHECKSUM:=295b7cb202de069b313f4da50d6952e0
NGX_DYUPS_URL:=https://github.com/yzprofile/ngx_http_dyups_module/archive/v$(NGX_DYUPS_VERSION).tar.gz

NGX_GEOIP2_VERSION:=1.0
NGX_GEOIP2:=ngx_http_geoip2_module-$(NGX_GEOIP2_VERSION)
NGX_GEOIP2_DIGEST:=md5
NGX_GEOIP2_CHECKSUM:=4c89eea53ce8318f940c03adfe0b502b
NGX_GEOIP2_URL:=https://github.com/leev/ngx_http_geoip2_module/archive/1.0.tar.gz

OPENRESTY_VERSION:=1.9.3.1
OPENRESTY:=ngx_openresty-$(OPENRESTY_VERSION)
OPENRESTY_DIGEST:=md5
OPENRESTY_CHECKSUM:=cde1f7127f6ba413ee257003e49d6d0a
OPENRESTY_URL:=http://openresty.org/download/$(OPENRESTY).tar.gz

PERP_VERSION:=2.07
PERP:=perp-$(PERP_VERSION)
PERP_DIGEST:=md5
PERP_CHECKSUM:=a2acc7425d556d9635a25addcee9edb5
PERP_URL:=http://b0llix.net/perp/distfiles/$(PERP).tar.gz

RUBY_VERSION:=2.2.3
RUBY:=ruby-$(RUBY_VERSION)
RUBY_DIGEST:=sha256
RUBY_CHECKSUM:=df795f2f99860745a416092a4004b016ccf77e8b82dec956b120f18bdc71edce
RUBY_URL:=https://cache.ruby-lang.org/pub/ruby/2.2/$(RUBY).tar.gz

TRAFFICSERVER_VERSION:=5.3.1
TRAFFICSERVER:=trafficserver-$(TRAFFICSERVER_VERSION)
TRAFFICSERVER_DIGEST:=md5
TRAFFICSERVER_CHECKSUM:=9c0e2450b1dd1bbdd63ebcc344b5a813
TRAFFICSERVER_URL:=http://mirror.olnevhost.net/pub/apache/trafficserver/$(TRAFFICSERVER).tar.bz2

UNBOUND_VERSION:=1.5.4
UNBOUND:=unbound-$(UNBOUND_VERSION)
UNBOUND_DIGEST:=sha256
UNBOUND_CHECKSUM:=a1e1c1a578cf8447cb51f6033714035736a0f04444854a983123c094cc6fb137
UNBOUND_URL:=https://www.unbound.net/downloads/$(UNBOUND).tar.gz

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
	cd $< make
	touch $@

# LibYAML
deps/$(LIBYAML).tar.gz: | deps
	curl -L -o $@ $(LIBYAML_URL)

deps/$(LIBYAML): deps/$(LIBYAML).tar.gz
	openssl $(LIBYAML_DIGEST) $< | grep $(LIBYAML_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/$(LIBYAML)/.built: deps/$(LIBYAML)
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

deps/gocode/src/github.com/emicklei/mora: deps/$(MORA)
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

deps/gocode/src/github.com/Masterminds/glide: deps/$(GLIDE)
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
	deps/$(LIBYAML)/.built \
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

$(PREFIX)/embedded/.installed:
	mkdir -p $(PREFIX)/embedded/.installed
	touch $@

$(PREFIX)/embedded/.installed/$(BUNDLER): | $(PREFIX)/embedded/.installed $(PREFIX)/embedded/.installed/$(RUBY)
	PATH=$(PREFIX)/embedded/bin:$(PATH) gem install bundler -v '$(BUNDLER_VERSION)' --no-rdoc --no-ri
	touch $@

$(PREFIX)/embedded/.installed/$(ELASTICSEARCH): deps/$(ELASTICSEARCH) | $(PREFIX)/embedded/.installed
	rsync -a deps/$(ELASTICSEARCH)/ $(PREFIX)/embedded/elasticsearch/
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/plugin $(PREFIX)/embedded/bin/plugin
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/elasticsearch $(PREFIX)/embedded/bin/elasticsearch
	touch $@

$(PREFIX)/embedded/.installed/GeoLite2-City.mmdb: deps/GeoLite2-City.mmdb | $(PREFIX)/embedded/.installed
	mkdir -p $(PREFIX)/embedded/var/db/geoip2
	rsync -a deps/GeoLite2-City.mmdb $(PREFIX)/embedded/var/db/geoip2/city.mmdb
	touch $@

$(PREFIX)/embedded/.installed/$(HEKA): deps/$(HEKA) | $(PREFIX)/embedded/.installed
	rsync -a deps/$(HEKA)/ $(PREFIX)/embedded/
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(PREFIX)/embedded/bin/heka-cat \
		$(PREFIX)/embedded/bin/heka-flood \
		$(PREFIX)/embedded/bin/heka-inject \
		$(PREFIX)/embedded/bin/heka-sbmgr
	touch $@

$(PREFIX)/embedded/.installed/$(LIBCIDR): deps/$(LIBCIDR)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(LIBCIDR) && make install PREFIX=$(PREFIX)/embedded
	touch $@

$(PREFIX)/embedded/.installed/$(LIBMAXMINDDB): deps/$(LIBMAXMINDDB)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(LIBMAXMINDDB) && make install
	touch $@

$(PREFIX)/embedded/.installed/$(LIBYAML): deps/$(LIBYAML)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(LIBYAML) && make install
	touch $@

$(PREFIX)/embedded/.installed/$(LUAROCKS): deps/$(LUAROCKS) | $(PREFIX)/embedded/.installed $(PREFIX)/embedded/.installed/$(OPENRESTY)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty/luajit \
		--with-lua=$(PREFIX)/embedded/openresty/luajit/ \
		--with-lua-include=$(PREFIX)/embedded/openresty/luajit/include/luajit-2.1 \
		--lua-suffix=jit-2.1.0-alpha
	cd $< && env -i make && env -i make install
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luarocks $(PREFIX)/embedded/bin/luarocks
	touch $@

$(PREFIX)/embedded/.installed/$(MONGODB): deps/$(MONGODB) | $(PREFIX)/embedded/.installed
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
	touch $@

$(PREFIX)/embedded/.installed/$(MORA)-$(MORA_DEPENDENCIES_CHECKSUM): deps/$(MORA)/.built-$(MORA_DEPENDENCIES_CHECKSUM) | $(PREFIX)/embedded/.installed
	cp deps/gocode/bin/mora $(PREFIX)/embedded/bin/
	touch $@

$(PREFIX)/embedded/.installed/$(OPENRESTY): deps/$(OPENRESTY)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(OPENRESTY) && make install
	ln -sf $(PREFIX)/embedded/openresty/bin/resty $(PREFIX)/embedded/bin/resty
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luajit-2.1.0-alpha $(PREFIX)/embedded/bin/luajit
	ln -sf $(PREFIX)/embedded/openresty/nginx/sbin/nginx $(PREFIX)/embedded/sbin/nginx
	touch $@

$(PREFIX)/embedded/.installed/$(PERP): deps/$(PERP)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(PERP) && make install
	touch $@

$(PREFIX)/embedded/.installed/$(RUBY): deps/$(RUBY)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(RUBY) && make install
	touch $@

$(PREFIX)/embedded/.installed/$(TRAFFICSERVER): deps/$(TRAFFICSERVER)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(TRAFFICSERVER) && make install
	# Trim our own distribution by removing some larger files we don't need for
	# API Umbrella.
	rm -f $(PREFIX)/embedded/bin/traffic_sac
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
	deps/$(LIBYAML).tar.gz \
	deps/$(LIBYAML) \
	deps/$(LIBYAML)/.built \
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
	$(PREFIX)/embedded/.installed/$(BUNDLER) \
	$(PREFIX)/embedded/.installed/$(ELASTICSEARCH) \
	$(PREFIX)/embedded/.installed/GeoLite2-City.mmdb \
	$(PREFIX)/embedded/.installed/$(HEKA) \
	$(PREFIX)/embedded/.installed/$(LIBCIDR) \
	$(PREFIX)/embedded/.installed/$(LIBMAXMINDDB) \
	$(PREFIX)/embedded/.installed/$(LIBYAML) \
	$(PREFIX)/embedded/.installed/$(LUAROCKS) \
	$(PREFIX)/embedded/.installed/$(MONGODB) \
	$(PREFIX)/embedded/.installed/$(MORA)-$(MORA_DEPENDENCIES_CHECKSUM) \
	$(PREFIX)/embedded/.installed/$(OPENRESTY) \
	$(PREFIX)/embedded/.installed/$(PERP) \
	$(PREFIX)/embedded/.installed/$(RUBY) \
	$(PREFIX)/embedded/.installed/$(TRAFFICSERVER)

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

vendor/bundle: src/api-umbrella/web-app/Gemfile src/api-umbrella/web-app/Gemfile.lock | vendor $(PREFIX)/embedded/.installed/$(BUNDLER)
	cd src/api-umbrella/web-app && PATH=$(PREFIX)/embedded/bin:$(PATH) bundle install --path=$(PWD)/vendor/bundle
	touch $@

vendor/lib/luarocks/rocks/$(INSPECT)/$(INSPECT_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(INSPECT) $(INSPECT_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install https://raw.githubusercontent.com/GUI/lua-libcidr-ffi/master/libcidr-ffi-git-1.rockspec CIDR_DIR=$(PREFIX)/embedded
	touch $@

vendor/lib/luarocks/rocks/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUA_CMSGPACK) $(LUA_CMSGPACK_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUAPOSIX)/$(LUAPOSIX_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUAPOSIX) $(LUAPOSIX_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUASOCKET)/$(LUASOCKET_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUASOCKET) $(LUASOCKET_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LYAML)/$(LYAML_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LYAML) $(LYAML_VERSION) YAML_DIR=$(PREFIX)/embedded
	touch $@

vendor/lib/luarocks/rocks/$(PENLIGHT)/$(PENLIGHT_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
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
	vendor/lib/luarocks/rocks/$(INSPECT)/$(INSPECT_VERSION) \
	vendor/lib/luarocks/rocks/$(LIBCIDR_FFI)/$(LIBCIDR_FFI_VERSION) \
	vendor/lib/luarocks/rocks/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION) \
	vendor/lib/luarocks/rocks/$(LUAPOSIX)/$(LUAPOSIX_VERSION) \
	vendor/lib/luarocks/rocks/$(LUASOCKET)/$(LUASOCKET_VERSION) \
	vendor/lib/luarocks/rocks/$(LYAML)/$(LYAML_VERSION) \
	vendor/lib/luarocks/rocks/$(PENLIGHT)/$(PENLIGHT_VERSION) \
	vendor/share/lua/5.1/lustache.lua \
	vendor/share/lua/5.1/resty/dns/cache.lua \
	vendor/share/lua/5.1/resty/http.lua \
	vendor/share/lua/5.1/resty/logger/socket.lua \
	vendor/share/lua/5.1/shcache.lua

install: install_dependencies install_app_dependencies

LUACHECK:=luacheck
LUACHECK_VERSION:=0.11.1-1

# luacheck
vendor/lib/luarocks/rocks/$(LUACHECK)/$(LUACHECK_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
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

$(PREFIX)/embedded/.installed/test-python-requirements: test/requirements.txt $(PREFIX)/embedded/bin/pip | $(PREFIX)/embedded/.installed
	$(PREFIX)/embedded/bin/pip install -r test/requirements.txt
	touch $@

$(PREFIX)/embedded/.installed/$(UNBOUND): deps/$(UNBOUND)/.built | $(PREFIX)/embedded/.installed
	cd deps/$(UNBOUND) && make install
	touch $@

install_test_dependencies: \
	node_modules/.installed \
	vendor/lib/luarocks/rocks/$(LUACHECK)/$(LUACHECK_VERSION) \
	$(PREFIX)/embedded/.installed/test-python-requirements \
	$(PREFIX)/embedded/.installed/$(UNBOUND)

lint: install_test_dependencies
	LUA_PATH="vendor/share/lua/5.1/?.lua;vendor/share/lua/5.1/?/init.lua;;" LUA_CPATH="vendor/lib/lua/5.1/?.so;;" ./vendor/bin/luacheck src

test: install install_test_dependencies lint
	API_UMBRELLA_INSTALL_ROOT=$(PREFIX) MOCHA_FILES="$(MOCHA_FILES)" npm test

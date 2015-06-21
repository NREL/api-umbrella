export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin

PREFIX:=/tmp/api-umbrella-build
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DNSMASQ_VERSION:=2.73
DNSMASQ:=dnsmasq-$(DNSMASQ_VERSION)
DNSMASQ_DIGEST:=md5
DNSMASQ_CHECKSUM:=c2d56b11317336bc788ded4298642e2e
DNSMASQ_URL:=http://www.thekelleys.org.uk/dnsmasq/$(DNSMASQ).tar.gz

ELASTICSEARCH_VERSION:=1.6.0
ELASTICSEARCH:=elasticsearch-$(ELASTICSEARCH_VERSION)
ELASTICSEARCH_DIGEST:=sha1
ELASTICSEARCH_CHECKSUM:=cb8522f5d3daf03ef96ed533d027c0e3d494e34b
ELASTICSEARCH_URL:=https://download.elastic.co/elasticsearch/elasticsearch/$(ELASTICSEARCH).tar.gz

FREEGEOIP_VERSION:=3.0.4
FREEGEOIP:=freegeoip-$(FREEGEOIP_VERSION)
FREEGEOIP_DIGEST:=md5
FREEGEOIP_CHECKSUM:=06effa101645431a4608581d6dd98970
FREEGEOIP_URL:=https://github.com/fiorix/freegeoip/releases/download/v$(FREEGEOIP_VERSION)/$(FREEGEOIP)-linux-amd64.tar.gz

GOLANG_VERSION:=1.4.2
GOLANG:=golang-$(GOLANG_VERSION)
GOLANG_DIGEST:=sha1
GOLANG_CHECKSUM:=5020af94b52b65cc9b6f11d50a67e4bae07b0aff
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

LIBYAML_VERSION:=0.1.6
LIBYAML:=libyaml-$(LIBYAML_VERSION)
LIBYAML_DIGEST:=md5
LIBYAML_CHECKSUM:=5fe00cda18ca5daeb43762b80c38e06e
LIBYAML_URL:=http://pyyaml.org/download/libyaml/yaml-$(LIBYAML_VERSION).tar.gz

LUA_RESTY_HTTP_VERSION:=0.05
LUA_RESTY_HTTP:=lua-resty-http-$(LUA_RESTY_HTTP_VERSION)
LUA_RESTY_HTTP_DIGEST:=md5
LUA_RESTY_HTTP_CHECKSUM:=bf489d545d99c11f8deef769cfd5fec2
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

MONGODB_VERSION:=3.0.4
MONGODB:=mongodb-$(MONGODB_VERSION)
MONGODB_DIGEST:=md5
MONGODB_CHECKSUM:=df7d1ed6538f3568cf6d130721694b42
MONGODB_URL:=https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-$(MONGODB_VERSION).tgz

MORA_VERSION:=fb667a3342bce09e975a25b0cf090ed251b5197a
MORA:=mora-$(MORA_VERSION)
MORA_DIGEST:=md5
MORA_CHECKSUM:=b5e5c4dd70fcfe131826ca44afcabb1e
MORA_URL:=https://github.com/emicklei/mora/archive/$(MORA_VERSION).tar.gz

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

OPENRESTY_VERSION:=1.7.10.1
OPENRESTY:=ngx_openresty-$(OPENRESTY_VERSION)
OPENRESTY_DIGEST:=md5
OPENRESTY_CHECKSUM:=1093b89459922634a818e05f80c1e18a
OPENRESTY_URL:=http://openresty.org/download/$(OPENRESTY).tar.gz

PERP_VERSION:=2.07
PERP:=perp-$(PERP_VERSION)
PERP_DIGEST:=md5
PERP_CHECKSUM:=a2acc7425d556d9635a25addcee9edb5
PERP_URL:=http://b0llix.net/perp/distfiles/$(PERP).tar.gz

TRAFFICSERVER_VERSION:=5.3.0
TRAFFICSERVER:=trafficserver-$(TRAFFICSERVER_VERSION)
TRAFFICSERVER_DIGEST:=md5
TRAFFICSERVER_CHECKSUM:=fe24cf2d44eccc84c753376f0e8c3be6
TRAFFICSERVER_URL:=http://mirror.olnevhost.net/pub/apache/trafficserver/$(TRAFFICSERVER).tar.bz2

# Define non-file/folder targets
.PHONY: all dependencies clean

all: dependencies

deps:
	mkdir -p $@

# dnsmasq
deps/$(DNSMASQ).tar.gz: | deps
	curl -L -o $@ $(DNSMASQ_URL)

deps/$(DNSMASQ): deps/$(DNSMASQ).tar.gz
	openssl $(DNSMASQ_DIGEST) $< | grep $(DNSMASQ_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

# ngx_dyups
deps/$(NGX_DYUPS).tar.gz: | deps
	curl -L -o $@ $(NGX_DYUPS_URL)

deps/$(NGX_DYUPS): deps/$(NGX_DYUPS).tar.gz
	openssl $(NGX_DYUPS_DIGEST) $< | grep $(NGX_DYUPS_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
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

deps/$(OPENRESTY)/.built: deps/$(OPENRESTY) deps/$(NGX_DYUPS) deps/$(NGX_TXID)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty \
		--error-log-path=stderr \
		--with-ipv6 \
		--with-pcre-jit \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_realip_module \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--add-module=../$(NGX_DYUPS) \
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

deps/gocode/src/github.com/emicklei/mora: deps/$(MORA).tar.gz
	openssl $(MORA_DIGEST) $< | grep $(MORA_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
	touch $@

deps/gocode/src/github.com/emicklei/mora/.built: deps/gocode/src/github.com/emicklei/mora deps/$(GOLANG)
	cd $< && PATH=$(ROOT_DIR)/deps/$(GOLANG)/bin:$(PATH) GOPATH=$(ROOT_DIR)/deps/gocode GOROOT=$(ROOT_DIR)/deps/$(GOLANG) go get
	cd $< && PATH=$(ROOT_DIR)/deps/$(GOLANG)/bin:$(PATH) GOPATH=$(ROOT_DIR)/deps/gocode GOROOT=$(ROOT_DIR)/deps/$(GOLANG) go build
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

# ElasticSearch
deps/$(ELASTICSEARCH).tar.gz: | deps
	curl -L -o $@ $(ELASTICSEARCH_URL)

deps/$(ELASTICSEARCH): deps/$(ELASTICSEARCH).tar.gz
	openssl $(ELASTICSEARCH_DIGEST) $< | grep $(ELASTICSEARCH_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
	mkdir -p $@
	tar --strip-components 1 -C $@ -xf $<
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

# freegeoip
deps/$(FREEGEOIP).tar.gz: | deps
	curl -L -o $@ $(FREEGEOIP_URL)

deps/$(FREEGEOIP): deps/$(FREEGEOIP).tar.gz
	openssl $(FREEGEOIP_DIGEST) $< | grep $(FREEGEOIP_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
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
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded
	cd $< && make
	touch $@

dependencies: \
	deps/$(DNSMASQ) \
	deps/$(ELASTICSEARCH) \
	deps/$(FREEGEOIP) \
	deps/$(HEKA) \
	deps/$(LIBCIDR)/.built \
	deps/$(LIBYAML)/.built \
	deps/$(LUAROCKS) \
	deps/$(MONGODB) \
	deps/gocode/src/github.com/emicklei/mora/.built \
	deps/$(OPENRESTY)/.built \
	deps/$(PERP)/.built \
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

$(PREFIX)/embedded/.installed/$(DNSMASQ): deps/$(DNSMASQ) $(PREFIX)/embedded/.installed
	cd deps/$(DNSMASQ) && make install PREFIX=$(PREFIX)/embedded
	touch $@

$(PREFIX)/embedded/.installed/$(ELASTICSEARCH): deps/$(ELASTICSEARCH) $(PREFIX)/embedded/.installed
	rsync -a deps/$(ELASTICSEARCH)/ $(PREFIX)/embedded/elasticsearch/
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/plugin $(PREFIX)/embedded/bin/plugin
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/elasticsearch $(PREFIX)/embedded/bin/elasticsearch
	touch $@

$(PREFIX)/embedded/.installed/$(FREEGEOIP): deps/$(FREEGEOIP) $(PREFIX)/embedded/.installed
	cp deps/$(FREEGEOIP)/freegeoip $(PREFIX)/embedded/bin/
	touch $@

$(PREFIX)/embedded/.installed/$(HEKA): deps/$(HEKA) $(PREFIX)/embedded/.installed
	rsync -a deps/$(HEKA)/ $(PREFIX)/embedded/
	touch $@

$(PREFIX)/embedded/.installed/$(LIBCIDR): deps/$(LIBCIDR)/.built $(PREFIX)/embedded/.installed
	cd deps/$(LIBCIDR) && make install PREFIX=$(PREFIX)/embedded
	touch $@

$(PREFIX)/embedded/.installed/$(LIBYAML): deps/$(LIBYAML)/.built $(PREFIX)/embedded/.installed
	cd deps/$(LIBYAML) && make install
	touch $@

$(PREFIX)/embedded/.installed/$(LUAROCKS): deps/$(LUAROCKS) $(PREFIX)/embedded/.installed $(PREFIX)/embedded/.installed/$(OPENRESTY)
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty/luajit \
		--with-lua=$(PREFIX)/embedded/openresty/luajit/ \
		--with-lua-include=$(PREFIX)/embedded/openresty/luajit/include/luajit-2.1 \
		--lua-suffix=jit-2.1.0-alpha
	cd $< && env -i make && env -i make install
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luarocks $(PREFIX)/embedded/bin/luarocks
	touch $@

$(PREFIX)/embedded/.installed/$(MONGODB): deps/$(MONGODB) $(PREFIX)/embedded/.installed
	rsync -a deps/$(MONGODB)/ $(PREFIX)/embedded/
	touch $@

$(PREFIX)/embedded/.installed/$(MORA): deps/gocode/src/github.com/emicklei/mora/.built $(PREFIX)/embedded/.installed
	cp deps/gocode/bin/mora $(PREFIX)/embedded/bin/
	touch $@

$(PREFIX)/embedded/.installed/$(OPENRESTY): deps/$(OPENRESTY)/.built $(PREFIX)/embedded/.installed
	cd deps/$(OPENRESTY) && make install
	ln -sf $(PREFIX)/embedded/openresty/bin/resty $(PREFIX)/embedded/bin/resty
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luajit-2.1.0-alpha $(PREFIX)/embedded/bin/luajit
	ln -sf $(PREFIX)/embedded/openresty/nginx/sbin/nginx $(PREFIX)/embedded/sbin/nginx
	touch $@

$(PREFIX)/embedded/.installed/$(PERP): deps/$(PERP)/.built $(PREFIX)/embedded/.installed
	cd deps/$(PERP) && make install
	touch $@

$(PREFIX)/embedded/.installed/$(TRAFFICSERVER): deps/$(TRAFFICSERVER)/.built $(PREFIX)/embedded/.installed
	cd deps/$(TRAFFICSERVER) && make install
	touch $@

.SECONDARY: \
	deps/$(DNSMASQ).tar.gz \
	deps/$(DNSMASQ) \
	deps/$(ELASTICSEARCH).tar.gz \
	deps/$(ELASTICSEARCH) \
	deps/$(FREEGEOIP).tar.gz \
	deps/$(FREEGEOIP) \
	deps/$(GOLANG).tar.gz \
	deps/$(GOLANG) \
	deps/$(HEKA).tar.gz \
	deps/$(HEKA) \
	deps/$(LIBCIDR).tar.xz \
	deps/$(LIBCIDR) \
	deps/$(LIBCIDR)/.built \
	deps/$(LIBYAML).tar.gz \
	deps/$(LIBYAML) \
	deps/$(LIBYAML)/.built \
	deps/$(LUAROCKS).tar.gz \
	deps/$(LUAROCKS) \
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
	deps/gocode/src/github.com/emicklei/mora \
	deps/gocode/src/github.com/emicklei/mora/.built \
	deps/$(NGX_DYUPS).tar.gz \
	deps/$(NGX_DYUPS) \
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
	deps/$(TRAFFICSERVER).tar.gz \
	deps/$(TRAFFICSERVER) \
	deps/$(TRAFFICSERVER)/.built

install_dependencies: \
	$(PREFIX)/embedded/bin \
	$(PREFIX)/embedded/sbin \
	$(PREFIX)/embedded/.installed/$(DNSMASQ) \
	$(PREFIX)/embedded/.installed/$(ELASTICSEARCH) \
	$(PREFIX)/embedded/.installed/$(FREEGEOIP) \
	$(PREFIX)/embedded/.installed/$(HEKA) \
	$(PREFIX)/embedded/.installed/$(LIBCIDR) \
	$(PREFIX)/embedded/.installed/$(LIBYAML) \
	$(PREFIX)/embedded/.installed/$(LUAROCKS) \
	$(PREFIX)/embedded/.installed/$(MONGODB) \
	$(PREFIX)/embedded/.installed/$(MORA) \
	$(PREFIX)/embedded/.installed/$(OPENRESTY) \
	$(PREFIX)/embedded/.installed/$(PERP) \
	$(PREFIX)/embedded/.installed/$(TRAFFICSERVER)

vendor:
	mkdir -p $@

LUA_LIBCIDR_FFI:=lua-libcidr-ffi
LUA_LIBCIDR_FFI_VERSION:=0.1.0-1
INSPECT:=inspect
INSPECT_VERSION:=3.0-1
LUA_CMSGPACK:=lua-cmsgpack
LUA_CMSGPACK_VERSION:=0.3-2
LUAUTF8:=luautf8
LUAUTF8_VERSION:=0.1.0-1
LUAPOSIX:=luaposix
LUAPOSIX_VERSION:=33.3.1-1
LYAML:=lyaml
LYAML_VERSION:=5.1.4-1
PENLIGHT:=penlight
PENLIGHT_VERSION:=1.3.2-2
STDLIB:=stdlib
STDLIB_VERSION:=41.2.0-1

vendor/lib/luarocks/rocks/$(INSPECT)/$(INSPECT_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(INSPECT) $(INSPECT_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUA_CMSGPACK) $(LUA_CMSGPACK_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUAUTF8)/$(LUAUTF8_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUAUTF8) $(LUAUTF8_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUAPOSIX)/$(LUAPOSIX_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUAPOSIX) $(LUAPOSIX_VERSION)
	touch $@

#vendor/lib/luarocks/rocks/$(LUA_LIBCIDR_FFI)/$(LUA_LIBCIDR_FFI_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
#	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUA_LIBCIDR_FFI) $(LUA_LIBCIDR_FFI_VERSION)
#	touch $@

vendor/lib/luarocks/rocks/$(LYAML)/$(LYAML_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install https://raw.githubusercontent.com/GUI/lyaml/multiline-strings-release/lyaml-git-1.rockspec YAML_DIR=$(PREFIX)/embedded
	touch $@

vendor/lib/luarocks/rocks/$(PENLIGHT)/$(PENLIGHT_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(PENLIGHT) $(PENLIGHT_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(STDLIB)/$(STDLIB_VERSION): $(PREFIX)/embedded/.installed/$(LUAROCKS) | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(STDLIB) $(STDLIB_VERSION)
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
	vendor/lib/luarocks/rocks/$(INSPECT)/$(INSPECT_VERSION) \
	vendor/lib/luarocks/rocks/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION) \
	vendor/lib/luarocks/rocks/$(LUAUTF8)/$(LUAUTF8_VERSION) \
	vendor/lib/luarocks/rocks/$(LUAPOSIX)/$(LUAPOSIX_VERSION) \
	vendor/lib/luarocks/rocks/$(LYAML)/$(LYAML_VERSION) \
	vendor/lib/luarocks/rocks/$(PENLIGHT)/$(PENLIGHT_VERSION) \
	vendor/lib/luarocks/rocks/$(STDLIB)/$(STDLIB_VERSION) \
	vendor/share/lua/5.1/lustache.lua \
	vendor/share/lua/5.1/resty/http.lua \
	vendor/share/lua/5.1/resty/logger/socket.lua \
	vendor/share/lua/5.1/shcache.lua

install: install_dependencies install_app_dependencies

test: install
	API_UMBRELLA_ROOT=$(PREFIX) npm test

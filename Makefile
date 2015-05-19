export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin

PREFIX:=/tmp/api-umbrella-build
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

DNSMASQ_VERSION:=2.72
DNSMASQ:=dnsmasq-$(DNSMASQ_VERSION)
DNSMASQ_DIGEST:=md5
DNSMASQ_CHECKSUM:=cf82f81cf09ad3d47612985012240483
DNSMASQ_URL:=http://www.thekelleys.org.uk/dnsmasq/$(DNSMASQ).tar.gz

ELASTICSEARCH_VERSION:=1.5.2
ELASTICSEARCH:=elasticsearch-$(ELASTICSEARCH_VERSION)
ELASTICSEARCH_DIGEST:=sha1
ELASTICSEARCH_CHECKSUM:=ffe2e46ec88f4455323112a556adaaa085669d13
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

MONGODB_VERSION:=3.0.3
MONGODB:=mongodb-$(MONGODB_VERSION)
MONGODB_DIGEST:=md5
MONGODB_CHECKSUM:=67cae28e21f3fa822fc873c0240422e2
MONGODB_URL:=https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel62-$(MONGODB_VERSION).tgz

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

deps/$(LUAROCKS)/.installed: deps/$(LUAROCKS) deps/$(OPENRESTY)/.built
	cd $< && ./configure \
		--prefix=$(PREFIX)/embedded/openresty/luajit \
		--with-lua=$(PREFIX)/embedded/openresty/luajit/ \
		--with-lua-include=$(PREFIX)/embedded/openresty/luajit/include/luajit-2.1 \
		--lua-suffix=jit-2.1.0-alpha
	cd $< && make && make install
	touch $@

# lua-resty-http
deps/$(LUA_RESTY_HTTP).tar.gz: | deps
	curl -L -o $@ $(LUA_RESTY_HTTP_URL)

deps/$(LUA_RESTY_HTTP): deps/$(LUA_RESTY_HTTP).tar.gz
	openssl $(LUA_RESTY_HTTP_DIGEST) $< | grep $(LUA_RESTY_HTTP_CHECKSUM) || (echo "checksum mismatch $<" && exit 1)
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
	deps/$(LIBYAML)/.built \
	deps/$(LUAROCKS) \
	deps/$(MONGODB) \
	deps/gocode/src/github.com/emicklei/mora/.built \
	deps/$(OPENRESTY)/.built \
	deps/$(PERP)/.built \
	deps/$(TRAFFICSERVER)/.built

clean:
	rm -rf deps

install_dependencies: all
	mkdir -p $(PREFIX)/embedded/bin $(PREFIX)/embedded/sbin
	# dnsmasq
	cd deps/$(DNSMASQ) && make install PREFIX=$(PREFIX)/embedded
	# ElasticSearch
	rsync -a deps/$(ELASTICSEARCH)/ $(PREFIX)/embedded/elasticsearch/
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/elasticsearch $(PREFIX)/embedded/bin/elasticsearch
	ln -sf $(PREFIX)/embedded/elasticsearch/bin/plugin $(PREFIX)/embedded/bin/plugin
	# freegeoip
	cp deps/$(FREEGEOIP)/freegeoip $(PREFIX)/embedded/bin/
	# Heka
	rsync -a deps/$(HEKA)/ $(PREFIX)/embedded/
	# LibYAML
	cd deps/$(LIBYAML) && make install
	# MongoDB
	rsync -a deps/$(MONGODB)/ $(PREFIX)/embedded/
	# Mora
	cp deps/gocode/bin/mora $(PREFIX)/embedded/bin/
	# OpenResty
	cd deps/$(OPENRESTY) && make install
	ln -sf $(PREFIX)/embedded/openresty/bin/resty $(PREFIX)/embedded/bin/resty
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luajit-2.1.0-alpha $(PREFIX)/embedded/bin/luajit
	ln -sf $(PREFIX)/embedded/openresty/luajit/bin/luarocks $(PREFIX)/embedded/bin/luarocks
	ln -sf $(PREFIX)/embedded/openresty/nginx/sbin/nginx $(PREFIX)/embedded/sbin/nginx
	# perp
	cd deps/$(PERP) && make install
	# TrafficServer
	cd deps/$(TRAFFICSERVER) && make install

vendor:
	mkdir -p $@

LUA_RESTY_IPUTILS:=lua-resty-iputils
LUA_RESTY_IPUTILS_VERSION:=0.1.0-1
INSPECT:=inspect
INSPECT_VERSION:=3.0-1
LUA_CMSGPACK:=lua-cmsgpack
LUA_CMSGPACK_VERSION:=0.3-2
LUSTACHE:=lustache
LUSTACHE_VERSION:=1.3-1
LYAML:=lyaml
LYAML_VERSION:=5.1.4-1
PENLIGHT:=penlight
PENLIGHT_VERSION:=1.3.2-2
STDLIB:=stdlib
STDLIB_VERSION:=41.2.0-1

vendor/lib/luarocks/rocks/$(LUA_RESTY_IPUTILS)/$(LUA_RESTY_IPUTILS_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUA_RESTY_IPUTILS) $(LUA_RESTY_IPUTILS_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(INSPECT)/$(INSPECT_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(INSPECT) $(INSPECT_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUA_CMSGPACK) $(LUA_CMSGPACK_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LUSTACHE)/$(LUSTACHE_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LUSTACHE) $(LUSTACHE_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(LYAML)/$(LYAML_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(LYAML) $(LYAML_VERSION) YAML_DIR=$(PREFIX)/embedded
	touch $@

vendor/lib/luarocks/rocks/$(PENLIGHT)/$(PENLIGHT_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(PENLIGHT) $(PENLIGHT_VERSION)
	touch $@

vendor/lib/luarocks/rocks/$(STDLIB)/$(STDLIB_VERSION): deps/$(LUAROCKS)/.installed | vendor
	$(PREFIX)/embedded/bin/luarocks --tree=vendor install $(STDLIB) $(STDLIB_VERSION)
	touch $@

vendor/share/lua/5.1/resty/http.lua: deps/$(LUA_RESTY_HTTP) | vendor
	rsync -a deps/$(LUA_RESTY_HTTP)/lib/resty/ vendor/share/lua/5.1/resty/
	touch $@

vendor/share/lua/5.1/shcache.lua: deps/$(LUA_RESTY_SHCACHE) | vendor
	rsync -a deps/$(LUA_RESTY_SHCACHE)/*.lua vendor/share/lua/5.1/
	touch $@

install_app_dependencies: \
	vendor/lib/luarocks/rocks/$(LUA_RESTY_IPUTILS)/$(LUA_RESTY_IPUTILS_VERSION) \
	vendor/lib/luarocks/rocks/$(INSPECT)/$(INSPECT_VERSION) \
	vendor/lib/luarocks/rocks/$(LUA_CMSGPACK)/$(LUA_CMSGPACK_VERSION) \
	vendor/lib/luarocks/rocks/$(LUSTACHE)/$(LUSTACHE_VERSION) \
	vendor/lib/luarocks/rocks/$(LYAML)/$(LYAML_VERSION) \
	vendor/lib/luarocks/rocks/$(PENLIGHT)/$(PENLIGHT_VERSION) \
	vendor/lib/luarocks/rocks/$(STDLIB)/$(STDLIB_VERSION) \
	vendor/share/lua/5.1/resty/http.lua \
	vendor/share/lua/5.1/shcache.lua

install: all install_dependencies install_app_dependencies

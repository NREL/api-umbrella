###
# Build
###
FROM debian:bullseye AS build

ARG TARGETARCH

RUN mkdir -p /app/build /build/.task /build/build/work
RUN ln -snf /build/.task /app/.task
RUN ln -snf /build/build/work /app/build/work
WORKDIR /app

ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

COPY build/package_dependencies.sh /app/build/package_dependencies.sh
COPY tasks/helpers.sh tasks/install-system-build-dependencies /app/tasks/
COPY tasks/helpers/detect_os_release.sh tasks/helpers/lua.sh /app/tasks/helpers/
RUN /app/tasks/install-system-build-dependencies

COPY Makefile.in Taskfile.yml configure /app/
COPY tasks/bootstrap-* /app/tasks/
RUN ./configure

COPY tasks/clean/dev /app/tasks/clean/dev

COPY tasks/deps/perp /app/tasks/deps/
RUN make deps:perp && make clean:dev

COPY tasks/deps/runit_svlogd /app/tasks/deps/
RUN make deps:runit_svlogd && make clean:dev

COPY build/patches/openresty* /app/build/patches/
COPY tasks/deps/libmaxminddb tasks/deps/openresty /app/tasks/deps/
RUN make deps:openresty && make clean:dev

COPY tasks/deps/trafficserver /app/tasks/deps/
RUN make deps:trafficserver && make clean:dev

COPY tasks/deps/libestr tasks/deps/libfastjson tasks/deps/rsyslog /app/tasks/deps/
RUN make deps:rsyslog && make clean:dev

COPY src/api-umbrella-git-1.rockspec src/luarocks.lock /app/src/
COPY tasks/deps/luarocks /app/tasks/deps/
RUN make deps:luarocks && make clean:dev

COPY tasks/build-deps/crane /app/tasks/build-deps/
COPY tasks/deps/envoy /app/tasks/deps/
RUN make deps:envoy && make clean:dev

COPY tasks/deps /app/tasks/deps
RUN make deps && make clean:dev

COPY tasks/build-deps /app/tasks/build-deps
RUN make build-deps && make clean:dev

COPY src/api-umbrella/example-website/package.json src/api-umbrella/example-website/yarn.lock /app/src/api-umbrella/example-website/
COPY tasks/app-deps/example-website/yarn /app/tasks/app-deps/example-website/
RUN make app-deps:example-website:yarn && make clean:dev

COPY src/api-umbrella/admin-ui/.yarnrc src/api-umbrella/admin-ui/package.json src/api-umbrella/admin-ui/yarn.lock /app/src/api-umbrella/admin-ui/
COPY tasks/app-deps/admin-ui/yarn /app/tasks/app-deps/admin-ui/
RUN make app-deps:admin-ui:yarn && make clean:dev

COPY src/api-umbrella/web-app/package.json src/api-umbrella/web-app/yarn.lock /app/src/api-umbrella/web-app/
COPY tasks/app-deps/web-app/yarn /app/tasks/app-deps/web-app/
RUN make app-deps:web-app:yarn && make clean:dev

COPY build/patches/lrexlib-pcre2.patch /app/build/patches/
COPY tasks/app-deps/luarocks /app/tasks/app-deps/
RUN make app-deps:luarocks && make clean:dev

COPY tasks/app-deps /app/tasks/app-deps
RUN make app-deps && make clean:dev

COPY src/api-umbrella/example-website /app/src/api-umbrella/example-website
COPY tasks/app/example-website/build /app/tasks/app/example-website/
RUN make app:example-website:build && make clean:dev

COPY src/api-umbrella/web-app/assets /app/src/api-umbrella/web-app/assets
COPY src/api-umbrella/web-app/webpack.config.js /app/src/api-umbrella/web-app/webpack.config.js
COPY tasks/app/web-app/precompile /app/tasks/app/web-app/
RUN make app:web-app:precompile && make clean:dev

COPY src/api-umbrella/admin-ui /app/src/api-umbrella/admin-ui
COPY tasks/app/admin-ui/build /app/tasks/app/admin-ui/
RUN make app:admin-ui:build && make clean:dev

COPY LICENSE.txt /app/
COPY bin /app/bin
COPY config /app/config
COPY db /app/db
COPY locale /app/locale
COPY src /app/src
COPY tasks /app/tasks
COPY templates /app/templates
RUN make && make clean:dev

###
# Test
###
FROM debian:bullseye AS test

ARG TARGETARCH

RUN mkdir -p /app/build /build/.task /build/build/work
RUN ln -snf /build/.task /app/.task
RUN ln -snf /build/build/work /app/build/work
WORKDIR /app

COPY build/package_dependencies.sh /app/build/package_dependencies.sh
COPY tasks/helpers.sh tasks/install-system-build-dependencies /app/tasks/
COPY tasks/helpers/detect_os_release.sh tasks/helpers/lua.sh /app/tasks/helpers/
RUN INSTALL_TEST_DEPENDENCIES=true /app/tasks/install-system-build-dependencies

COPY Makefile.in Taskfile.yml configure /app/
COPY tasks/bootstrap-* /app/tasks/
RUN ./configure

COPY tasks/clean/dev /app/tasks/clean/dev

COPY --from=build /build /build

COPY Gemfile Gemfile.lock /app/
COPY tasks/test-deps/bundle /app/tasks/test-deps/
RUN make test-deps:bundle && make clean:dev

COPY test/api-umbrella-test-git-1.rockspec test/luarocks.lock /app/test/
COPY tasks/deps/libmaxminddb tasks/deps/luarocks tasks/deps/openresty /app/tasks/deps/
COPY tasks/test-deps /app/tasks/test-deps
RUN make test-deps && make clean:dev

RUN groupadd -r api-umbrella && \
  useradd -r -g api-umbrella -s /sbin/nologin -d /opt/api-umbrella -c "API Umbrella user" api-umbrella

COPY --from=build /app /app
COPY .luacheckrc .rubocop.yml Thorfile /app/
COPY build/package /app/build/package
COPY scripts /app/scripts
COPY test /app/test
COPY website/Gemfile website/Rakefile website/config.rb /app/website/

RUN ln -snf "/app/build/work/tasks/app-deps/admin-ui/yarn/_persist/node_modules" "/app/src/api-umbrella/admin-ui/node_modules"
RUN ln -snf "/app/build/work/tasks/app-deps/example-website/yarn/_persist/node_modules" "/app/src/api-umbrella/example-website/node_modules"
RUN ln -snf "/app/build/work/tasks/app-deps/web-app/yarn/_persist/node_modules" "/app/src/api-umbrella/web-app/node_modules"

ENV \
  PATH="/app/bin:/build/build/work/dev-env/sbin:/build/build/work/dev-env/bin:/build/build/work/test-env/sbin:/build/build/work/test-env/bin:/build/build/work/stage/opt/api-umbrella/sbin:/build/build/work/stage/opt/api-umbrella/bin:/build/build/work/stage/opt/api-umbrella/embedded/sbin:/build/build/work/stage/opt/api-umbrella/embedded/bin:${PATH}" \
  API_UMBRELLA_ROOT="/build/build/work/stage/opt/api-umbrella"

###
# Install
###
FROM debian:bullseye AS install

RUN apt-get update && \
  apt-get -y install git rsync && \
  rm -rf /var/lib/apt/lists/*

COPY build/package/files /tmp/install/build/package/files
COPY build/package/scripts/after-install /tmp/install/build/package/scripts/after-install
COPY --from=build /app/tasks/helpers.sh /tmp/install/tasks/helpers.sh
COPY --from=build /app/tasks/install /tmp/install/tasks/install
COPY --from=build /app/build/work /tmp/install/build/work
WORKDIR /tmp/install
RUN DESTDIR="/build/install-destdir" PREFIX=/opt/api-umbrella ./tasks/install

###
# Runtime
###
FROM debian:bullseye AS runtime

COPY --from=install /build/install-destdir /
COPY build/package/scripts/after-install /tmp/install/build/package/scripts/after-install
COPY --from=build /app/build/package_dependencies.sh /tmp/install/build/package_dependencies.sh
COPY --from=build /app/tasks/helpers/detect_os_release.sh /tmp/install/tasks/helpers/detect_os_release.sh
RUN set -x && \
  apt-get update && \
  bash -c 'source /tmp/install/build/package_dependencies.sh && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install "${core_runtime_dependencies[@]}"' && \
  /tmp/install/build/package/scripts/after-install 1 && \
  rm -rf /tmp/install /var/lib/apt/lists/*

EXPOSE 80 443

CMD ["api-umbrella", "run"]

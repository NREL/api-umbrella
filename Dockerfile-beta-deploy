FROM ubuntu:18.04 AS build

RUN mkdir -p /app/build /build/.task /build/build/work
RUN ln -snf /build/.task /app/.task
RUN ln -snf /build/build/work /app/build/work
WORKDIR /app

ENV DOCKER_DEV true
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

COPY build/package_dependencies.sh /app/build/package_dependencies.sh
COPY tasks/helpers.sh /app/tasks/helpers.sh
COPY tasks/helpers/detect_os_release.sh /app/tasks/helpers/detect_os_release.sh
COPY tasks/install-system-build-dependencies /app/tasks/install-system-build-dependencies
RUN /app/tasks/install-system-build-dependencies

COPY Makefile.in /app/Makefile.in
COPY Taskfile.yml /app/Taskfile.yml
COPY configure /app/configure
COPY tasks/bootstrap-* /app/tasks/
RUN ./configure

COPY build/patches /app/build/patches
COPY tasks/deps /app/tasks/deps
COPY tasks/clean/dev /app/tasks/clean/dev
RUN make deps && make clean:dev

COPY tasks/build-deps /app/tasks/build-deps
RUN make build-deps && make clean:dev

COPY src/api-umbrella/admin-ui/.yarnrc /app/src/api-umbrella/admin-ui/.yarnrc
COPY src/api-umbrella/admin-ui/package.json /app/src/api-umbrella/admin-ui/package.json
COPY src/api-umbrella/admin-ui/yarn.lock /app/src/api-umbrella/admin-ui/yarn.lock
COPY src/api-umbrella/web-app/Gemfile /app/src/api-umbrella/web-app/Gemfile
COPY src/api-umbrella/web-app/Gemfile.lock /app/src/api-umbrella/web-app/Gemfile.lock
COPY tasks/app-deps /app/tasks/app-deps
RUN make app-deps && make clean:dev

COPY . /app
RUN make && make clean:dev
RUN make install DESTDIR="/build/install-destdir"

FROM ubuntu:18.04

COPY --from=build /build/install-destdir /
COPY --from=build /app/build/package/scripts/after-install /tmp/install/build/package/scripts/after-install
COPY --from=build /app/build/package_dependencies.sh /tmp/install/build/package_dependencies.sh
COPY --from=build /app/tasks/helpers/detect_os_release.sh /tmp/install/tasks/helpers/detect_os_release.sh
RUN set -x && \
  apt-get update && \
  bash -c 'source /tmp/install/build/package_dependencies.sh && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install "${core_package_dependencies[@]}"' && \
  /tmp/install/build/package/scripts/after-install 1 && \
  rm -rf /tmp/install /var/lib/apt/lists/*

CMD ["api-umbrella", "run"]

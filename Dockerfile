FROM debian:bullseye AS build

RUN mkdir -p /app/build /build/.task /build/build/work
RUN ln -snf /build/.task /app/.task
RUN ln -snf /build/build/work /app/build/work
WORKDIR /app

ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

COPY build/package_dependencies.sh /app/build/package_dependencies.sh
COPY tasks/helpers.sh /app/tasks/helpers.sh
COPY tasks/helpers/detect_os_release.sh /app/tasks/helpers/detect_os_release.sh
COPY tasks/helpers/lua.sh /app/tasks/helpers/lua.sh
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

COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
COPY tasks/test-deps /app/tasks/test-deps
ARG INSTALL_TEST_DEPENDENCIES=false
RUN set -x && \
  if [ "$INSTALL_TEST_DEPENDENCIES" = "true" ]; then \
    INSTALL_TEST_DEPENDENCIES=true /app/tasks/install-system-build-dependencies; \
  fi

# Add Chrome for integration tests, similar to how the CircleCI images add it:
# https://github.com/CircleCI-Public/circleci-dockerfiles/blob/c24e69355b400aaba34a1ddfc55cdb1fef9dedff/buildpack-deps/images/xenial/browsers/Dockerfile#L47
RUN set -x && \
  if [ "$INSTALL_TEST_DEPENDENCIES" = "true" ]; then \
    apt-get update && \
    curl --silent --show-error --location --fail --retry 3 --output /tmp/google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    (dpkg -i /tmp/google-chrome-stable_current_amd64.deb || apt-get -fy install) && \
    rm -f /tmp/google-chrome-stable_current_amd64.deb && \
    sed -i 's|HERE/chrome"|HERE/chrome" --disable-setuid-sandbox --no-sandbox|g' /opt/google/chrome/google-chrome && \
    google-chrome --version && \
    CHROME_VERSION="$(google-chrome --version)" && \
    export CHROMEDRIVER_RELEASE="$(echo $CHROME_VERSION | sed 's/^Google Chrome //')" && export CHROMEDRIVER_RELEASE=${CHROMEDRIVER_RELEASE%%.*} && \
    CHROMEDRIVER_VERSION=$(curl --silent --show-error --location --fail --retry 4 --retry-delay 5 http://chromedriver.storage.googleapis.com/LATEST_RELEASE_${CHROMEDRIVER_RELEASE}) && \
    curl --silent --show-error --location --fail --retry 4 --retry-delay 5 --output /tmp/chromedriver_linux64.zip "http://chromedriver.storage.googleapis.com/$CHROMEDRIVER_VERSION/chromedriver_linux64.zip" && \
    cd /tmp && \
    unzip chromedriver_linux64.zip && \
    rm -rf chromedriver_linux64.zip && \
    mv chromedriver /usr/local/bin/chromedriver && \
    chmod +x /usr/local/bin/chromedriver && \
    chromedriver --version; \
  fi

RUN set -x && \
  if [ "$INSTALL_TEST_DEPENDENCIES" = "true" ]; then \
    make test-deps && make clean:dev; \
  fi

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

RUN /app/build/package/scripts/after-install 1

FROM debian:bullseye AS runtime

COPY --from=build /build/install-destdir /
COPY --from=build /app/build/package/scripts/after-install /tmp/install/build/package/scripts/after-install
COPY --from=build /app/build/package_dependencies.sh /tmp/install/build/package_dependencies.sh
COPY --from=build /app/tasks/helpers/detect_os_release.sh /tmp/install/tasks/helpers/detect_os_release.sh
RUN set -x && \
  apt-get update && \
  bash -c 'source /tmp/install/build/package_dependencies.sh && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install "${core_package_dependencies[@]}"' && \
  /tmp/install/build/package/scripts/after-install 1 && \
  rm -rf /tmp/install /var/lib/apt/lists/*

ENTRYPOINT ["/app/docker/dev/docker-entrypoint"]
CMD ["/app/docker/dev/docker-start"]

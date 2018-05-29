# Mora: HTTP API for MongoDB (allowing OpenResty connectivity)

set(GOLANG_VERSION 1.10.2)
set(GOLANG_HASH 4b677d698c65370afa33757b6954ade60347aaca310ea92a63ed717d7cb0c2ff)
set(MORA_VERSION 8127901857cf88d3f0902708b25ad930354973a3)
set(MORA_HASH b86cea913596370cd58fce89b23acd97)

# Built with Go
ExternalProject_Add(
  golang
  EXCLUDE_FROM_ALL 1
  URL https://storage.googleapis.com/golang/go${GOLANG_VERSION}.linux-amd64.tar.gz
  URL_HASH SHA256=${GOLANG_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(golang SOURCE_DIR)
set(GOLANG_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  mora
  DEPENDS golang
  URL https://github.com/emicklei/mora/archive/${MORA_VERSION}.tar.gz
  URL_HASH MD5=${MORA_HASH}
  SOURCE_DIR ${WORK_DIR}/gocode/src/github.com/emicklei/mora
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${WORK_DIR}/gocode/bin:${DEFAULT_PATH} GOPATH=${WORK_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} go install
  INSTALL_COMMAND install -D -m 755 ${WORK_DIR}/gocode/bin/mora ${STAGE_EMBEDDED_DIR}/bin/mora
)

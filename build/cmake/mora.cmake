# Mora: HTTP API for MongoDB (allowing OpenResty connectivity)
# Built with Go
ExternalProject_Add(
  golang
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
  URL https://github.com/emicklei/mora/archive/${MORA_VERSION}.tar.gz
  URL_HASH MD5=${MORA_HASH}
  SOURCE_DIR ${WORK_DIR}/gocode/src/github.com/emicklei/mora
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${WORK_DIR}/gocode/bin:$ENV{PATH} GOPATH=${WORK_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} go install
  INSTALL_COMMAND install -D -m 755 ${WORK_DIR}/gocode/bin/mora ${STAGE_EMBEDDED_DIR}/bin/mora
)

# Mora: HTTP API for MongoDB (allowing OpenResty connectivity)
# Built with Go & Glide for dependencies
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
  glide
  DEPENDS golang
  URL https://github.com/Masterminds/glide/releases/download/${GLIDE_VERSION}/glide-${GLIDE_VERSION}-linux-amd64.tar.gz
  URL_HASH MD5=${GLIDE_HASH}
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
)
ExternalProject_Get_Property(glide SOURCE_DIR)
set(GLIDE_SOURCE_DIR ${SOURCE_DIR})

ExternalProject_Add(
  mora
  DEPENDS glide
  URL https://github.com/emicklei/mora/archive/${MORA_VERSION}.tar.gz
  URL_HASH MD5=${MORA_HASH}
  SOURCE_DIR ${WORK_DIR}/gocode/src/github.com/emicklei/mora
  BUILD_IN_SOURCE 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND cp ${CMAKE_SOURCE_DIR}/build/mora/glide.yaml <SOURCE_DIR>/glide.yaml
    COMMAND cp ${CMAKE_SOURCE_DIR}/build/mora/glide.lock <SOURCE_DIR>/glide.lock
    COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${GLIDE_SOURCE_DIR}:${WORK_DIR}/gocode/bin:$ENV{PATH} GOPATH=${WORK_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} GO15VENDOREXPERIMENT=1 glide install
    COMMAND env PATH=${GOLANG_SOURCE_DIR}/bin:${GLIDE_SOURCE_DIR}:${WORK_DIR}/gocode/bin:$ENV{PATH} GOPATH=${WORK_DIR}/gocode GOROOT=${GOLANG_SOURCE_DIR} GO15VENDOREXPERIMENT=1 go install
  INSTALL_COMMAND install -D -m 755 ${WORK_DIR}/gocode/bin/mora ${STAGE_EMBEDDED_DIR}/bin/mora
)
ExternalProject_Add_Step(
  mora mora_rebuild_on_glide_file_changes
  DEPENDERS build
  DEPENDS ${CMAKE_SOURCE_DIR}/build/mora/glide.yaml ${CMAKE_SOURCE_DIR}/build/mora/glide.lock
)

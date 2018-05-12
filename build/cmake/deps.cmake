include(${CMAKE_SOURCE_DIR}/build/cmake/deps/elasticsearch.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/libcidr.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/mongodb.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/mora.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/openresty.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/perp.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/rsyslog.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/ruby.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/runit_svlogd.cmake)
include(${CMAKE_SOURCE_DIR}/build/cmake/deps/trafficserver.cmake)

add_custom_target(deps ALL DEPENDS
  bundler
  elasticsearch
  geolitecity
  libcidr
  luarocks
  mongodb
  mora
  openresty
  perp
  rsyslog
  runit_svlogd
  trafficserver
)

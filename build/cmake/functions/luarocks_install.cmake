function(_luarocks_install tree_dir package version hash)
  ExternalProject_Add(
    luarock_${package}
    EXCLUDE_FROM_ALL 1
    DEPENDS luarocks ${ARGV5}
    URL https://luarocks.org/${package}-${version}.rockspec
    URL_HASH MD5=${hash}
    DOWNLOAD_NO_EXTRACT 1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND ${LUAROCKS_CMD} --tree=${tree_dir} install ${package} ${version} ${ARGV4}
      COMMAND find ${tree_dir} -name *.so -exec chrpath -d {} $<SEMICOLON>
  )
endfunction()

function(luarocks_install package version hash)
  _luarocks_install(${VENDOR_DIR} ${package} ${version} ${hash} ${ARGV3} ${ARGV4})
endfunction()

function(test_luarocks_install package version hash)
  _luarocks_install(${TEST_VENDOR_DIR} ${package} ${version} ${hash} ${ARGV3} ${ARGV4})
endfunction()

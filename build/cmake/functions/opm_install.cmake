function(_opm_install tree_dir package account version hash)
  ExternalProject_Add(
    opm_${package}
    EXCLUDE_FROM_ALL 1
    DEPENDS openresty ${ARGV5}
    URL https://opm.openresty.org/api/pkg/tarball/${account}/${package}-${version}.opm.tar.gz
    URL_HASH MD5=${hash}
    DOWNLOAD_NO_EXTRACT 1
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ""
    INSTALL_COMMAND mkdir -p ${tree_dir} && cd ${tree_dir} && ${OPM_CMD} --cwd get ${account}/${package}=${version}
      COMMAND find ${tree_dir}/resty_modules -name *.so -exec chrpath -d {} $<SEMICOLON>
  )
endfunction()

function(opm_install package account version hash)
  _opm_install(${VENDOR_DIR} ${package} ${account} ${version} ${hash} ${ARGV4})
endfunction()

function(test_opm_install package account version hash)
  _opm_install(${TEST_VENDOR_DIR} ${package} ${account} ${version} ${hash} ${ARGV4})
endfunction()

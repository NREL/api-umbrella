ExternalProject_Add(
  shellcheck
  # Download 64bit linux binary (that works in all distros) for v0.4.5 from
  # author:
  # https://github.com/koalaman/shellcheck/issues/758#issuecomment-257730652
  #
  # Should followup with shellcheck issue about whether they plan to release
  # these binaries more formally and on an ongoing basis.
  URL https://www.vidarholen.net/%7Evidar/shellcheck.${SHELLCHECK_VERSION}.gz
  URL_HASH SHA256=${SHELLCHECK_HASH}
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND gzip -d -c <DOWNLOADED_FILE> > <BINARY_DIR>/shellcheck
  INSTALL_COMMAND install -D -m 755 <BINARY_DIR>/shellcheck ${TEST_INSTALL_PREFIX}/bin/shellcheck
)

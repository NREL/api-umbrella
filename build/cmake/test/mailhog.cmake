# MailHog: SMTP testing server
ExternalProject_Add(
  mailhog
  URL https://github.com/mailhog/MailHog/releases/download/v${MAILHOG_VERSION}/MailHog_linux_amd64
  URL_HASH MD5=${MAILHOG_HASH}
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <DOWNLOADED_FILE> ${TEST_INSTALL_PREFIX}/bin/mailhog
)

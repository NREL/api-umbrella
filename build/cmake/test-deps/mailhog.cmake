# MailHog: SMTP testing server

set(MAILHOG_VERSION 1.0.0)
set(MAILHOG_HASH 3b758c81bfe2c9110911511daca1a7bc)

ExternalProject_Add(
  mailhog
  EXCLUDE_FROM_ALL 1
  URL https://github.com/mailhog/MailHog/releases/download/v${MAILHOG_VERSION}/MailHog_linux_amd64
  URL_HASH MD5=${MAILHOG_HASH}
  DOWNLOAD_NO_EXTRACT 1
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND install -D -m 755 <DOWNLOADED_FILE> ${TEST_INSTALL_PREFIX}/bin/mailhog
)

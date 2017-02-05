# OpenLDAP: For testing LDAP admin auth.
ExternalProject_Add(
  openldap
  URL ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-${OPENLDAP_VERSION}.tgz
  URL_HASH SHA1=${OPENLDAP_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX} --disable-backends --enable-mdb
  BUILD_COMMAND make depend && make
)

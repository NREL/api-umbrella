# OpenLDAP: For testing LDAP admin auth.

set(OPENLDAP_VERSION 2.4.45)
set(OPENLDAP_HASH c98437385d3eaee80c9e2c09f3f0d4b7c140233d)

ExternalProject_Add(
  openldap
  EXCLUDE_FROM_ALL 1
  URL ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-${OPENLDAP_VERSION}.tgz
  URL_HASH SHA1=${OPENLDAP_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX} --disable-backends --enable-mdb
  BUILD_COMMAND make depend && make
)

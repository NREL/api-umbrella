# OpenLDAP: For testing LDAP admin auth.

set(OPENLDAP_VERSION 2.4.46)
set(OPENLDAP_HASH a9ae2273eb9bdd70090dafe0d018a3132606bef6)

ExternalProject_Add(
  openldap
  EXCLUDE_FROM_ALL 1
  URL ftp://ftp.openldap.org/pub/OpenLDAP/openldap-release/openldap-${OPENLDAP_VERSION}.tgz
  URL_HASH SHA1=${OPENLDAP_HASH}
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=${TEST_INSTALL_PREFIX} --disable-backends --enable-mdb
  BUILD_COMMAND make depend && make
)

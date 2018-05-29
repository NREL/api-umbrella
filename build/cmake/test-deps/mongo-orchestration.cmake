set(MONGO_ORCHESTRATION_VERSION 0.6.11)

add_custom_command(
  OUTPUT ${TEST_INSTALL_PREFIX}/bin/pip
  COMMAND virtualenv ${TEST_INSTALL_PREFIX}
)
add_custom_command(
  OUTPUT ${TEST_INSTALL_PREFIX}/bin/mongo-orchestration
  DEPENDS ${TEST_INSTALL_PREFIX}/bin/pip
  COMMAND ${TEST_INSTALL_PREFIX}/bin/pip install --ignore-installed 'mongo-orchestration==${MONGO_ORCHESTRATION_VERSION}'
)

add_custom_target(mongo-orchestration DEPENDS ${TEST_INSTALL_PREFIX}/bin/mongo-orchestration)

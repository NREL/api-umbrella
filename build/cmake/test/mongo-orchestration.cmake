# Python test dependencies (mongo-orchestration)
add_custom_command(
  OUTPUT ${TEST_INSTALL_PREFIX}/bin/pip
  COMMAND virtualenv ${TEST_INSTALL_PREFIX}
)
add_custom_target(test_virtualenv ALL DEPENDS ${TEST_INSTALL_PREFIX}/bin/pip)
add_custom_command(
  OUTPUT ${TEST_INSTALL_PREFIX}/bin/mongo-orchestration
  COMMAND ${TEST_INSTALL_PREFIX}/bin/pip install --ignore-installed 'mongo-orchestration==${MONGO_ORCHESTRATION_VERSION}'
)
add_custom_target(test_pip_install ALL DEPENDS ${TEST_INSTALL_PREFIX}/bin/mongo-orchestration)

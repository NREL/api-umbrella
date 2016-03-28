# Python test dependencies (mongo-orchestration)
add_custom_command(
  OUTPUT ${TEST_INSTALL_PREFIX}/bin/pip
  COMMAND virtualenv ${TEST_INSTALL_PREFIX}
)
add_custom_target(test_virtualenv ALL DEPENDS ${TEST_INSTALL_PREFIX}/bin/pip)
add_custom_command(
  OUTPUT ${TEST_INSTALL_PREFIX}/bin/mongo-orchestration
  DEPENDS ${TEST_INSTALL_PREFIX}/bin/pip ${CMAKE_SOURCE_DIR}/test/requirements.txt
  COMMAND ${TEST_INSTALL_PREFIX}/bin/pip install -r ${CMAKE_SOURCE_DIR}/test/requirements.txt
)
add_custom_target(test_pip_install ALL DEPENDS ${TEST_INSTALL_PREFIX}/bin/mongo-orchestration)

# Python test dependencies (mongo-orchestration)
add_custom_command(
  OUTPUT ${TEST_STAGE_PREFIX_DIR}/bin/pip
  COMMAND virtualenv ${TEST_STAGE_PREFIX_DIR}
)
add_custom_target(test_virtualenv ALL DEPENDS ${TEST_STAGE_PREFIX_DIR}/bin/pip)
add_custom_command(
  OUTPUT ${TEST_STAGE_PREFIX_DIR}/bin/mongo-orchestration
  DEPENDS ${TEST_STAGE_PREFIX_DIR}/bin/pip ${CMAKE_SOURCE_DIR}/test/requirements.txt
  COMMAND ${TEST_STAGE_PREFIX_DIR}/bin/pip install -r ${CMAKE_SOURCE_DIR}/test/requirements.txt
)
add_custom_target(test_pip_install ALL DEPENDS ${TEST_STAGE_PREFIX_DIR}/bin/mongo-orchestration)

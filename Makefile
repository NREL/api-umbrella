# A minimal Makefile that downloads the "task" tool and passes things off to
# that tool for executing (so "make all" actually becomes "task all"). See
# Taskfile.yml for more detail.

ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
WORK_DIR:=$(ROOT_DIR)/build/work

.PHONY: default
default: all

# Download and locally install the "task" tool.
TASK_VERSION:=2.0.2
$(ROOT_DIR)/tasks/bootstrap-$(TASK_VERSION): ;
$(WORK_DIR)/stamp/bootstrap-$(TASK_VERSION): $(ROOT_DIR)/tasks/bootstrap-$(TASK_VERSION)
	$(ROOT_DIR)/tasks/bootstrap-$(TASK_VERSION)

# Match all commands sent to "make" and send them to "task" instead.
%: $(WORK_DIR)/stamp/bootstrap-$(TASK_VERSION)
	$(WORK_DIR)/task $(MAKECMDGOALS)

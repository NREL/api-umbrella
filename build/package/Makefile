SOURCE_DIR:=$(shell dirname $(shell dirname $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))))
WORK_DIR:=$(SOURCE_DIR)/build/work/package
LOG_DIR:=$(WORK_DIR)/log

.PHONY: \
	docker \
	docker_centos6 \
	docker_centos6_verify_only \
	docker_centos7 \
	docker_centos7_verify_only \
	docker_ubuntu1204 \
	docker_ubuntu1204_verify_only \
	docker_ubuntu1404 \
	docker_ubuntu1404_verify_only \
	docker_debian7 \
	docker_debian7_verify_only \
	docker_debian8 \
	docker_debian8_verify_only \

$(LOG_DIR):
	mkdir -p $@

$(WORK_DIR)/download_previous_packages.stamp: $(SOURCE_DIR)/build/package/verify/download_previous_packages
	$(SOURCE_DIR)/build/package/verify/download_previous_packages
	mkdir -p $(WORK_DIR)
	touch $@

docker: $(LOG_DIR)
	$(SOURCE_DIR)/build/package/docker_run > $(LOG_DIR)/$(DIST).log 2>&1
	$(SOURCE_DIR)/build/package/verify/docker_run >> $(LOG_DIR)/$(DIST).log 2>&1

docker_verify_only: $(WORK_DIR)/download_previous_packages.stamp | $(LOG_DIR)
	$(SOURCE_DIR)/build/package/verify/docker_run >> $(LOG_DIR)/$(DIST).log 2>&1

docker_centos6:
	DIST=centos-6 $(MAKE) docker

docker_centos6_verify_only:
	DIST=centos-6 $(MAKE) docker_verify_only

docker_centos7:
	DIST=centos-7 $(MAKE) docker

docker_centos7_verify_only:
	DIST=centos-7 $(MAKE) docker_verify_only

docker_ubuntu1204:
	DIST=ubuntu-12.04 $(MAKE) docker

docker_ubuntu1204_verify_only:
	DIST=ubuntu-12.04 $(MAKE) docker_verify_only

docker_ubuntu1404:
	DIST=ubuntu-14.04 $(MAKE) docker

docker_ubuntu1404_verify_only:
	DIST=ubuntu-14.04 $(MAKE) docker_verify_only

docker_debian7:
	DIST=debian-7 $(MAKE) docker

docker_debian7_verify_only:
	DIST=debian-7 $(MAKE) docker_verify_only

docker_debian8:
	DIST=debian-8 $(MAKE) docker

docker_debian8_verify_only:
	DIST=debian-8 $(MAKE) docker_verify_only

docker_all: \
	docker_centos6 \
	docker_centos7 \
	docker_ubuntu1204 \
	docker_ubuntu1404 \
	docker_debian7 \
	docker_debian8

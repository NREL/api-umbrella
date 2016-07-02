SOURCE_DIR:=$(shell dirname $(shell dirname $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))))
WORK_DIR:=$(SOURCE_DIR)/build/work/package
LOG_DIR:=$(WORK_DIR)/log

.PHONY: \
	docker \
	docker_build \
	docker_verify \
	docker_centos6 \
	docker_centos6_build \
	docker_centos6_verify \
	docker_centos7 \
	docker_centos7_build \
	docker_centos7_verify \
	docker_ubuntu1204 \
	docker_ubuntu1204_build \
	docker_ubuntu1204_verify \
	docker_ubuntu1404 \
	docker_ubuntu1404_build \
	docker_ubuntu1404_verify \
	docker_ubuntu1604 \
	docker_ubuntu1604_build \
	docker_ubuntu1604_verify \
	docker_debian7 \
	docker_debian7_build \
	docker_debian7_verify \
	docker_debian8 \
	docker_debian8_build \
	docker_debian8_verify \
	docker_all

$(LOG_DIR):
	mkdir -p $@

docker: | $(LOG_DIR)
	$(MAKE) docker_build
	$(MAKE) docker_verify

docker_build: | $(LOG_DIR)
	$(SOURCE_DIR)/build/package/docker_run > $(LOG_DIR)/$(DIST).log 2>&1

docker_verify: | $(LOG_DIR)
	$(SOURCE_DIR)/build/package/verify/download_previous_packages >> $(LOG_DIR)/$(DIST).log 2>&1
	$(SOURCE_DIR)/build/package/verify/docker_run >> $(LOG_DIR)/$(DIST).log 2>&1

docker_centos6:
	DIST=centos-6 $(MAKE) docker

docker_centos6_build:
	DIST=centos-6 $(MAKE) docker_build

docker_centos6_verify:
	DIST=centos-6 $(MAKE) docker_verify

docker_centos7:
	DIST=centos-7 $(MAKE) docker

docker_centos7_build:
	DIST=centos-7 $(MAKE) docker_build

docker_centos7_verify:
	DIST=centos-7 $(MAKE) docker_verify

docker_ubuntu1204:
	DIST=ubuntu-12.04 $(MAKE) docker

docker_ubuntu1204_build:
	DIST=ubuntu-12.04 $(MAKE) docker_build

docker_ubuntu1204_verify:
	DIST=ubuntu-12.04 $(MAKE) docker_verify

docker_ubuntu1404:
	DIST=ubuntu-14.04 $(MAKE) docker

docker_ubuntu1404_build:
	DIST=ubuntu-14.04 $(MAKE) docker_build

docker_ubuntu1404_verify:
	DIST=ubuntu-14.04 $(MAKE) docker_verify

docker_ubuntu1604:
	DIST=ubuntu-16.04 $(MAKE) docker

docker_ubuntu1604_build:
	DIST=ubuntu-16.04 $(MAKE) docker_build

docker_ubuntu1604_verify:
	DIST=ubuntu-16.04 $(MAKE) docker_verify

docker_debian7:
	DIST=debian-7 $(MAKE) docker

docker_debian7_build:
	DIST=debian-7 $(MAKE) docker_build

docker_debian7_verify:
	DIST=debian-7 $(MAKE) docker_verify

docker_debian8:
	DIST=debian-8 $(MAKE) docker

docker_debian8_build:
	DIST=debian-8 $(MAKE) docker_build

docker_debian8_verify:
	DIST=debian-8 $(MAKE) docker_verify

docker_all: docker_centos6 \
	docker_centos7 \
	docker_ubuntu1204 \
	docker_ubuntu1404 \
	docker_ubuntu1604 \
	docker_debian7 \
	docker_debian8

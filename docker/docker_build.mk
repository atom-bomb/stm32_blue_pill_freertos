#!/usr/bin/make

PWD?=$(shell pwd)

# check to see if the build is already inside of a docker container
# in order to prevent container recursion
# no matter how funny that may seem
DOCKER_RUNNING:=$(shell \
  if [ -f /.dockerenv ]; then echo true;\
  else echo false; fi)

ifeq ($(DOCKER_RUNNING),false)

ifeq ($(USE_DOCKER),true)

# docker must be installed in order to use docker
# other than that, the docker file should handle all build tool prereqs
DOCKER=$(shell which docker)
ifeq ($(DOCKER),)
  $(error Install docker)
endif

$(info XXX building in a docker container)

# guess where this makefile include is kept
# so that the default dockerfile can be found
DOCKER_MAKE_INCLUDE:=$(lastword $(MAKEFILE_LIST))
DOCKER_MAKE_INCLUDE_DIR:=$(dir $(DOCKER_MAKE_INCLUDE))

# if unspecified, use this docker image
DOCKER_IMAGE_TAG?=docker_build
DOCKER_FILE?=$(DOCKER_MAKE_INCLUDE_DIR)/default_dockerfile

# HOST_SOURCE_DIR is mapped to CONTAINER_SOURCE_DIR inside the build container
HOST_SOURCE_DIR?=$(PWD)
CONTAINER_SOURCE_DIR?=/home/user/docker_build
CONTAINER_MAKE?=make

CONTAINER_DEVICES?=/dev/ttyUSB0

CONTAINER_VALID_DEVICES?=$(shell\
  for DEV in $(CONTAINER_DEVICES); do\
    if [ -c $$DEV ]; then \
      echo $$DEV;\
    fi;\
  done)

UID?=$(shell id -u)
GID?=$(shell id -g)

# find all makefile variables that have been passed on the command line
# so that they may be passed to the container build
# TODO consider also passing variables set from the environment
COMMAND_LINE_DEFS:=$(strip \
$(foreach HOST_VAR,$(.VARIABLES),\
$(if $(findstring command line,$(origin $(HOST_VAR))),\
$(HOST_VAR)=$($(HOST_VAR)))))

DOCKER_BUILD_CMD=\
	$(DOCKER) build --build-arg UID=$(UID) --build-arg GID=$(GID) \
                --tag $(DOCKER_IMAGE_TAG) --file $(DOCKER_FILE) .

DOCKER_RUN_CMD=\
	$(DOCKER) run -it \
                -v $(HOST_SOURCE_DIR):$(CONTAINER_SOURCE_DIR) \
                $(addprefix --device ,$(CONTAINER_VALID_DEVICES)) \
		--rm $(DOCKER_IMAGE_TAG) \
		$(CONTAINER_MAKE) -C $(CONTAINER_SOURCE_DIR) \
			$(COMMAND_LINE_DEFS) $(@:docker_build=)

# override all build goals so that the docker container is always invoked
docker_build:
	$(DOCKER_BUILD_CMD)
	$(DOCKER_RUN_CMD) $(@:docker_build=)

%:
	$(DOCKER_BUILD_CMD)
	$(DOCKER_RUN_CMD) $(@:docker_build=)

distclean:
	$(DOCKER_BUILD_CMD)
	$(DOCKER_RUN_CMD) $@
	$(DOCKER) image rm $(DOCKER_IMAGE_TAG)

.DEFAULT_GOAL:=docker_build

#else USE_DOCKER=true
else

# if USE_DOCKER=true was not specified, spew out a message in case
# the user hasn't natively installed all of the build prereq's
# and is about to get a disappointing failure
$(info XXX building in the native environment)
$(info XXX specify USE_DOCKER=true to build in a docker container)

#endif USE_DOCKER=false
endif

#endif DOCKER_RUNNING=false
endif

USE_DOCKER?=true
include docker/docker_build.mk

ifeq ($(DOCKER_RUNNING),true)
include Makefile
endif 

.PHONY: build tag push clean

CONTAINER_RUNTIME?=$(shell which docker)

IMAGE_NAME:=fisher772/vpn-strongswan
FULL_IMAGE_NAME=${IMAGE_NAME}:${VERSION}
FULL_IMAGE_NAME_LATEST=${IMAGE_NAME}:latest

VERSION:=

REMOTE_REGISTRY_NAME?=
DOCKER_USER:=
DOCKER_TOKEN:=

build:
	@echo "Building the image..."
	${CONTAINER_RUNTIME} build \
	--file Dockerfile \
	--no-cache \
	--pull \
	--tag ${FULL_IMAGE_NAME} \
	--tag ${FULL_IMAGE_NAME_LATEST} \
	.

tag:
	@echo "Tagging the image..."
	${CONTAINER_RUNTIME} tag $(IMAGE_NAME) ${FULL_IMAGE_NAME_LATEST}
	${CONTAINER_RUNTIME} tag $(IMAGE_NAME) ${FULL_IMAGE_NAME}

push:
	@echo "Pushing the image..."
	echo ${DOCKER_TOKEN} | ${CONTAINER_RUNTIME} login ${REMOTE_REGISTRY_NAME} --username ${DOCKER_USER} --password-stdin; \
	${CONTAINER_RUNTIME} push ${FULL_IMAGE_NAME} && ${CONTAINER_RUNTIME} push ${FULL_IMAGE_NAME_LATEST}

clean:
	@echo "Cleaning up..."
	${CONTAINER_RUNTIME} rmi ${FULL_IMAGE_NAME}
	${CONTAINER_RUNTIME} rmi ${FULL_IMAGE_NAME_LATEST}

all: build tag push clean

vars:
	@./make-vars.sh

help:
	@echo "Usage:"
	@echo "  make build   - Build the Docker image"
	@echo "  make tag     - Tag the Docker image with version $(VERSION) and latest"
	@echo "  make push    - Push the Docker image to the registry"
	@echo "  make clean   - Remove the Docker image"
	@echo "  make all     - Starting all blocks"
	@echp "  make vars    - Use the automatic assignment of dynamic values for variables at your discretion"
	@echo "  make help    - Display this help message"

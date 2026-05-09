BUILDDIR?=./.build
CURRENT_BRANCH:=$(shell git rev-parse --abbrev-ref HEAD)
VERSION:=$(shell git describe --tags --abbrev=0)
LOCAL_PORT?=13000

.PHONY: help run
.DEFAULT_GOAL := help

CONTAINER_NAME=docmost
DOCKER_IMAGE=docker.k-tech.it/kt/${CONTAINER_NAME}
DOCKER_IMAGE_FULLNAME=${DOCKER_IMAGE}:${VERSION}

ifeq ($(wildcard .python-version),)
    PYTHON_VERSION = ""
else
    PYTHON_VERSION = $(shell head -1 .python-version)
endif

ifeq ($(wildcard .initialized),)
    INITIALIZED = 0
else
    INITIALIZED = 1
endif

guard-%:
	@if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
        exit 1; \
    fi


define BROWSER_PYSCRIPT
import os, webbrowser, sys

from urllib.request import pathname2url

webbrowser.open("file://" + pathname2url(os.path.abspath(sys.argv[1])))
endef
export BROWSER_PYSCRIPT

define PRINT_HELP_PYSCRIPT
import re, sys

for line in sys.stdin:
	match = re.match(r'^([a-zA-Z0-9_-]+):.*?## (.*)$$', line)
	if match:
		target, help = match.groups()
		print("%-20s %s" % (target, help))
endef
export PRINT_HELP_PYSCRIPT

BROWSER := python -c "$$BROWSER_PYSCRIPT"

help:
	@python -c "$$PRINT_HELP_PYSCRIPT" < $(MAKEFILE_LIST)


build: ## Builds the image
	cd .. && docker build \
		${BUILD_OPTIONS} \
		--platform linux/amd64 \
		--progress plain \
		--build-arg VERSION="${VERSION}" \
		--build-arg DOCKER_REGISTRY="${DOCKER_REGISTRY}" \
		-t ${DOCKER_IMAGE_FULLNAME} \
		-f Dockerfile .
	@docker images | grep ${DOCKER_IMAGE} | grep ${VERSION}


.guards: guard-DOCMOST_SECRET \
		 guard-DOCMOST_DB_URL \
		 guard-DOCMOST_REDIS_URL \
		 guard-DOCMOST_SMTP_HOST \
		 guard-DOCMOST_SMTP_PORT \
		 guard-DOCMOST_SMTP_SECURE \
		 guard-DOCMOST_STORAGE


.run: .guards
	$(eval TMPSTATIC := $(shell mktemp -d))
	docker run \
			--rm \
	 		--name=${CONTAINER_NAME} \
			-p "${LOCAL_PORT}:3000" \
			-e APP_URL="http://docmost.local:13000" \
			-e APP_SECRET="${DOCMOST_SECRET}" \
			-e DATABASE_URL="${DOCMOST_DB_URL}" \
			-e REDIS_URL="${DOCMOST_REDIS_URL}" \
			-e MAIL_DRIVER=smtp \
			-e SMTP_HOST="${DOCMOST_SMTP_HOST}" \
			-e SMTP_PORT=${DOCMOST_SMTP_PORT} \
			-e SMTP_USERNAME="${DOCMOST_SMTP_USER}"\
			-e SMTP_PASSWORD="${DOCMOST_SMTP_PASSWORD}" \
			-e SMTP_SECURE="${DOCMOST_SMTP_SECURE}" \
			-e MAIL_FROM_ADDRESS=noreply@singlewave.co.uk \
			-e MAIL_FROM_NAME=Docmost \
			--hostname docmost.local \
			-v "${DOCMOST_STORAGE}:/app/data/storage" \
			${RUN_OPTIONS} \
			${DOCKER_IMAGE_FULLNAME} \
			${CMD}
	rm -rf $(TMPSTATIC)

run: ## run docker container locally with http
	STACK_PROTOCOL=http $(MAKE) .run

.reset-storage: guard-DOCMOST_DB_PORT guard-DOCMOST_DB_NAME guard-DOCMOST_BACKUP ## DANGER: give a source folder (obtained from a backup) it will destroy local DB and storage and recreate them
	sudo rm -rf ../.mount/storage/* && cp -R ${DOCMOST_BACKUP}/storage/* ../.mount/storage
	psql -h localhost -p "${DOCMOST_DB_PORT}" -U postgres -c "DROP DATABASE IF EXISTS ${DOCMOST_DB_NAME}"
	psql -h localhost -p "${DOCMOST_DB_PORT}" -U postgres -c "CREATE DATABASE ${DOCMOST_DB_NAME} OWNER docmost"
	psql -h localhost -p ${DOCMOST_DB_PORT} -U postgres --set ON_ERROR_STOP=on -d ${DOCMOST_DB_NAME} < `ls -1 ${DOCMOST_BACKUP}/docmost*.sql`

release-latest: ## Release
	@docker tag ${DOCKER_IMAGE_FULLNAME} ${DOCKER_IMAGE}:latest
	@docker push ${DOCKER_IMAGE_FULLNAME}
	@docker push ${DOCKER_IMAGE}:latest

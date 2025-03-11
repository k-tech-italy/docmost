.PHONY: help runonce run i18n build
#.ONESHELL:
.DEFAULT_GOAL := help

NVM_EXISTS := $(shell if [ -d "${HOME}/.nvm" ]; then echo "nvm installed"; fi)

NPM_VER := $(shell cat .nvmrc)
NPM_INSTALLED := $(shell . ${HOME}/.nvm/nvm.sh && nvm ls | grep -E "\->\s+v${NPM_VER}\.\d{1,2}\.\d{1,3}")
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
HASH := $(shell git rev-parse HEAD)
VERSION := `grep version package.json | cut -d '"' -f 4`

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


develop:  ## Develop
	@if [ "${NVM_EXISTS}" = "" ]; then \
		echo "nvm not found. Install it first"; \
		exit 1; \
  	fi
	@if [ "${NPM_INSTALLED}" = "" ]; then \
  		echo "Installing version ${NPM_VER}" ; \
		. ${HOME}/.nvm/nvm.sh && nvm install ${NPM_VER} ; \
	fi
	@if [ "`npm ls -g | grep "└── pnpm@"`" = "" ]; then \
  		echo "Installing pnpm globally." ; \
	    npm install -g pnpm ; \
	fi
	pnpm install
	direnv allow

build:  ## Build
	pnpm nx run @docmost/editor-ext:build
	pnpm build

docker:
	docker build -t docker.k-tech.it/docmost-kt:${VERSION}-${BRANCH} -t docker.k-tech.it/docmost-kt:latest .

run:
	docker run --rm \
		-e APP_URL=http://${DOCKER_HUB}:9999 \
		-e APP_SECRET=${APP_SECRET} \
		-e DATABASE_URL=${DOCKER_DB_URL} \
		-e SMTP_HOST=${DOCKER_HUB} \
		-e SMTP_PORT=1025 \
		-e SMTP_SECURE=0 \
		-e MAIL_FROM_ADDRESS=noreply@noreply.com \
      	-e MAIL_FROM_NAME=Docmost \
      	-e REDIS_URL=redis://${DOCKER_HUB}:6379 \
      	--add-host ${DOCKER_SSO_HOST} \
      	--name docmost-temp \
		-p "9999:3000" \
		-v "./~storage:/app/data/storage" \
		docker.k-tech.it/docmost-kt:latest

exec:
	docker exec -it docmost-temp /bin/bash

docker-migrate:
	echo "Does not work yet as tsx is not installed"
	#docker run --rm \
#		-e APP_URL=http://${DOCKER_HUB}:9999 \
#		-e APP_SECRET=${APP_SECRET} \
#		-e DATABASE_URL=${DOCKER_DB_URL} \
#		-e SMTP_HOST=${DOCKER_HUB} \
#		-e SMTP_PORT=1025 \
#		-e SMTP_SECURE=0 \
#		-e MAIL_FROM_ADDRESS=noreply@noreply.com \
#      	-e MAIL_FROM_NAME=Docmost \
#      	-e REDIS_URL=redis://${DOCKER_HUB}:6379 \
#      	--add-host ${DOCKER_SSO_HOST} \
#		-p "9999:3000" \
#		-v "./~storage:/app/data/storage" \
#		docker.k-tech.it/docmost-kt:latest \
#		bash -c "cd /app/apps/server && pnpm install tsx && pnpm run migration:latest"
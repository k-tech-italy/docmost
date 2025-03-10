.PHONY: help runonce run i18n build
#.ONESHELL:
.DEFAULT_GOAL := help

NVM_EXISTS := $(shell if [ -d "${HOME}/.nvm" ]; then echo "nvm installed"; fi)

NPM_VER := $(shell cat .nvmrc)
NPM_INSTALLED := $(shell source ${HOME}/.nvm/nvm.sh && nvm ls | grep -E "\->\s+v${NPM_VER}\.\d{1,2}\.\d{1,3}")

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
		source ${HOME}/.nvm/nvm.sh && nvm install ${NPM_VER} ; \
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

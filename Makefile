# PACKAGE_NAME_FILE := .package-name
# PACKAGE_NAME := $(shell cat $(PACKAGE_NAME_FILE))
# MODULE_NAME := $(subst -,_,$(PACKAGE_NAME))
# PYTHON_VERSION_FILE := .python-version
# PYTHON_VERSION := $(shell cat $(PYTHON_VERSION_FILE))

# Most useful make commands in this file:
#		dev-full-install: Installs the dev environment needed develop this app.
#			Does a full install including reinstalling python with pyenv.
#		dev-basic-install: Installs the dev environment without installing
#			python.
#		pip-install-e: Install the package in an editable state so that you can run
#			tests, coverage reports, etc.
#		build: Builds distribution files with setup.py.
#		test: Runs tests with pytest.
#		lint: Lints with flake8.
#		types: Checks types with mypy.
#		coverage: Checks test coverage.
#		docs: Generates sphinx autodocs.

##
# Django targets
##
.PHONY: runserver
runserver:
	@echo "Launching django site locally on port 8080..."
	@python manage.py runserver 8080


##
# Environment setup and teardown
##

# Install the needed python version using pyenv (or delete and reinstall if the
# python version is already installed), and then install all project
# dependencies.
.PHONY: dev-full-install
dev-full-install: install-python build-virtualenv install-dev-reqs pip-install-e

# Install all project dependencies without installing a new version of python
# with pyenv.
.PHONY: dev-basic-install
dev-basic-install: build-virtualenv install-dev-reqs pip-install-e

.PHONY: install-python
install-python:
	@echo "Installing python $(PYTHON_VERSION)"
	@pyenv install $(PYTHON_VERSION)

.PHONY: uninstall-python
uninstall-python:
	@echo "Uninstalling python $(PYTHON_VERSION)"
	@pyenv uninstall -f $(PYTHON_VERSION)

.PHONY: build-virtualenv
build-virtualenv:
	@echo "Building virtualenv: $(PACKAGE_NAME)"
	@eval "$$(pyenv init -)" && \
	eval "$$(pyenv virtualenv-init -)" && \
	pyenv virtualenv -f $(PYTHON_VERSION) $(PACKAGE_NAME)

.PHONY: destroy-virtualenv
destroy-virtualenv:
	@echo "Destroying virtualenv: $(PACKAGE_NAME)"
	@eval "$$(pyenv init -)" && \
	eval "$$(pyenv virtualenv-init -)" && \
	pyenv uninstall -f $(PACKAGE_NAME)

.PHONY: install-dev-reqs
install-dev-reqs:
	@echo "Installing dev requirements for virtualenv: $(PACKAGE_NAME)"
	@eval "$$(pyenv init -)" && \
	eval "$$(pyenv virtualenv-init -)" && \
	pyenv activate $(PACKAGE_NAME) && \
	pip install --upgrade pip setuptools wheel && \
	pip install -U -r requirements.txt && \
	pip install -U -r docs/requirements.txt

.PHONY: pip-install-e
pip-install-e:
	@echo "Installing python package in editable state"
	@eval "$$(pyenv init -)" && \
	eval "$$(pyenv virtualenv-init -)" && \
	pyenv activate $(PACKAGE_NAME) && \
	pip install --upgrade pip setuptools wheel && \
	pip install -e .

##
# Build
##

# general build command for building a normal python project.
.phony: build
build: clean
	@python setup.py sdist

##
# Clean
##

.PHONY: clean
clean:
	@python setup.py clean

##
# Code validation
##

# The test, lint, and coverage commands can only be run if the project is
# installed in an editable state. If it is not, first run `make pip-install-e`.
# `pip-install-e` is not included as a dependency of these commands so as to
# keep running them as fast as possible.

.PHONY: lint
lint:
	@echo "Linting the project using flake8."
	@python -m flake8 . --count --statistics --exclude=terraform

.PHONY: black
black:
	@echo "Reformatting code using black"
	@python -m black -l 79 . --exclude 'terraform'

.PHONY: types
types:
	@echo "Running mypy to check all type hints"
	@python -m mypy .

.PHONY: test
test:
	@python -m py.test

.PHONY: generate-coverage-report
generate-coverage-report:
	@python -m coverage run --source=./$(MODULE_NAME) -m py.test
	@python -m coverage html

.PHONY: coverage
coverage: generate-coverage-report
	@open htmlcov/index.html

# Returns a failing exit code if the coverage is under the threshold of 90%
.PHONY: check-coverage
check-coverage:
	@python -m coverage report --fail-under=90

##
# Sphinx docs
##

.PHONY: clean-docs
clean-docs:
	@echo "Cleaning the docs folder"
	@cd docs && make clean
	@rm -rf docs/build
	@rm -rf docs/source/package_source
	@rm -rf docs/source/_static
	@rm -rf docs/source/_templates

.PHONY: generate-docs
generate-docs: clean-docs
	@echo "Generating the Sphinx HTML docs"
	@mkdir -p docs/source/package_source
	@mkdir -p docs/source/_static
	@mkdir -p docs/source/_templates
	@pip install -e .
	@cd docs && sphinx-apidoc -o ./source/package_source ../$(MODULE_NAME)
	@cd docs && make html

.PHONY: docs
docs: generate-docs
	# This will open docs in a browser
	@open docs/build/html/index.html

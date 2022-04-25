PYTHON_CMD ?= python
PIP_CMD ?= pip
PYTHON_MODULE_NAME ?= netbox
PYTHON_MODULE_VERSION ?= 0.0.0 # manged by poetry-dynamic-versioning

# Override in CI
.EXPORT_ALL_VARIABLES:
NETBOX_CONFIGURATION ?= netbox.configuration_testing

init_pip:
	@echo "Initializing using '$(PIP_CMD)"
	$(PIP_CMD) show -q poetry || $(PIP_CMD) install poetry
	$(PIP_CMD) show -q poetry-dynamic-versioning || $(PIP_CMD) install poetry-dynamic-versioning
	poetry install
	poetry version --no-ansi
	touch init_pip

init_pipx:
	@echo "Initializing using 'pipx'"
	$(PIP_CMD) show -q pipx || $(PIP_CMD) install pipx
	$(PYTHON_CMD) -m pipx ensurepath
	$(PYTHON_CMD) -m pipx runpip poetry show -q poetry || $(PYTHON_CMD) -m pipx install poetry
	$(PYTHON_CMD) -m pipx runpip poetry show -q  poetry-dynamic-versioning || $(PYTHON_CMD) -m pipx inject poetry poetry-dynamic-versioning
	poetry install
	poetry version --no-ansi
	touch init_pipx

fmt:
	@echo "Format code"
	poetry run black $(PYTHON_MODULE_NAME)

poetry.lock:
	@echo "Locking dependencies in poetry.lock"
	poetry lock
	poetry version --no-ansi

docs: poetry.lock
	@echo "Building documentation using mkdocs"
	poetry run mkdocs build

syntax: poetry.lock
	@echo "Running syntax tests"
	poetry run pycodestyle --ignore=W504,E501 --exclude=node_modules $(PYTHON_MODULE_NAME)/
	poetry run flake8 $(PYTHON_MODULE_NAME) --count --exit-zero --statistics
	poetry run bandit -r $(PYTHON_MODULE_NAME)

build: poetry.lock
	@echo "Building using poetyr"
	poetry version --no-ansi
	cat $(PYTHON_MODULE_NAME)/_$(PYTHON_MODULE_NAME)_version.py
	poetry build

clean:
	@echo "Clean up"
	git clean -fdx

static:
	@echo "Collect static files"
	poetry run python $(PYTHON_MODULE_NAME)/manage.py collectstatic --no-input

tests:
	@echo "Run tests"
	poetry run coverage run --source="$(PYTHON_MODULE_NAME)/" $(PYTHON_MODULE_NAME)/manage.py test $(PYTHON_MODULE_NAME)/ --parallel

	@echo "Show coverage report"
	poetry run coverage report --skip-covered --omit *migrations*

pex: build
	mkdir -p dist/pex/
	poetry export -f requirements.txt -o dist/pex/requirements.txt --without-hashes
	poetry run pex . \
		--find-links=dist/ \
		--entry-point="$(PYTHON_MODULE_NAME).manage:main" \
		--requirement=dist/pex/requirements.txt \
		--output-file=dist/pex/$(PYTHON_MODULE_NAME).pex \
		--resolver-version=pip-2020-resolver \
		--pre \
		--wheel \
		--jobs=4 \
		--interpreter-constraint="CPython>=3.8,<3.10" \
		--python-shebang="/usr/bin/env python3" \
		--manylinux=manylinux2014
	du -hs dist/pex/$(PYTHON_MODULE_NAME).pex

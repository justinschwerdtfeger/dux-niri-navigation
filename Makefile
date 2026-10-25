.PHONY: check test test-qml lint format check-qml dev-up dev-check link-plugin

check: test lint check-qml

test:
	python3 scripts/check.py
	npm test
	python3 -m unittest discover -s tests -p 'test_*.py'

test-qml:
	QT_QPA_PLATFORM=offscreen $(QMLTESTRUNNER) -import tests/qml/imports -input tests/qml

lint:
	ruff check scripts tests
	ruff format --check scripts tests
	npm run lint
	bash -n scripts/link-plugin.sh .devcontainer/setup.sh
	$(SHELLCHECK) scripts/link-plugin.sh .devcontainer/setup.sh
	git diff --check

check-qml:
	python3 scripts/qml-tools.py lint
	python3 scripts/qml-tools.py check-format

format:
	ruff check scripts tests --fix
	ruff format scripts tests
	npm run format
	python3 scripts/qml-tools.py format

SHELLCHECK ?= shellcheck
QMLTESTRUNNER ?= qmltestrunner
DEVCONTAINER ?= devcontainer
DEVCONTAINER_UP_ARGS ?=
CONTAINER_ENGINE ?= docker

dev-up:
	@common_dir="$$(git rev-parse --path-format=absolute --git-common-dir)" && \
	$(DEVCONTAINER) up --docker-path $(CONTAINER_ENGINE) --workspace-folder "$(CURDIR)" \
		--mount "type=bind,source=$$common_dir,target=$$common_dir" $(DEVCONTAINER_UP_ARGS)

dev-check:
	$(DEVCONTAINER) exec --docker-path $(CONTAINER_ENGINE) --workspace-folder "$(CURDIR)" make check test-qml

link-plugin:
	bash scripts/link-plugin.sh

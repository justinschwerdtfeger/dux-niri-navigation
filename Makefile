.PHONY: check test test-qml lint format check-qml dev-up dev-check link-plugin package

check: test lint check-qml

test: package
	python3 scripts/check.py
	npm test
	python3 -m unittest discover -s tests -p 'test_*.py'

test-qml: package
	python3 scripts/test_qml.py --runner "$(QMLTESTRUNNER)"

lint:
	ruff check scripts shared tests
	ruff format --check scripts shared tests
	npm run lint
	bash -n scripts/link-plugin.sh .devcontainer/setup.sh
	$(SHELLCHECK) scripts/link-plugin.sh .devcontainer/setup.sh
	git diff --check

check-qml: package
	python3 scripts/qml-tools.py lint
	python3 scripts/qml-tools.py check-format

format:
	ruff check scripts shared tests --fix
	ruff format scripts shared tests
	npm run format
	python3 scripts/qml-tools.py format

SHELLCHECK ?= shellcheck
QMLTESTRUNNER ?= qmltestrunner
DEVCONTAINER ?= devcontainer
DEVCONTAINER_UP_ARGS ?=
CONTAINER_ENGINE ?= docker

dev-up:
	@common_dir="$$(git rev-parse --path-format=absolute --git-common-dir)" || exit; \
	case "$$common_dir" in \
	    "$(CURDIR)"|"$(CURDIR)"/*) set -- ;; \
	    *,*) echo 'Cannot mount a Git directory containing a comma.' >&2; exit 1 ;; \
	    *) set -- --mount "type=bind,source=$$common_dir,target=$$common_dir" ;; \
	esac; \
	$(DEVCONTAINER) up --docker-path "$(CONTAINER_ENGINE)" --workspace-folder "$(CURDIR)" $(DEVCONTAINER_UP_ARGS) "$$@"

dev-check:
	$(DEVCONTAINER) exec --docker-path "$(CONTAINER_ENGINE)" --workspace-folder "$(CURDIR)" make check test-qml

PLUGIN ?= all

package:
	python3 scripts/package_plugins.py --plugin "$(PLUGIN)"

link-plugin: package
	bash scripts/link-plugin.sh "$(PLUGIN)"

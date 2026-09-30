.PHONY: check link-plugin

check:
	python3 scripts/check.py
	node tests/window-model.test.cjs
	bash -n scripts/link-plugin.sh
	git diff --check

link-plugin:
	bash scripts/link-plugin.sh

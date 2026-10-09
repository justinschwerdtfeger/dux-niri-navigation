.PHONY: check link-plugin

check:
	python3 scripts/check.py
	node tests/window-model.test.cjs
	node tests/workspace-model.test.cjs
	node tests/browser-model.test.cjs
	node tests/window-tabs-extension.test.cjs
	node --input-type=module --check < extensions/window-tabs/background.js
	python3 -m unittest discover -s tests -p 'test_*.py'
	bash -n scripts/link-plugin.sh
	git diff --check

link-plugin:
	bash scripts/link-plugin.sh

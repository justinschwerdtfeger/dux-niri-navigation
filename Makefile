.PHONY: check

check:
	python3 scripts/check.py
	git diff --check

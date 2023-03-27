.PHONY: smoke-test
smoke-test:
	rm -rf ./_www ./_cache || /bin/true
	mkdir ./_www ./_cache || /bin/true
	./godoc.sh
	cd ./_www && python -m http.server 8000

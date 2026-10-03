.PHONY: setup test build install release
setup:
	scripts/setup.sh
test:
	scripts/ci.sh
build:
	scripts/build.sh
install:
	scripts/build.sh --install
release:
	scripts/build-release.sh

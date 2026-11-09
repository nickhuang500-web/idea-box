# Build, install and run Idea Box.
#
#   make          build build/Idea Box.app
#   make install  build + copy to ~/Applications
#   make run      build + launch
#   make autostart / make no-autostart
#   make clean

APP := build/Idea Box.app

.PHONY: all build install run autostart no-autostart clean

all: build

build:
	./scripts/build.sh

install:
	./scripts/build.sh --install

run: install
	open "$(HOME)/Applications/Idea Box.app"

autostart: install
	./scripts/autostart.sh install

no-autostart:
	./scripts/autostart.sh uninstall

clean:
	rm -rf build

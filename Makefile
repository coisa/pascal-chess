FPC ?= fpc
FPCFLAGS = -Mobjfpc -Sh -O2 -g -gl -Cr -Co -Ci -Sa -vew -Fusrc -FUbuild -FEbuild
DOCKER ?= docker
IMAGE ?= pascal-chess:local
TEST_IMAGE ?= pascal-chess-test:local
SOURCES = $(wildcard src/*.pas)

.PHONY: help test image play smoke local-build local-test local-smoke local-play preview

help:
	@printf '%s\n' 'make test - reproducible rules, search, CLI and SDL checks' 'make play - offline terminal game in Docker' 'make local-play - build and launch the native desktop game' 'make local-build local-test local-smoke - use installed FPC, SDL2 and Python' 'make preview - capture the real renderer with Docker and ImageMagick'

build:
	mkdir -p build

build/chess: chess.pas $(SOURCES) | build
	$(FPC) $(FPCFLAGS) -ochess chess.pas

build/ChessCLI: ChessCLI.pas src/chess_engine.pas src/chess_search.pas | build
	$(FPC) $(FPCFLAGS) -oChessCLI ChessCLI.pas

build/test_chess: tests/test_chess.pas src/chess_engine.pas src/chess_search.pas | build
	$(FPC) $(FPCFLAGS) -otest_chess tests/test_chess.pas

local-build: build/chess build/ChessCLI
local-test: build/test_chess
	./build/test_chess
local-smoke: local-build
	python3 tests/smoke.py ./build/ChessCLI ./build/chess
local-play: build/chess
	./build/chess
test:
	$(DOCKER) build --target test -t $(TEST_IMAGE) .
	$(DOCKER) run --rm --network none $(TEST_IMAGE)
image:
	$(DOCKER) build --target game -t $(IMAGE) .
play: image
	$(DOCKER) run --rm -it --network none --read-only --cap-drop ALL --security-opt no-new-privileges $(IMAGE)
smoke:
	$(DOCKER) run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges $(IMAGE) --perft 3
	$(DOCKER) run --rm --network none --read-only --cap-drop ALL --security-opt no-new-privileges $(IMAGE) --search --nodes 2000
preview: | build
	$(DOCKER) build --target build -t pascal-chess-build:local .
	$(DOCKER) run --rm --network none -e SDL_VIDEODRIVER=dummy --mount "type=bind,src=$(CURDIR)/build,target=/captures" pascal-chess-build:local ./build/chess --snapshot /captures/play.bmp --scene play --no-audio
	magick build/play.bmp -strip docs/preview.png

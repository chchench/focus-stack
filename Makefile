-include Makefile.local

# Default compilation flags, these can be overridden in Makefile.local
# or in environment like: CXXFLAGS=... make
CXX ?= g++
CXXFLAGS ?= -O2 -g3 -ggdb -Wall -Wextra -Wno-sign-compare
DESTDIR ?=
prefix ?= /usr/local

# Try to get opencv path from pkg-config
CXXFLAGS += $(shell pkg-config --silence-errors --cflags-only-I opencv4 || pkg-config --cflags-only-I opencv)
LDFLAGS += $(shell pkg-config --silence-errors --libs-only-L opencv4 || pkg-config --silence-errors --cflags-only-I opencv)

# Required compilation options
CXXFLAGS += --std=c++14
LDFLAGS += -lpthread -lm
LDFLAGS += -lopencv_video -lopencv_imgcodecs -lopencv_photo -lopencv_imgproc -lopencv_core

VERSION = $(shell git describe)
CXXFLAGS += -DGIT_VERSION=\"$(shell git describe --always --dirty 2>/dev/null)\"

# List of source code files
CXXSRCS += focusstack.cc worker.cc options.cc
CXXSRCS += task_align.cc task_grayscale.cc task_loadimg.cc
CXXSRCS += task_merge.cc task_reassign.cc task_saveimg.cc
CXXSRCS += task_wavelet.cc task_wavelet_opencl.cc task_denoise.cc

# Generate list of object file and dependency file names
OBJS = $(CXXSRCS:%.cc=build/%.o)
DEPS := $(OBJS:%.o=%.d)

# List of unit test files
TESTSRCS += task_grayscale_tests.cc
TESTSRCS += task_wavelet_tests.cc
TESTSRCS += task_wavelet_opencl_tests.cc

TESTOBJS = $(TESTSRCS:%.cc=build/%.o)
TESTDEPS := $(TESTOBJS:%.o=%.d)

$(shell mkdir -p build)

all: build/focus-stack

run_unittests: build/unittests
	build/unittests

clean:
	rm -rf build
	mkdir -p build

install: all
	install -D build/focus-stack $(DESTDIR)$(prefix)/bin/focus-stack
	mkdir -p $(DESTDIR)$(prefix)/share/man/man1/
	gzip -c docs/focus-stack.1 > $(DESTDIR)$(prefix)/share/man/man1/focus-stack.1.gz

make_debuild:
	rm -rf DEBUILD
	mkdir -p DEBUILD
	git archive --prefix=focus-stack.orig/ --format=tar.gz HEAD > DEBUILD/focus-stack_$(VERSION).orig.tar.gz
	(cd DEBUILD && tar xzf focus-stack_$(VERSION).orig.tar.gz && cp -pr focus-stack.orig focus-stack)

builddeb: make_debuild
	(cd DEBUILD/focus-stack && debuild -uc -us)

builddeb_signed: make_debuild
	(cd DEBUILD/focus-stack && debuild -S)

docs/focus-stack.html:
	mandoc -Thtml docs/focus-stack.1 > $@

-include $(DEPS)
-include $(TESTDEPS)

build/focus-stack: src/main.cc $(OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LDFLAGS)

build/%.o: src/%.cc
	$(CXX) $(CXXFLAGS) -MMD -c -o $@ $<

build/unittests: src/gtest_main.cc $(OBJS) $(TESTOBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ -lgtest $(LDFLAGS)

# Mac OS X application bundle
build/focus-stack.app: build/focus-stack packaging/macosx/focus-stack-gui.scpt packaging/macosx/Info.plist
	rm -rf "$@"
	osacompile -o "$@" packaging/macosx/focus-stack-gui.scpt
	mv "$@/Contents/MacOS/droplet" "$@/Contents/MacOS/focus-stack-gui"
	mv "$@/Contents/Resources/droplet.rsrc" "$@/Contents/Resources/focus-stack-gui.rsrc"
	sed "s/VERSION/$(VERSION)/g" <"packaging/macosx/Info.plist" >"$@/Contents/Info.plist"
	cp "packaging/macosx/PkgInfo" "$@/Contents"
	cp "build/focus-stack" "$@/Contents/MacOS"
	dylibbundler -x "$@/Contents/MacOS/focus-stack" -d "$@/Contents/libs" -od -b

build/focus-stack_MacOSX.zip: build/focus-stack.app
	rm -f "$@"
	cd build; zip -r focus-stack_MacOSX.zip focus-stack.app


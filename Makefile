#############################################
##                                         ##
##    Copyright (C) 2022-2022 Julian Uy    ##
##  https://sites.google.com/site/awertyb  ##
##                                         ##
##   See details of license at "LICENSE"   ##
##                                         ##
#############################################

TOOL_TRIPLET_PREFIX ?= i686-w64-mingw32-
CC := $(TOOL_TRIPLET_PREFIX)gcc
CXX := $(TOOL_TRIPLET_PREFIX)g++
AR := $(TOOL_TRIPLET_PREFIX)ar
WINDRES := $(TOOL_TRIPLET_PREFIX)windres
STRIP := $(TOOL_TRIPLET_PREFIX)strip
GIT_TAG := $(shell git describe --abbrev=0 --tags)
INCFLAGS += -I. -I.. -Iexternal/libjxl/lib/include -Iexternal/libjxl/build/lib/include
ALLSRCFLAGS += $(INCFLAGS) -DGIT_TAG=\"$(GIT_TAG)\"
CFLAGS += -O3 -flto
CFLAGS += $(ALLSRCFLAGS) -Wall -Wno-unused-value -Wno-format -DNDEBUG -DWIN32 -D_WIN32 -D_WINDOWS 
CFLAGS += -D_USRDLL -DUNICODE -D_UNICODE -DJXL_STATIC_DEFINE -DJXL_THREADS_STATIC_DEFINE
CXXFLAGS += $(CFLAGS) -fpermissive
WINDRESFLAGS += $(ALLSRCFLAGS) --codepage=65001
LDFLAGS += -static -static-libgcc -shared -Wl,--add-stdcall-alias
LDLIBS +=

%.o: %.c
	@printf '\t%s %s\n' CC $<
	$(CC) -c $(CFLAGS) -o $@ $<

%.o: %.cpp
	@printf '\t%s %s\n' CXX $<
	$(CXX) -c $(CXXFLAGS) -o $@ $<

%.o: %.rc
	@printf '\t%s %s\n' WINDRES $<
	$(WINDRES) $(WINDRESFLAGS) $< $@

LIBJXL_SOURCES += external/libjxl/build/lib/libjxl-static.a external/libjxl/build/lib/libjxl_threads-static.a external/libjxl/build/third_party/highway/libhwy.a external/libjxl/build/third_party/brotli/libbrotlicommon-static.a external/libjxl/build/third_party/brotli/libbrotlidec-static.a
SOURCES := extractor.c spi00in.c ifjxl.rc $(LIBJXL_SOURCES)
OBJECTS := $(SOURCES:.c=.o)
OBJECTS := $(OBJECTS:.cpp=.o)
OBJECTS := $(OBJECTS:.rc=.o)

BINARY ?= ifjxl_unstripped.spi
BINARY_STRIPPED ?= ifjxl.spi
ARCHIVE ?= ifjxl.7z

all: $(BINARY_STRIPPED)

archive: $(ARCHIVE)

clean:
	rm -f $(OBJECTS) $(BINARY) $(BINARY_STRIPPED) $(ARCHIVE)
	rm -rf external/libjxl/build

external/libjxl/build/lib/include/jxl/jxl_export.h: external/libjxl/build/lib/libjxl-static.a

external/libjxl/build/lib/libjxl_threads-static.a external/libjxl/build/third_party/highway/libhwy.a external/libjxl/build/third_party/brotli/libbrotlicommon-static.a external/libjxl/build/third_party/brotli/libbrotlidec-static.a: external/libjxl/build/lib/libjxl-static.a

extractor.o: external/libjxl/build/lib/include/jxl/jxl_export.h

external/libjxl/build/lib/libjxl-static.a:
	mkdir -p external/libjxl/build && cd external/libjxl/build && cmake -GNinja -DCMAKE_TOOLCHAIN_FILE=../../../mingw32.cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS="-DHWY_DISABLED_TARGETS=\"HWY_AVX2|HWY_AVX3\"" -DJPEGXL_ENABLE_JNI=OFF -DJPEGXL_ENABLE_MANPAGES=OFF -DJPEGXL_BUNDLE_GFLAGS=ON -DBUILD_TESTING=OFF -DJPEGXL_ENABLE_TOOLS=OFF -DJPEGXL_ENABLE_VIEWERS=OFF .. && ninja

$(ARCHIVE): $(BINARY_STRIPPED)
	rm -f $(ARCHIVE)
	7z a $@ $^

$(BINARY_STRIPPED): $(BINARY)
	@printf '\t%s %s\n' STRIP $@
	$(STRIP) -o $@ $^

$(BINARY): $(OBJECTS) 
	@printf '\t%s %s\n' LNK $@
	$(CXX) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LDLIBS)

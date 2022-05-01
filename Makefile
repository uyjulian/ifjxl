#############################################
##                                         ##
##    Copyright (C) 2019-2022 Julian Uy    ##
##  https://sites.google.com/site/awertyb  ##
##                                         ##
##   See details of license at "LICENSE"   ##
##                                         ##
#############################################

TARGET_ARCH ?= intel32
USE_STABS_DEBUG ?= 0
USE_POSITION_INDEPENDENT_CODE ?= 0
USE_ARCHIVE_HAS_GIT_TAG ?= 0
ifeq (x$(TARGET_ARCH),xarm32)
TOOL_TRIPLET_PREFIX ?= armv7-w64-mingw32-
endif
ifeq (x$(TARGET_ARCH),xarm64)
TOOL_TRIPLET_PREFIX ?= aarch64-w64-mingw32-
endif
ifeq (x$(TARGET_ARCH),xintel64)
TOOL_TRIPLET_PREFIX ?= x86_64-w64-mingw32-
endif
TOOL_TRIPLET_PREFIX ?= i686-w64-mingw32-
ifeq (x$(TARGET_ARCH),xarm32)
TARGET_CMAKE_SYSTEM_PROCESSOR ?= arm
endif
ifeq (x$(TARGET_ARCH),xarm64)
TARGET_CMAKE_SYSTEM_PROCESSOR ?= arm64
endif
ifeq (x$(TARGET_ARCH),xintel64)
TARGET_CMAKE_SYSTEM_PROCESSOR ?= amd64
endif
TARGET_CMAKE_SYSTEM_PROCESSOR ?= i686
CC := $(TOOL_TRIPLET_PREFIX)gcc
CXX := $(TOOL_TRIPLET_PREFIX)g++
AR := $(TOOL_TRIPLET_PREFIX)ar
WINDRES := $(TOOL_TRIPLET_PREFIX)windres
STRIP := $(TOOL_TRIPLET_PREFIX)strip
7Z := 7z
ifeq (x$(TARGET_ARCH),xintel32)
OBJECT_EXTENSION ?= .o
endif
OBJECT_EXTENSION ?= .$(TARGET_ARCH).o
DEP_EXTENSION ?= .dep.make
BUILD_DIR_EXTERNAL_NAME ?= build-$(TARGET_ARCH)
export GIT_TAG := $(shell git describe --abbrev=0 --tags)
INCFLAGS += -I. -I.. -Iexternal/libjxl/lib/include -Iexternal/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/include
ALLSRCFLAGS += $(INCFLAGS) -DGIT_TAG=\"$(GIT_TAG)\"
OPTFLAGS := -O3
ifeq (x$(TARGET_ARCH),xintel32)
OPTFLAGS += -march=pentium4 -mfpmath=sse
endif
ifeq (x$(TARGET_ARCH),xintel32)
ifneq (x$(USE_STABS_DEBUG),x0)
CFLAGS += -gstabs
else
CFLAGS += -gdwarf-2
endif
else
CFLAGS += -gdwarf-2
endif

ifneq (x$(USE_POSITION_INDEPENDENT_CODE),x0)
CFLAGS += -fPIC
endif
CFLAGS += -flto
CFLAGS += $(ALLSRCFLAGS) -Wall -Wno-unused-value -Wno-format -DNDEBUG -DWIN32 -D_WIN32 -D_WINDOWS 
CFLAGS += -D_USRDLL -DMINGW_HAS_SECURE_API -DUNICODE -D_UNICODE -DNO_STRICT
CFLAGS += -MMD -MF $(patsubst %$(OBJECT_EXTENSION),%$(DEP_EXTENSION),$@)
CFLAGS += -DJXL_STATIC_DEFINE -DJXL_THREADS_STATIC_DEFINE
CXXFLAGS += $(CFLAGS) -fpermissive
WINDRESFLAGS += $(ALLSRCFLAGS) --codepage=65001
LDFLAGS += $(OPTFLAGS) -static -static-libgcc -Wl,--add-stdcall-alias -fPIC
LDFLAGS_LIB += -shared
LDLIBS +=

%$(OBJECT_EXTENSION): %.c
	@printf '\t%s %s\n' CC $<
	$(CC) -c $(CFLAGS) $(OPTFLAGS) -o $@ $<

%$(OBJECT_EXTENSION): %.cpp
	@printf '\t%s %s\n' CXX $<
	$(CXX) -c $(CXXFLAGS) $(OPTFLAGS) -o $@ $<

%$(OBJECT_EXTENSION): %.rc
	@printf '\t%s %s\n' WINDRES $<
	$(WINDRES) $(WINDRESFLAGS) $< $@

PROJECT_BASENAME ?= ifjxl
ifeq (x$(TARGET_ARCH),xintel32)
BINARY ?= $(PROJECT_BASENAME)_unstripped.spi
endif
ifeq (x$(TARGET_ARCH),xintel64)
BINARY ?= $(PROJECT_BASENAME)_unstripped.sph
endif
BINARY ?= $(PROJECT_BASENAME)_$(TARGET_ARCH)_unstripped.spi
ifeq (x$(TARGET_ARCH),xintel32)
BINARY_STRIPPED ?= $(PROJECT_BASENAME).spi
endif
ifeq (x$(TARGET_ARCH),xintel64)
BINARY_STRIPPED ?= $(PROJECT_BASENAME).sph
endif
BINARY_STRIPPED ?= $(PROJECT_BASENAME)_$(TARGET_ARCH).spi
ifneq (x$(USE_ARCHIVE_HAS_GIT_TAG),x0)
ARCHIVE ?= $(PROJECT_BASENAME).$(TARGET_ARCH).$(GIT_TAG).7z
endif
ARCHIVE ?= $(PROJECT_BASENAME).$(TARGET_ARCH).7z

LIBJXL_LIBS += external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl_threads-static.a external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/third_party/highway/libhwy.a external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/third_party/brotli/libbrotlicommon-static.a external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/third_party/brotli/libbrotlidec-static.a
SOURCES := extractor.c spi00in.c ifjxl.rc
OBJECTS := $(SOURCES:.c=$(OBJECT_EXTENSION))
OBJECTS := $(OBJECTS:.cpp=$(OBJECT_EXTENSION))
OBJECTS := $(OBJECTS:.rc=$(OBJECT_EXTENSION))
DEPENDENCIES := $(OBJECTS:%$(OBJECT_EXTENSION)=%$(DEP_EXTENSION))
EXTERNAL_LIBS := $(LIBJXL_LIBS)

.PHONY:: all archive clean

all: $(BINARY_STRIPPED)

archive: $(ARCHIVE)

clean::
	rm -f $(OBJECTS) $(OBJECTS_BIN) $(BINARY) $(BINARY_STRIPPED) $(ARCHIVE) $(DEPENDENCIES)
	rm -rf external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)

external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/include/jxl/jxl_export.h: external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a

external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl_threads-static.a: external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a
external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/third_party/highway/libhwy.a: external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a
external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/third_party/brotli/libbrotlicommon-static.a: external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a
external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/third_party/brotli/libbrotlidec-static.a: external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a

extractor$(OBJECT_EXTENSION): external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/include/jxl/jxl_export.h

external/libjxl/$(BUILD_DIR_EXTERNAL_NAME)/lib/libjxl-static.a:
	mkdir -p external/libjxl/$(BUILD_DIR_EXTERNAL_NAME) && \
	cd external/libjxl/$(BUILD_DIR_EXTERNAL_NAME) && \
	cmake \
		-GNinja \
		-DCMAKE_SYSTEM_NAME=Windows \
		-DCMAKE_SYSTEM_PROCESSOR=$(TARGET_CMAKE_SYSTEM_PROCESSOR) \
		-DCMAKE_FIND_ROOT_PATH=/dev/null \
		-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
		-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
		-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
		-DCMAKE_DISABLE_FIND_PACKAGE_PkgConfig=TRUE \
		-DCMAKE_C_COMPILER=$(CC) \
		-DCMAKE_CXX_COMPILER=$(CXX) \
		-DCMAKE_RC_COMPILER=$(WINDRES) \
		-DCMAKE_BUILD_TYPE=Release \
		-DJPEGXL_ENABLE_OPENEXR=FALSE \
		-DJPEGXL_ENABLE_TOOLS=FALSE \
		-DJPEGXL_ENABLE_BENCHMARK=FALSE \
		-DCMAKE_CXX_FLAGS="-DHWY_DISABLED_TARGETS=\"HWY_AVX2|HWY_AVX3\"" \
		-DJPEGXL_ENABLE_JNI=OFF \
		-DJPEGXL_ENABLE_MANPAGES=OFF \
		-DJPEGXL_BUNDLE_GFLAGS=ON \
		-DBUILD_TESTING=OFF \
		-DJPEGXL_ENABLE_TOOLS=OFF \
		-DJPEGXL_ENABLE_VIEWERS=OFF \
		.. && \
	ninja

$(ARCHIVE): $(BINARY_STRIPPED) $(EXTRA_DIST)
	@printf '\t%s %s\n' 7Z $@
	rm -f $(ARCHIVE)
	$(7Z) a $@ $^

$(BINARY_STRIPPED): $(BINARY)
	@printf '\t%s %s\n' STRIP $@
	$(STRIP) -o $@ $^

$(BINARY): $(OBJECTS) $(EXTERNAL_LIBS)
	@printf '\t%s %s\n' LNK $@
	$(CXX) $(CFLAGS) $(LDFLAGS) $(LDFLAGS_LIB) -o $@ $^ $(LDLIBS)

-include $(DEPENDENCIES)

#!/bin/sh

set -ex

clang++ \
  -D__DARWIN_UNIX03 \
  \
  -Wall \
  -Wno-long-long \
  -Wno-import \
  -Wno-format \
  -Wno-deprecated \
  -Wno-unused-variable \
  -Wno-unused-private-field \
  -Wno-unused-function \
  -Wno-invalid-offsetof \
  -Wno-int-conversion \
  -Wno-char-subscripts \
  \
  -DTAPI_SUPPORT \
  -D__LITTLE_ENDIAN__=1 \
  \
  -I../../../include \
  -I../../../include/foreign \
  -I../../../ld64/src \
  -I../../../ld64/src/abstraction \
  -I../../../ld64/src/3rd \
  -I../../../ld64/src/3rd/BlocksRuntime \
  -I../../../ld64/src/3rd/include \
  -I../../../ld64/src/ld \
  -I../../../ld64/src/ld/parsers \
  -I../../../ld64/src/ld/passes \
  \
  "-DPROGRAM_PREFIX=\"\"" \
  "${BUILD_PATH}/apple-libtapi/build/projects/libtapi/lib/Core/CMakeFiles/tapiCore.dir/FakeSymbols.cpp.o" \
  -Wl,--unresolved-symbols=ignore-in-object-files \
  -std=c++0x \
  \
  -isystem /usr/local/include \
  -isystem /usr/pkg/include \
  -isystem "${LD64_TARGET_BASE_PATH}/include" \
  \
  -DLD64_VERSION_NUM=530 \
  -fblocks \
  -pthread \
  \
  -Wl,-rpath "-Wl,${LD64_TARGET_BASE_PATH}/lib" \
  -Wl,--enable-new-dtags \
  -Wl,-rpath "-Wl,${LD64_TARGET_BASE_PATH}lib64" \
  -Wl,--enable-new-dtags \
  -Wl,-rpath "-Wl,${LD64_TARGET_BASE_PATH}/lib32" \
  -Wl,--enable-new-dtags \
  \
  -o ld \
  \
  ld-debugline.o \
  ld-InputFiles.o \
  ld-ld.o \
  ld-Options.o \
  ld-OutputFile.o \
  ld-Resolver.o \
  ld-Snapshot.o \
  ld-SymbolTable.o \
  ld-PlatformSupport.o \
  code-sign-blobs/ld-blob.o  \
  \
  -L/usr/local/lib \
  -L/usr/pkg/lib \
  "-L${LD64_TARGET_BASE_PATH}/lib" \
  \
  ../../../ld64/src/3rd/.libs/libhelper.a \
  ../../../ld64/src/3rd/BlocksRuntime/.libs/libBlocksRuntime.a \
  ../../../ld64/src/ld/parsers/.libs/libParsers.a \
  ../../../ld64/src/ld/passes/.libs/libPasses.a \
  \
  -ldl \
  -ltapi \
  -pthread \
  -static

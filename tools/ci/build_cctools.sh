#!/bin/sh

set -ex

cd cctools

LDFLAGS='-static' \
  CFLAGS="${COMPILER_FLAGS}" \
  CXXFLAGS="${COMPILER_FLAGS}" \
  ./configure \
  --prefix="${LD64_TARGET_BASE_PATH}" \
  --with-libtapi="${LD64_TARGET_BASE_PATH}"

make -j 2
cp "${GITHUB_WORKSPACE}/tools/ci/statically_link_ld64.sh" "${LD64_SOURCE_PATH}"
cd "${LD64_SOURCE_PATH}"
./statically_link_ld64.sh
strip ld
cd "${GITHUB_WORKSPACE}/cctools"
make install -j 2

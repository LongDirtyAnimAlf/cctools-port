#!/bin/sh

set -ex

function build_and_install_litapi {
  git clone https://github.com/tpoechtrager/apple-libtapi
  INSTALLPREFIX="${LD64_TARGET_BASE_PATH}" apple-libtapi/build.sh
  apple-libtapi/install.sh
  # remove shared libraries to make sure the static library is used
  rm ${LD64_TARGET_BASE_PATH}/lib/*.so*
}

function create_static_libtapi {
  mkdir tmp
  cp apple-libtapi/build/lib/*.a tmp
  # some object files are not packed into libraries
  cp apple-libtapi/build/projects/libtapi/tools/libtapi/CMakeFiles/libtapi.dir/*.o tmp
  # unpack existing static libraries to combine them into one
  find tmp/ -name '*.a' -exec ar x {} \;
  rm tmp/*.a
  mv *.o tmp
  # combine object files from existing static libraries and standalone object
  # files into one static library
  ar r "${LD64_TARGET_BASE_PATH}/lib/libtapi.a" tmp/*.o
}

mkdir "${BUILD_PATH}"
cd "${BUILD_PATH}"
build_and_install_litapi
create_static_libtapi
cd ..

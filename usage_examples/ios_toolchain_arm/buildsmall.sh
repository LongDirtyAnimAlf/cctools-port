#!/usr/bin/env bash

export LC_ALL=C
pushd "${0%/*}" &>/dev/null

PLATFORM=$(uname -s)
OPERATING_SYSTEM=$(uname -o || echo "-")

BASEARCH="armv7"

if [ $OPERATING_SYSTEM == "Android" ]; then
  export CC="clang -D__ANDROID_API__=26"
  export CXX="clang++ -D__ANDROID_API__=26"
fi

if [ -z "$LLVM_DSYMUTIL" ]; then
    LLVM_DSYMUTIL=llvm-dsymutil
fi

if [ -z "$JOBS" ]; then
    JOBS=$(nproc 2>/dev/null || ncpus 2>/dev/null || echo 1)
fi

set -e

function verbose_cmd
{
    echo "$@"
    eval "$@"
}

function extract()
{
    echo "extracting $(basename $1) ..."
    local tarflags="xf"

    case $1 in
        *.tar.xz)
            xz -dc $1 | tar $tarflags -
            ;;
        *.tar.gz)
            gunzip -dc $1 | tar $tarflags -
            ;;
        *.tar.bz2)
            bzip2 -dc $1 | tar $tarflags -
            ;;
        *)
            echo "unhandled archive type" 1>&2
            exit 1
            ;;
    esac
}

function git_clone_repository
{
    local url=$1
    local branch=$2
    local directory

    directory=$(basename $url)
    directory=${directory/\.git/}

    if [ -n "$CCTOOLS_IOS_DEV" ]; then
        rm -rf $directory
        cp -r $CCTOOLS_IOS_DEV/$directory .
        return
    fi

    if [ ! -d $directory ]; then
        local args=""
        test "$branch" = "master" && args="--depth 1"
        git clone $url $args
    fi

    pushd $directory &>/dev/null

    git reset --hard
    git clean -fdx
    git checkout $branch
    git pull origin $branch

    popd &>/dev/null
}


TRIPLE="arm-apple-darwin11"
TARGETDIR="$PWD/target"
SDKDIR="$TARGETDIR/SDK"

mkdir -p $TARGETDIR
mkdir -p $TARGETDIR/bin
mkdir -p $SDKDIR

pushd $SDKDIR &>/dev/null

SDK_VERSION="10.3"

SYSLIB=$(find $SDKDIR -name libSystem.dylib -o -name libSystem.tbd | head -n1)
if [ -z "$SYSLIB" ]; then
    echo "SDK should contain libSystem{.dylib,.tbd}" 1>&2
    exit 1
fi
WRAPPER_SDKDIR=$(echo iPhoneOS*sdk | head -n1)
if [ -z "$WRAPPER_SDKDIR" ]; then
    echo "broken SDK" 1>&2
    exit 1
fi
popd &>/dev/null

echo ""
echo "*** building cctools / ld64 ***"
echo ""

pushd ../../cctools &>/dev/null
# git clean -fdx &>/dev/null || true
popd &>/dev/null

pushd tmp &>/dev/null
mkdir -p cctools
pushd cctools &>/dev/null
../../../../cctools/configure --target=$TRIPLE --prefix=$TARGETDIR --with-libtapi=$TARGETDIR CFLAGS="-D_BSD_SOURCE"
# make clean && make -j$JOBS && make install
make -j$JOBS && make install
popd &>/dev/null
popd &>/dev/null

echo ""
echo "*** checking toolchain ***"
echo ""

export PATH=$TARGETDIR/bin:$PATH

echo "int main(){return 0;}" | $TRIPLE-clang -xc -O2 -o test - 1>/dev/null || exit 1
rm test
echo "OK"

echo ""
echo "*** all done ***"
echo ""
echo "do not forget to add $TARGETDIR/bin to your PATH variable"
echo ""


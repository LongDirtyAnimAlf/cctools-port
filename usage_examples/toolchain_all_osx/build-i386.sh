#!/usr/bin/env bash

export LC_ALL=C
pushd "${0%/*}" &>/dev/null

PLATFORM=$(uname -s)
OPERATING_SYSTEM=$(uname -o || echo "-")

SDK_VERSION="10.13"
MIN_SDK_VERSION="10.8"
BASEARCH="i386"
BASEOS="MacOSX"

if [ $OPERATING_SYSTEM == "Android" ]; then
  export CC="clang -D__ANDROID_API__=26"
  export CXX="clang++ -D__ANDROID_API__=26"
fi

GNUMAKE="make"
if [ $OPERATING_SYSTEM == "FreeBSD" ] || [ $OPERATING_SYSTEM == "OpenBSD" ] || [ $OPERATING_SYSTEM == "NetBSD" ] || [ $OPERATING_SYSTEM == "Solaris" ]; then
  GNUMAKE="gmake"
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


TRIPLE="$BASEARCH-apple-darwin19"
TARGETDIR="$PWD/target"
SDKDIR="$TARGETDIR/SDK"

PATCH_DIR=$PWD/../../patches

mkdir -p $TARGETDIR
mkdir -p $TARGETDIR/bin
mkdir -p $SDKDIR

echo ""
echo "*** checking SDK ***"
echo ""

pushd $SDKDIR &>/dev/null

SYSLIB=$(find $SDKDIR -name libSystem.dylib -o -name libSystem.tbd | head -n1)
if [ -z "$SYSLIB" ]; then
    echo "SDK should contain libSystem{.dylib,.tbd}" 1>&2
    exit 1
fi
WRAPPER_SDKDIR=$(echo $BASEOS*sdk | head -n1)
if [ -z "$WRAPPER_SDKDIR" ]; then
    echo "broken SDK" 1>&2
    exit 1
fi
popd &>/dev/null

echo ""
echo "*** building wrapper ***"
echo ""

OK=0

set +e
which $LLVM_DSYMUTIL &>/dev/null
if [ $? -eq 0 ]; then
    case $($LLVM_DSYMUTIL --version | \
           grep "LLVM version" | head -1 | awk '{print $3}') in
        3.8*|3.9*|4.0*|5.0*|6.0*|7.0*|8.0*|9.0*) OK=1 ;;
    esac
fi
set -e

if [ $OK -eq 1 ]; then
    ln -sf $(which $LLVM_DSYMUTIL) $TARGETDIR/bin/dsymutil
    pushd $TARGETDIR/bin &>/dev/null
    ln -sf $TRIPLE-lipo lipo
    popd &>/dev/null
elif ! which dsymutil &>/dev/null; then
    echo "int main(){return 0;}" | cc -xc -O2 -o $TARGETDIR/bin/dsymutil -
fi

verbose_cmd cc -O2 -Wall -Wextra -Wno-format-truncation -pedantic wrapper-clang.c \
    -DSDK_DIR=\"\\\"$WRAPPER_SDKDIR\\\"\" \
    -DTARGET_CPU=\"\\\"$BASEARCH\\\"\" \
    -DOS_VER_MIN=\"\\\"$MIN_SDK_VERSION\\\"\" \
    -o $TARGETDIR/bin/$TRIPLE-clang

verbose_cmd cc -O2 -Wall -Wextra -Wno-format-truncation -pedantic wrapper-ld.c -o $TARGETDIR/bin/$TRIPLE-ld

pushd $TARGETDIR/bin &>/dev/null
verbose_cmd ln -sf $TRIPLE-clang $TRIPLE-clang++
popd &>/dev/null

echo ""
echo "*** building cctools / ld64 ***"
echo ""

pushd ../../cctools &>/dev/null
# git clean -fdx &>/dev/null || true
# patch -p1 < $PATCH_DIR/cctools.patch
popd &>/dev/null

pushd tmp &>/dev/null
mkdir -p cctools
pushd cctools &>/dev/null
../../../../cctools/configure --target=$TRIPLE --prefix=$TARGETDIR --with-libtapi=$TARGETDIR CFLAGS="-D_GNU_SOURCE -fcommon"
# $GNUMAKE clean && $GNUMAKE -j$JOBS && $GNUMAKE install
$GNUMAKE -j$JOBS && $GNUMAKE install
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


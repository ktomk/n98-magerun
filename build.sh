#!/bin/bash
#
# build from clean checkout
#
set -euo pipefail
IFS=$'\n\t'

name="$(awk '/<project name="([^"]*)"/ && !done {print gensub(/<project name="([^"]*)".*/, "\\1", "g"); done=1}' build.xml
)"
phar="${name}.phar"

echo "Building ${phar}..."

echo "$0 executed in $(pwd -P)"

build_dir="build/output"

if [ -d "${build_dir}" ]; then
    rm -rf "${build_dir}"
fi
if [ -d "${build_dir}" ]; then
    echo "Can not remove build-dir '${build_dir}'"
fi
mkdir "${build_dir}"
if [ ! -d "${build_dir}" ]; then
    echo "Can not create build-dir '${build_dir}'"
    echo "aborting."
    exit 1
fi

git clone --no-local -- . "${build_dir}"

composer="${build_dir}/composer.phar"

if [ -e "${composer}" ]; then
    rm "${composer}"
fi

# Set COMPOSER_HOME if HOME and COMPOSER_HOME not set (shell with no home-dir, e.g. build server with webhook)
if [ -z ${HOME+x} ]; then
    if [ -z ${COMPOSER_HOME+x} ]; then
        mkdir -p "build/composer-home"
        export COMPOSER_HOME="$(pwd -P)/build/composer-home"
    fi
fi

if [ ! -e "${composer}" ]; then
    echo "Downloading composer.phar..."
    if wget -O "${composer}" https://getcomposer.org/download/1.1.3/composer.phar; then
        chmod +x "${composer}"
    else
        echo "No conectivity, using standard version."
        if [ "$(type -p composer.phar)" != "" ]; then
            composer="$(type -p composer.phar)"
        elif [ "$(type -p composer)" != "" ]; then
            composer="$(type -p composer)"
        else
            echo >&2 "unable to locate composer"
            exit 1
        fi
        echo "composer is: ${composer}"
    fi
fi

"${composer}" --version
php --version

if ! "${composer}" -d="${build_dir}" --profile -q install --no-dev --no-interaction; then
    echo "failed to install from composer.lock, installing without lockfile now"
    rm "${build_dir}"/composer.lock
    "${composer}" -d="${build_dir}" --profile -q install --no-dev --no-interaction
fi

"${composer}" -d="${build_dir}"/build --profile -q install --no-interaction

if [ -e "${phar}" ]; then
    echo "Remove earlier created ${phar} file"
    rm "${phar}"
fi

cd "${build_dir}"

echo "building in $(pwd -P)"
git  --no-pager log --oneline -1

echo "setting ulimits (new setting is to $(ulimit -Hn))..."
ulimit -Sn $(ulimit -Hn)

echo "invoking phing dist_clean target..."
set +e
php -f build/vendor/phing/phing/bin/phing -dphar.readonly=0 -- -verbose dist_clean
BUILD_STATUS=$?
set -e
if [ ${BUILD_STATUS} -ne 0 ]; then
    >&2 echo "error: phing build failed with exit status ${BUILD_STATUS}"
    exit ${BUILD_STATUS}
fi

php -f build/phar/phar-timestamp.php

php -f "${phar}" -- --version

ls -al "${phar}"

php -r 'echo "SHA1: ", sha1_file("'"${phar}"'"), "\nMD5.: ", md5_file("'"${phar}"'"), "\n";'

cd -

cp -vip "${build_dir}"/"${phar}" "${phar}"

rm -rf "${build_dir}"

echo "done."

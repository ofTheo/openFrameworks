#!/bin/bash
set -ev
pwd
OF_ROOT=/home/actions/temp/arm-runner/mnt/openFrameworks
PROJECTS=$OF_ROOT/libs/openFrameworksCompiled/project
# source $OF_ROOT/scripts/ci/ccache.sh

# Add compiler flag to reduce memory usage to enable builds to complete
# see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=56746#c7
# the "proper" way does not work currently:
export CXXFLAGS="${CXXFLAGS} -ftrack-macro-expansion=0"

echo "**** Building OF core ****"
cd $OF_ROOT
# this carries over to subsequent compilations of examples
sed -i "s/PLATFORM_OPTIMIZATION_CFLAGS_DEBUG = .*/PLATFORM_OPTIMIZATION_CFLAGS_DEBUG = -g0/" $PROJECTS/makefileCommon/config.linux.common.mk
cd $PROJECTS
make Debug -j2

echo "**** Building emptyExample ****"
cd $OF_ROOT/scripts/templates/linuxarmv6l
make Debug -j2

echo "**** Building allAddonsExample ****"
cd $OF_ROOT
cp scripts/templates/linuxarmv6l/Makefile examples/templates/allAddonsExample/
cp scripts/templates/linuxarmv6l/config.make examples/templates/allAddonsExample/
cd examples/templates/allAddonsExample/
make Debug -j2

git checkout $PROJECTS/makefileCommon/config.linux.common.mk
git checkout $PROJECTS/linuxarmv6l/config.linuxarmv6l.default.mk

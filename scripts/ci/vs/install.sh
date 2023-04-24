OF_ROOT=$PWD

SCRIPT_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$SCRIPT_DIR" ]]; then SCRIPT_DIR="$PWD"; fi
. "$SCRIPT_DIR/../../dev/downloader.sh"

${OF_ROOT}/scripts/vs/download_libs.sh -p vs --silent

cd ~/
rm -rf projectGenerator
mkdir -p ~/projectGenerator
cd ~/projectGenerator

echo "Downloading projectGenerator from ci server"
downloader http://ci.openframeworks.cc/projectGenerator/projectGenerator-vs.zip 2> /dev/null
unzip projectGenerator-vs.zip 2> /dev/null
rm projectGenerator-vs.zip

cd $OF_ROOT
~/projectGenerator/projectGenerator.exe -o./ examples/templates/emptyExample
~/projectGenerator/projectGenerator.exe -o./ examples/templates/allAddonsExample

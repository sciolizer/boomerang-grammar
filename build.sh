#!/usr/bin/env sh

set -ev

rm -rf js-src js-test
node -harmony `which lsc` -bc -o js-src src
node -harmony `which lsc` -bc -o js-test test
mocha --harmony --colors --reporter spec js-test

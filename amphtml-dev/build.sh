#!/bin/sh

cd /home/

git clone https://github.com/ecoron/amphtml.git --branch master

cd /home/amphtml

mkdir node_modules
npm install

npm install gulp
gulp
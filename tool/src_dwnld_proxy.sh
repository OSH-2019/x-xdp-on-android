#!/bin/sh

if [ $# -lt 2 ];
then
    echo "Usage: ./src_dwnld <proxy_port>"
    exit 0
fi

proxy_port=$1
proxy="127.0.0.1:${proxy_port}"

export http_proxy=$proxy
export https_proxy=$proxy

repo init -u http://scm.osdn.net/gitroot/android-x86/manifest -b oreo-x86
repo sync --no-tags --no-clone-bundle

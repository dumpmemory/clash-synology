#!/bin/bash

get_latest_release() {
	curl --silent "https://github.com/Dreamacro/clash/releases/tag/premium" |
	grep '  <title>Release Premium ' |
	sed -E 's/[^.^0-9]//g'
}

latest_release_tag=`get_latest_release`
arch=`uname -m`
[ $arch == 'x86_64' ] && board_id='amd64';
[ $arch == 'aarch64' ] && board_id='armv8';
[ $arch == 'armv7' ] && board_id='armv7';
[ $arch == 'armv5' ] && board_id='armv5';

wget -q https://github.com/Dreamacro/clash/releases/download/premium/clash-linux-$board_id-$latest_release_tag.gz
gzip -d clash-linux-$board_id-$latest_release_tag.gz
chmod +x clash-linux-$board_id-$latest_release_tag
mv clash-linux-$board_id-$latest_release_tag /usr/bin/clash

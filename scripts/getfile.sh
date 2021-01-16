#!/bin/sh

getfile() {
	local FN="$1"
	local HASH="$2"

	# get file, check hash
	if [ -f "$FN" ]; then
		echo -n "Checking hash for $FN ..."
		local LH="$(sha256sum -b "$FN" | awk '{ print $1 }')"
		if [ x"$LH" = x"$HASH" ]; then
			echo "OK"
			return
		fi

		# not good
		echo "BAD, download..."
		rm -f "$FN"
	fi

	# TODO find a way to urlencode filename?
	local INFO="$(curl -s "${API_PREFIX}Shell/Bit:get?filename=${FN}&hash=${HASH}")"
	local URL="$(echo "$INFO" | jq -r .data.Url -)"

	echo "Downloading $FN ..."
	curl -# -L -o "$FN" "$URL"

	echo -n "Checking hash for $FN ..."
	local LH="$(sha256sum -b "$FN" | awk '{ print $1 }')"
	if [ x"$LH" = x"$HASH" ]; then
		echo "OK"
		return
	fi

	echo "BAD"
	echo "There was an issue downloading ${FN} or the data was corrupt, please make sure you are using the latest version"
	exit 1
}

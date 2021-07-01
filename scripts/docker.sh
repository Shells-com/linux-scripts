#!/bin/sh

# docker stuff
# we use docker to grab minimal images of distributions in order to build base images

docker_get() {
	# $1 $2
	# for example: docker_get fedora 33
	local NAME_SAN=`echo "$1" | sed -e 's#/#_#g'`

	if [ -f "docker_${NAME_SAN}_$2.tar.xz" ]; then
		return
	fi

	echo "Grabbing $1:$2 from docker..."
	docker pull "$1:$2"

	echo "Extracting..."
	DOCKERTMP="docker$$"
	mkdir "$DOCKERTMP"
	docker save "$1:$2" | tar -xC "$DOCKERTMP"
	local LAYER="$(find "$DOCKERTMP" -mindepth 1 -type d \! -name 'lost+found')"
	if [ $(echo "$LAYER" | wc -l) -eq 1 ]; then
		# all good
		mv "$LAYER/layer.tar" "docker_${NAME_SAN}_$2.tar"
		rm -fr "$DOCKERTMP"
		xz -z -9 -T 16 -v "docker_${NAME_SAN}_$2.tar"
	else
		rm -fr "$DOCKERTMP"
		echo "Failed to extract: image contains more than one layer"
		exit 1
	fi
}

docker_prepare() {
	# $1 $2
	# for example: docker_prepare fedora 33
	docker_get "$@"

	local NAME_SAN=`echo "$1" | sed -e 's#/#_#g'`
	prepare "docker_${NAME_SAN}_$2.tar.xz"
}

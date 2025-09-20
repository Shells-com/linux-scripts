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
	# Create a throwaway container and export its merged rootfs
	cid=$(docker create --platform=linux/amd64 "$1:$2")
	docker export "$cid" -o "docker_${NAME_SAN}_$2.tar"
	docker rm "$cid"

	xz -z -9 -T 16 -v "docker_${NAME_SAN}_$2.tar"
}

docker_prepare() {
	# $1 $2
	# for example: docker_prepare fedora 33
	docker_get "$@"

	local NAME_SAN=`echo "$1" | sed -e 's#/#_#g'`
	prepare "docker_${NAME_SAN}_$2.tar.xz"
}

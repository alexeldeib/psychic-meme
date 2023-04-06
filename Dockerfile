# Fix bugs in distroless busybox; simple `ls` doesn't work.
FROM ubuntu:22.04
RUN apt-get update && apt-get install -yq curl

COPY start.sh /start.sh

COPY dist/. /
COPY output/images/vmlinux /vmlinux
COPY output/images/rootfs.ext4 /rootfs.ext4

ENTRYPOINT ["/start.sh"]


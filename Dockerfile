# Fix bugs in distroless busybox; simple `ls` doesn't work.
FROM alpine:3
RUN apk --update add curl

COPY start.sh /start.sh

COPY dist/. /
COPY output/images/vmlinux /vmlinux
COPY output/images/rootfs.ext4 /rootfs.ext4

ENTRYPOINT ["/start.sh"]


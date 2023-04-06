# Fix bugs in distroless busybox; simple `ls` doesn't work.
FROM amd64/busybox:uclibc as busybox
FROM gcr.io/distroless/cc:debug
COPY --from=busybox /bin/busybox /busybox/busybox
RUN ["/busybox/busybox", "--install", "/bin"]

COPY ./dist /dist

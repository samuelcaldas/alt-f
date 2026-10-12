FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Sao_Paulo \
    TERM=xterm \
    HOME=/tmp

RUN apt-get update && apt-get install -y --no-install-recommends \
        autoconf automake bc bison build-essential ca-certificates cpio cvs \
        file flex gawk genext2fs gettext git gzip intltool make mtd-utils patch perl \
        pkg-config python3 python-is-python3 python3-distutils python3-dev rsync subversion tar texinfo unzip \
        wget xz-utils libncurses-dev libssl-dev libtool-bin zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && printf '#!/bin/sh\nexec /usr/bin/gawk -c "$@"\n' > /usr/local/bin/gawk \
    && chmod +x /usr/local/bin/gawk \
    && ln -s /usr/local/bin/gawk /usr/local/bin/awk \
    && ln -sf /usr/share/bison/skeletons/* /usr/share/bison/ \
    && ln -sf /usr/bin/rename.ul /usr/local/bin/rename

COPY source.tar /firmware-input/source.tar
COPY firmware-run.sh /usr/local/bin/firmware-run.sh

ENTRYPOINT ["/bin/bash", "/usr/local/bin/firmware-run.sh"]

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Sao_Paulo \
    HOME=/tmp

RUN apt-get update && apt-get install -y --no-install-recommends \
        bc bison build-essential ca-certificates cpio diffutils file flex \
        gawk gcc g++ git gzip make patch perl python3 python-is-python3 rsync sed tar unzip \
        wget xz-utils libncurses-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY run-toolchain.sh /toolchain-build/run-toolchain.sh
COPY m4-glibc-sigstksz.patch /toolchain-build/m4-glibc-sigstksz.patch
COPY mktc.sh /workspace/mktc.sh
COPY local/buildroot-2019.02.8.config /workspace/local/buildroot-2019.02.8.config
COPY local/uclibc-1.0.31.config /workspace/local/uclibc-1.0.31.config

RUN mkdir -p /workspace/local /out/build/dl \
    && touch /workspace/.config \
    && ln -s /out/build/dl /workspace/dl

ENTRYPOINT ["/bin/bash", "/toolchain-build/run-toolchain.sh"]

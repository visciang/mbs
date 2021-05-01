FROM gcc:10.2.0

RUN wget https://github.com/Kitware/CMake/releases/download/v3.19.6/cmake-3.19.6-Linux-x86_64.sh \
      -q -O /tmp/cmake-install.sh \
      && chmod u+x /tmp/cmake-install.sh \
      && mkdir /usr/bin/cmake \
      && /tmp/cmake-install.sh --skip-license --prefix=/usr/bin/cmake \
      && rm /tmp/cmake-install.sh

ADD toolchain.sh /toolchain.sh

ENV PATH="/usr/bin/cmake/bin:${PATH}"

ENTRYPOINT [ "/toolchain.sh" ]

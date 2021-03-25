FROM python:3.9.2-slim

RUN pip install build
ADD build.sh /toolchain/build.sh

ENTRYPOINT [ "/toolchain/build.sh" ]
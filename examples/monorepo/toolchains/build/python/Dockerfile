FROM python:3.9.2-slim

RUN pip install build
ADD toolchain.sh /toolchain.sh

ENTRYPOINT [ "/toolchain.sh" ]
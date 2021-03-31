FROM amazon/aws-cli:2.1.32
RUN yum install -y util-linux
ADD toolchain.sh /toolchain.sh
ENTRYPOINT [ "/toolchain.sh" ]

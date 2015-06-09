FROM cloudrouter/base-centos:latest
MAINTAINER "Arun Neelicattu" <arun.neelicattu@gmail.com>

ENV WORKSPACE /workspace
ENV SOURCES /sources
ENV OUTPUT /sources

RUN yum -y upgrade
RUN yum -y install rpm-build rpmdevtools yum-utils

RUN yum -y install epel-release

RUN rm -rf /root/rpmbuild
RUN ln -sf /root/rpmbuild ${RPM_BUILD_DIR}

RUN mkdir -p ${SOURCES} \
    ${WORKSPACE} \
    ${OUTPUT} \
    ${RPM_BUILD_DIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

VOLUME [${SOURCES}, ${TARGET}, ${WORKSPACE}, ${RPM_BUILD_DIR}]

ADD ./assets/build /usr/bin/build

CMD ["build"]

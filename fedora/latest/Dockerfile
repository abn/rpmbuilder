FROM fedora:latest
MAINTAINER "Arun Neelicattu" <arun.neelicattu@gmail.com>

ENV WORKSPACE /workspace
ENV SOURCES /sources
ENV OUTPUT /output

RUN dnf -y upgrade
RUN dnf -y install rpm-build rpmdevtools yum-utils
RUN dnf -y clean all

ENV RPM_BUILD_DIR /rpmbuild
RUN ln -sf ${RPM_BUILD_DIR} /root/rpmbuild

RUN mkdir -p ${SOURCES} \
    ${WORKSPACE} \
    ${OUTPUT} \
    ${RPM_BUILD_DIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

VOLUME [${SOURCES}, ${OUTPUT}, ${WORKSPACE}, ${RPM_BUILD_DIR}]

ADD ./assets/build /usr/bin/build

CMD ["build"]

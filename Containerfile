ARG BASE_IMAGE=fedora
FROM ${BASE_IMAGE}

ARG EXTRA_PACKAGES=""
ENV EXTRA_PACKAGES=${EXTRA_PACKAGES}

ENV SOURCES=/sources
ENV OUTPUT=/output

COPY ./bin/configure.sh /usr/bin/rpmbuilder-configure
RUN rpmbuilder-configure

COPY ./rpmbuilder.sh /usr/bin/rpmbuilder

VOLUME ${SOURCES}
VOLUME ${OUTPUT}

CMD /usr/bin/rpmbuilder

ARG ALPINE_VERSION=3.24

FROM alpine:${ALPINE_VERSION} AS build

ARG ALPINE_VERSION
ARG DISABLE_UI_BUILD
ARG REPOSITORY_URL=https://github.com/owntone/owntone-server.git
ARG REPOSITORY_BRANCH=master
ARG REPOSITORY_COMMIT
ARG REPOSITORY_VERSION

WORKDIR /tmp/source

RUN \
  apk add -U -q --no-cache --no-progress \
    alsa-lib-dev \
    autoconf \
    automake \
    avahi-dev \
    bison \
    confuse-dev \
    curl-dev \
    ffmpeg-dev \
    flex \
    g++ \
    gawk \
    gcc \
    gettext-dev \
    git \
    gnutls-dev \
    gperf \
    json-c-dev \
    libevent-dev \
    libgcrypt-dev \
    libplist-dev \
    libsodium-dev \
    libtool \
    libunistring-dev \
    libwebsockets-dev \
    libxml2-dev \
    make \
    npm \
    protobuf-c-dev \
    sqlite-dev && \
  git clone -b ${REPOSITORY_BRANCH} ${REPOSITORY_URL} ./ && \
  if [ ${REPOSITORY_COMMIT} ]; then git checkout ${REPOSITORY_COMMIT}; \
  elif [ ${REPOSITORY_VERSION} ]; then git checkout tags/${REPOSITORY_VERSION}; fi && \
  if [ -z ${DISABLE_UI_BUILD} ]; then cd web-src; npm install; npm run build; cd ..; fi && \
  autoreconf -fvi -I /usr/share/gettext/m4 && \
  ./configure \
    --disable-install_systemd \
    --disable-install_user \
    --enable-chromecast \
    --enable-silent-rules \
    --infodir=/usr/share/info \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --prefix=/usr \
    --sysconfdir=/etc/owntone && \
  make DESTDIR=/tmp/build install && \
  cd /tmp/build && \
  install -D etc/owntone/owntone.conf usr/share/doc/owntone/examples/owntone.conf && \
  rm -rf var etc

FROM alpine:${ALPINE_VERSION} AS runtime

ARG ALPINE_VERSION
ARG UID=1000 
ENV LOG_LEVEL=1

COPY --from=build /tmp/build/ .
RUN \
  apk add -U -q --no-cache --no-progress \
    avahi \
    confuse \
    curl \
    dbus \
    ffmpeg \
    gnutls \
    json-c \
    libevent \
    libgcrypt \
    libplist \
    libsodium \
    libunistring \
    libuuid \
    libwebsockets \
    libxml2 \
    nss_wrapper \
    protobuf-c \
    shadow \
    sqlite \
    sqlite-libs \
    tini && \
  rm /etc/avahi/services/* &&\
  sed -i \
    -e 's|\(.*\)\(db_path = "\).\+\(".*\)|\t\2/var/cache/owntone/database.db\3|' \
    -e 's|\(.*\)\(db_backup_path = "\).\+\(".*\)|\t\2/var/cache/owntone/database.bak\3|' \
    -e 's|\(.*\)\(cache_path = "\).\+\(".*\)|\t\2/var/cache/owntone/cache.db\3|' \
    -e 's|\(.*\)\(logfile = "\).\+\(".*\)|\t\2/dev/stderr\3|' \
    -e 's|\(.*\)\(directories = { \).\+\( }.*\)|\t\2"/srv/media"\3|' \
    -e 's|\(.*\)\(trusted_networks = { \).\+\( }.*\)|\t\2"any"\3|' \
    /usr/share/doc/owntone/examples/owntone.conf && \
    adduser -DH -u ${UID} -g owntone -h /tmp -s /sbin/nologin owntone && \
    chmod u+s /usr/sbin/avahi-daemon /usr/sbin/avahi-dnsconfd && \
    chmod 1777 /run

COPY --chmod=755 entrypoint.sh /usr/local/bin/
COPY dbus-local.conf /etc/dbus-1/

USER $UID
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
  CMD ["/usr/bin/curl", "http://localhost:3689"]

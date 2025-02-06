ARG PACKAGE_REPOSITORY_URL=https://dl-cdn.alpinelinux.org/alpine/v3.19

FROM alpine:3.21 AS build

ARG DISABLE_UI_BUILD
ARG PACKAGE_REPOSITORY_URL
ARG REPOSITORY_URL=https://github.com/owntone/owntone-server.git
ARG REPOSITORY_BRANCH=master
ARG REPOSITORY_COMMIT
ARG REPOSITORY_VERSION

WORKDIR /tmp/source

RUN \
  apk add -U -q --no-cache --no-progress --repository ${PACKAGE_REPOSITORY_URL} \
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
  autoreconf -i && \
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

FROM alpine:3.21 AS runtime

ARG PACKAGE_REPOSITORY_URL

COPY --from=build /tmp/build/ .
COPY --chmod=755 /etc/init.d/* /etc/init.d/

RUN \
  apk add -U -q --no-cache --no-progress --repository ${PACKAGE_REPOSITORY_URL} \
    avahi \
    busybox-openrc \
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
    openrc \
    protobuf-c \
    shadow \
    sqlite \
    sqlite-libs \
    udev-init-scripts-openrc && \
  rm /etc/avahi/services/* &&\
  sed -i \
    -e 's|\(.*\)\(db_path = "\).\+\(".*\)|\t\2/var/cache/owntone/database.db\3|' \
    -e 's|\(.*\)\(db_backup_path = "\).\+\(".*\)|\t\2/var/cache/owntone/database.bak\3|' \
    -e 's|\(.*\)\(cache_path = "\).\+\(".*\)|\t\2/var/cache/owntone/cache.db\3|' \
    -e 's|\(.*\)\(logfile = "\).\+\(".*\)|\t\2/dev/stderr\3|' \
    -e 's|\(.*\)\(directories = { \).\+\( }.*\)|\t\2"/srv/media"\3|' \
    -e 's|\(.*\)\(trusted_networks = { \).\+\( }.*\)|\t\2"any"\3|' \
    /usr/share/doc/owntone/examples/owntone.conf && \
  sed -i 's/^\(tty\d\:\:\)/#\1/g' /etc/inittab && \
  sed -i \
    -e 's/#rc_env_allow=".*"/rc_env_allow="UID GID"/g' \
    -e 's/#rc_provide=".*"/rc_provide="loopback net"/g' \
    -e 's/#rc_sys=".*"/rc_sys="docker"/g' \
    /etc/rc.conf && \
  rc-update add syslog boot && \
  rc-update add owntone default && \
  install -D /dev/null /run/openrc/softlevel

ENTRYPOINT ["/sbin/init"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 \
  CMD ["/sbin/rc-service", "owntone", "status"]

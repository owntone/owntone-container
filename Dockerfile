ARG PACKAGE_REPOSITORY_URL=https://dl-cdn.alpinelinux.org/alpine/v3.18

FROM alpine:3.18 AS build

ARG PACKAGE_REPOSITORY_URL
ARG REPOSITORY_URL=https://github.com/owntone/owntone-server.git
ARG REPOSITORY_BRANCH=master
ARG REPOSITORY_COMMIT
ARG REPOSITORY_TAG

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
    make \
    mxml-dev \
    npm \
    protobuf-c-dev \
    sqlite-dev && \
  git clone -b ${REPOSITORY_BRANCH} ${REPOSITORY_URL} ./ && \
  if [ ${COMMIT} ]; then git checkout ${COMMIT}; \
  elif [ ${TAG} ]; then git checkout tags/${TAG}; fi && \
  cd web-src && \
  npm update -s --no-progress && \
  npm run -s build -- -l silent && \
  cd .. && \
  autoreconf -i && \
  ./configure \
    -q \
    --disable-install_systemd \
    --disable-install_user \
    --enable-chromecast \
    --enable-silent-rules \
    --infodir=/usr/share/info \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --prefix=/usr \
    --sysconfdir=/etc/owntone && \
  make -s DESTDIR=/tmp/build install && \
  cd /tmp/build && \
  install -D etc/owntone/owntone.conf usr/share/doc/owntone/examples/owntone.conf && \
  rm -rf var etc

FROM alpine:3.18 AS runtime

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
    mxml \
    openrc \
    protobuf-c \
    shadow \
    sqlite \
    sqlite-libs \
    udev-init-scripts-openrc && \
  rm /etc/avahi/services/* &&\
  sed -i \
    -e 's/\/srv\/music/\/srv\/media/g' \
    -e 's/\/var\/log/\/var\/log\/owntone/g' \
    -e 's/^#.*trusted_networks/\ttrusted_networks = { "any" }/g' \
    /usr/share/doc/owntone/examples/owntone.conf && \
  sed -i 's/^\(tty\d\:\:\)/#\1/g' /etc/inittab && \
  sed -i \
    -e 's/#rc_env_allow=".*"/rc_env_allow="UID GID"/g' \
    -e 's/#rc_provide=".*"/rc_provide="loopback net"/g' \
    -e 's/#rc_sys=".*"/rc_sys="docker"/g' \
    /etc/rc.conf && \
  rc-update add syslog boot && \
  rc-update add owntone boot && \
  install -D /dev/null /run/openrc/softlevel

ENTRYPOINT ["/sbin/init"]

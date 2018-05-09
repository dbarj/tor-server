# Dockerfile for Tor Relay Server with obfs4proxy
#
# TODO:
# - add IPv6

FROM debian:stretch-slim
MAINTAINER Christian chriswayg@gmail.com

# If no Nickname is set, a random string will be added to 'Tor4'
ENV TOR_NICKNAME=Tor4 \
    TERM=xterm

# Install prerequisites
RUN apt-get update &&  \
	DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y \
      apt-transport-https \
      ca-certificates \
      dirmngr \
      apt-utils \
      pwgen \
      gnupg && \
  # Add torproject.org Debian repository, which will always install the latest stable version
	GPGKEY=A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89; \
	found=''; \
	for server in \
  		ha.pool.sks-keyservers.net \
  		hkp://keyserver.ubuntu.com:80 \
  		hkp://p80.pool.sks-keyservers.net:80 \
      ipv4.pool.sks-keyservers.net \
      keys.gnupg.net \
  		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPGKEY from $server"; \
		APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE="True" apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPGKEY" && exit 1; \
  apt-get clean && rm -rf /var/lib/apt/lists/* && \
  \
  echo "deb https://deb.torproject.org/torproject.org stretch main"   >  /etc/apt/sources.list.d/tor-apt-sources.list && \
  echo "deb-src https://deb.torproject.org/torproject.org stretch main" >> /etc/apt/sources.list.d/tor-apt-sources.list && \
  echo "deb http://deb.torproject.org/torproject.org obfs4proxy main" >> /etc/apt/sources.list.d/tor-apt-sources.list && \
# Install tor and obfs4proxy & backup torrc
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -y \
    tor \
    deb.torproject.org-keyring \
    obfs4proxy && \
  mv -v /etc/tor/torrc /etc/tor/torrc.default && \
  # Download GeoIP files
  cd /etc/tor && \
  apt-get -d source tor && \
  tar --strip-components=3 --wildcards -zxvf tor_*.orig.tar.gz tor-*/src/config/geoip && \
  tar --strip-components=3 --wildcards -zxvf tor_*.orig.tar.gz tor-*/src/config/geoip6 && \
  rm -v tor_* && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy Tor configuration file
COPY ./config/torrc /etc/tor/torrc

# Copy docker-entrypoint
COPY ./scripts/ /usr/local/bin/

# Persist data
VOLUME /etc/tor /var/lib/tor

# ORPort, DirPort, ObfsproxyPort
EXPOSE 9001 9030 54444

ENTRYPOINT ["docker-entrypoint"]

CMD ["tor", "-f", "/etc/tor/torrc"]

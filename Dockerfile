FROM alpine:latest

RUN set -xe \
    && apk add --no-cache --update sudo bash tzdata rsyslog logrotate\
    iptables iptables-legacy openssl strongswan xl2tpd

COPY settings/ipsec.docker.secrets /etc/ipsec.d/ipsec.docker/ipsec.docker.secrets

COPY scripts/init.sh /init.sh
RUN chmod 0755 /init.sh
RUN bash /init.sh

COPY settings/l2tp-ikev2.conf /etc/ipsec.d/ipsec.docker/l2tp-ikev2.conf

COPY settings/xl2tpd.conf /etc/xl2tpd/xl2tpd.conf

COPY settings/options.xl2tpd /etc/ppp/options.xl2tpd

COPY settings/10-charon-logging.conf /etc/strongswan.d/10-charon-logging.conf

RUN mkdir -p /etc/rsyslog.d
RUN mkdir -p /etc/logrotate.d
COPY settings/10-strongswan /etc/logrotate.d/10-strongswan
COPY settings/20-syslog /etc/logrotate.d/20-syslog

RUN rm -f /etc/logrotate.d/rsyslog

COPY scripts/trasher.sh /trasher.sh
RUN chmod 0755 /trasher.sh
RUN echo '0 0 * * * /trasher.sh' | crontab -
RUN echo "0 0 * * * /usr/sbin/logrotate /etc/logrotate.conf" | crontab -

COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh

RUN echo '%ipsec ALL=NOPASSWD:SETENV:/usr/sbin/ipsec' > /etc/sudoers.d/ipsec
RUN chmod 0440 /etc/sudoers.d/ipsec

VOLUME /etc/ipsec.d /etc/strongswan.d /var/log /etc/xl2tpd /etc/ppp

EXPOSE 500/udp 4500/udp 1701/udp

ENTRYPOINT ["/entrypoint.sh"]

FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y softhsm2 && \
    apt-get clean

ENV SOFTHSM2_CONF=/etc/softhsm/softhsm2.conf

VOLUME ["/var/lib/softhsm/tokens"]

CMD ["tail", "-f", "/dev/null"]

FROM ubuntu:focal as base
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
    && apt-get install -y --force-yes --no-install-recommends dpkg-dev nginx supervisor apt-transport-https lsb-release ca-certificates wget gnupg2 apt-rdepends dpkg-dev \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*


FROM base as downloader

# Download and add the NGINX signing key:
RUN wget https://cs.nginx.com/static/keys/nginx_signing.key && apt-key add nginx_signing.key

# Download and add the NGINX Security Updates signing key:
RUN wget https://cs.nginx.com/static/keys/app-protect-security-updates.key && apt-key add app-protect-security-updates.key

# Add NGINX Plus repository:
RUN printf "deb https://pkgs.nginx.com/plus/ubuntu `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-plus.list

# Add NGINX App-protect repository:
RUN printf "deb https://pkgs.nginx.com/app-protect/ubuntu `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/nginx-app-protect.list

# Add security updates repository
RUN printf "deb https://pkgs.nginx.com/app-protect-security-updates/ubuntu/ `lsb_release -cs` nginx-plus\n" | tee /etc/apt/sources.list.d/app-protect-security-updates.list

# Download the apt configuration to `/etc/apt/apt.conf.d`:
RUN wget -P /etc/apt/apt.conf.d https://cs.nginx.com/static/files/90pkgs-nginx

# Update the repository and install the most recent version of the NGINX App Protect WAF package (which includes NGINX Plus):
RUN --mount=type=secret,id=nginx-crt,dst=/etc/ssl/nginx/nginx-repo.crt,mode=0644 \
    --mount=type=secret,id=nginx-key,dst=/etc/ssl/nginx/nginx-repo.key,mode=0644 \
    apt-get update && \
    mkdir -p /etc/packages/ && \
    cd /etc/packages/ && \
    for i in $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances nginx-plus | grep "^\w" | sort -u); do apt-get download $i 2>>errors.txt; done && \
    for i in $(apt-cache depends --recurse --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances app-protect | grep "^\w" | sort -u); do apt-get download $i 2>>errors.txt; done && \
    apt-get download app-protect-attack-signatures app-protect-threat-campaigns


FROM downloader as final
COPY --from=downloader /etc/packages /data/ubuntu/dists/focal/nginx-plus/binary-amd64/
COPY --chmod=0755 generate-release.sh .

RUN cd /data/ubuntu && dpkg-scanpackages --arch amd64 . > dists/focal/nginx-plus/binary-amd64/Packages
RUN cd /data/ubuntu && cat dists/focal/nginx-plus/binary-amd64/Packages | gzip -9 > dists/focal/nginx-plus/binary-amd64/Packages.gz

RUN cd /data/ubuntu/dists/focal/nginx-plus/binary-amd64 && /generate-release.sh > Release

ADD supervisord.conf /etc/supervisor/
ADD nginx.conf /etc/nginx/sites-enabled/default
ADD startup.sh /

ENV DEBIAN_FRONTEND noninteractive
EXPOSE 80
ENTRYPOINT ["/startup.sh"]

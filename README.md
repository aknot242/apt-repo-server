APT-REPO-SERVER
=========================

apt-repo-server is a debian repository server specifically for Ubuntu 20.04 (focal). On container build, it creates the Release index file automatically.

This has been modified to collect NGINX packages using a certificate and key, then host them in a container acting as a repo for demo environment purposes.

Packages collected are:
- app-protect (and all immediate dependencies)
- app-protect-attack-signatures
- app-protect-threat-campaigns

Usage
=======================

Build container
```
git clone https://github.com/aknot242/apt-repo-server
cd apt-repo-server
cp <your nginx repo cert> nginx-repo.crt
cp <your nginx repo key> nginx-repo.key

DOCKER_BUILDKIT=1 docker build --no-cache --secret id=nginx-crt,src=nginx-repo.crt --secret id=nginx-key,src=nginx-repo.key -t aknot242/apt-repo-server .
```


Run server

```
docker run --restart unless-stopped -d -p 10000:80 aknot242/apt-repo-server

```

Test to make sure packages are serving

```
curl http://localhost:10000/
```

Update /etc/apt/sources.list
```
$ echo deb http://127.0.0.1:10000/ focal main | sudo tee -a /etc/apt/sources.list
```


License
==================

apt-repo is under the Apache 2.0 license. See the LICENSE file for details.

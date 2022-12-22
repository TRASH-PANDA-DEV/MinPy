ARG BASE_REGISTRY=registry.access.redhat.com
ARG BASE_IMAGE=ubi8/ubi
ARG BASE_TAG=8.7-1026

ARG FINAL_IMAGE=ubi8/ubi-minimal
ARG FINAL_TAG=8.7-923.1669829893

#pull firt stage
FROM ${BASE_REGISTRY}/${BASE_IMAGE}:${BASE_TAG} as build

#set the python version to download and install
ENV PYTHON_VERSION 3.11.0

WORKDIR /usr/tmp

#MOUNT THE FOLLOWING FOR DEVELOPMENR
#/usr/tmp

COPY pip.conf /etc/

#install make a dev tools
RUN set -eux && \
    dnf upgrade -y --nodocs && \
    dnf install -y --nodocs \ 
    wget \
    bzip2-devel \
    expat-devel \
    gcc \
    libuuid-devel \
    make \
    xz \
    wget \
    openssl-devel \
    sqlite-devel \
    xz-devel && \
    update-ca-trust force-enable; \
    dnf clean all && \
    rm -rf /var/cache/dnf

RUN wget -V

#get python
RUN set -eux; \
    wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz"

RUN mkdir python && \
    tar -xvf python.tar.xz -C /usr/tmp/python/ && \
    cd python/Python-$PYTHON_VERSION && \
    ./configure \
    --enable-loadable-sqlite-extensions \
    --enable-optimizations \
    --enable-option-checking=fatal \
    --with-system-expat \
    --with-ensurepip && \
    make -d -j$(nproc) && \
    make && \
    make install

RUN set -eux; \
    python3 -m ensurepip --upgrade

#If additional requirements are needed, use this
#COPY requirements.txt /usr/tmp/
#RUN python3 -m pip install -r requirements.txt

FROM ${BASE_REGISTRY}/${FINAL_IMAGE}:${FINAL_TAG}

RUN microdnf update -y --nodocs && \
    microdnf install glibc \
    shadow-utils.x86_64 && \
    microdnf clean all && \
    rm -rf /var/cache/dnf

ENV PATH /usr/local/bin:/home/python/.local/bin:$PATH

#USE SHORT VERSION SUCH AS 3.12 RATHER THAN 3.12.0
ENV PYTHON_VERSION 3.11

#fix links
RUN set -eux; \
    cd /usr/local/bin && \
    ln -s idle$PYTHON_VERSION idle3 && \
    ln -s idle3 idle && \
    ln -s pydoc$PYTHON_VERSION pydoc3 && \
    ln -s pydoc3 pydoc && \
    ln -s python$PYTHON_VERSION Python3 && \
    ln -s python3 python && \
    ln -s python$PYTHON_VERSION-config python3-config && \
    ln -s python3-config python-config && \
    ln -s easy_install-$PYTHON_VERSION easy-install-3 && \
    ln -s easy-install3 easy_install && \
    ln -s 2to3-$PYTHON_VERSION 2to3-3 && \
    ln -s 2to3-3 2to3 && \
    ln -s pip$PYTHON_VERSION pip3 || true && \ 
    ln -s pip3 pip || true && \
    echo '/usr/local/lib' > /etc/ld.so.conf && \
    ldconfig

COPY --from=build /usr/local/include/python$PYTHON_VERSION /usr/local/include/python$PYTHON_VERSION
COPY --from=build /usr/local/lib /usr/local/lib
COPY --from=build /usr/local/bin /usr/local/bin

COPY pip.conf /etc/

RUN groupadd -g 1001 python; \
    useradd -r -u 1001 -m -s /sbin/nologin -g python python

USER 1001

RUN microdnf remove shadow-utils.x86_64 -y; \
    microdnf clean all; \
    rm -rf /var/cache/dnf

CMD ["python"]
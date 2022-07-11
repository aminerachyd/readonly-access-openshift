## This Dockerfile creates an UBI image with oc, jq and helm

FROM registry.access.redhat.com/ubi8:8.6-855

USER root

WORKDIR /home/usr

ENV VERIFY_CHECKSUM false

RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN ARCH=$(uname -m) && OC_VERSION=4.8.0 &&\
    curl https://mirror.openshift.com/pub/openshift-v4/$ARCH/clients/ocp/$OC_VERSION/openshift-client-linux.tar.gz --output oc-client.tar.gz &&\
    tar -xzf oc-client.tar.gz &&\
    mv oc /usr/local/bin &&\
    mv kubectl /usr/local/bin &&\
    dnf install -y jq

COPY rhacm-policy rhacm-policy
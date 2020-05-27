FROM quay.io/openshift-release-dev/ocp-v4.0-art-dev

RUN yum install openldap-clients -y

COPY ./ad-sync.sh /opt/ad-sync.sh

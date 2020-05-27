FROM quay.io/openshift-pipeline/openshift-cli:v0.8.0

RUN yum install openldap-clients -y

COPY ./ad-sync.sh /opt/ad-sync.sh

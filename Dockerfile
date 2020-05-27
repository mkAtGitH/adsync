FROM registry.redhat.io/openshift4/ose-cli

RUN yum install openldap-clients -y

COPY ./ad-sync.sh /opt/ad-sync.sh

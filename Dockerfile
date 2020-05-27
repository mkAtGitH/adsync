FROM openshift/ose-cli

RUN yum install openldap-clients -y

COPY ./ad-sync.sh /opt/ad-sync.sh

FROM image-registry.openshift-image-registry.svc:5000/openshift/cli

RUN yum install openldap-clients -y

COPY ./ad-sync.sh /opt/ad-sync.sh

FROM default-route-openshift-image-registry.apps.cluster-p001.msp.upc.biz/openshift/cli

RUN yum install openldap-clients -y

COPY ./ad-sync.sh /opt/ad-sync.sh

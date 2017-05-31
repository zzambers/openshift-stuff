FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift
USER root
COPY deployments/* /deployments/
RUN ln -s /deployments/bin/thermostat-web-gateway.sh
/deployments/bin/run.sh
USER 1001

FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift

USER ROOT

COPY ./bin ./etc ./lib ./services /deploymnets
RUN ln /deployments/bin/thermostat-web-gateway.sh /deployments/bin/run.sh

USER 1001

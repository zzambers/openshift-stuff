# This image is used as builder image for thermostat-gateway.
# It builds image with artifacts, which are then extracted and put to
# the runtime image.

# since we are building java app, this image is based on openjdk image
FROM registry.access.redhat.com/redhat-openjdk-18/openjdk18-openshift

# copy helper-scripts to deployments, it is used in following step to prepare
# runtime image. For more info see: helper-scripts/runtime-image-prepare.sh
COPY helper-scripts /deployments/helper-scripts

# set environment variables, required by openjdk18-openshift image
# ( base image of this one ), to successfully copy built artifacts
# of thermostat-gateway to the right place ( /deployments )
ENV ARTIFACT_DIR=distribution ARTIFACT_COPY_ARGS="-r target/image/*"

# Thermostat + Wildfly Builder Image for OpenShift

This repository contains a sample Dockerfile for a builder
image which can be used as a drop-in replacement of the
[openshift/wildfly-101-centos7](https://github.com/openshift-s2i/s2i-wildfly)
image.

The difference between `openshift/wildfly-101-centos7` and this
image is that the result will be capable of optionally starting a
[Thermostat](http://icedtea.classpath.org/thermostat/) agent within
a deployment.

See [Thermostat on OpenShift Usage](https://github.com/jerboaa/thermostat-openshift)
for more details as to how to use the built image.

## Usage

In order to build the Wildfly Builder image execute the following:

    $ docker build -f Dockerfile -t thermostat/wildfly-101-rhel7 .

The resulting image can then be used to build your Wildfly app:

    $ s2i build file://$(pwd)/test/wildfly-testapp thermostat/wildfly-101-rhel7 wildfly-testapp

Then run the app as usual:

    $ docker run -p 8080:8080 -d wildfly-testapp

## Enabling the Thermostat Agent

In order to enable the Thermostat Agent for an app image certain environment variables
need to be set and a storage endpoint needs to be running for the Thermostat Agent to
connect to.

### Starting the Thermostat Storage Endpoint

We can use the `rhscl/thermostat-16-storage-rhel7` image for this. That image in turn
relies on a third image, `rhscl/mongodb-32-rhel7` for example, for its mongodb backend.

Let's start the mongodb image first:

    $ MONGO_CID=$(mktemp -u --suffix=.cid)
    $ docker run -d \
              -e MONGODB_USER=mongouser \
              -e MONGODB_PASSWORD=mongopassword \
              -e MONGODB_DATABASE=thermostat \
              -e MONGODB_ADMIN_PASSWORD=changeme123 \
              --cidfile=${MONGO_CID} \
              rhscl/mongodb-32-rhel7
    $ MONGO_IP=$( docker inspect --format '{{ .NetworkSettings.IPAddress }}' $(cat ${MONGO_CID}) )

Now start the Thermostat Storage Endpoint:

    $ TH_STORAGE_CID=$(mktemp -u --suffix=.cid)
    $ docker run -p 8081:8080 -d \
              -e MONGO_URL=mongodb://${MONGO_IP}:27017 \
              -e MONGO_USERNAME=mongouser \
              -e MONGO_PASSWORD=mongopassword \
              -e THERMOSTAT_AGENT_USERNAMES="agent1" \
              -e THERMOSTAT_AGENT_PASSWORDS="a_secrit1" \
              -e THERMOSTAT_CLIENT_USERNAMES="client1" \
              -e THERMOSTAT_CLIENT_PASSWORDS="c_secrit1" \
              --cidfile=${TH_STORAGE_CID} \
              rhscl/thermostat-16-storage-rhel7
    $ TH_STORAGE_IP=$( docker inspect --format '{{ .NetworkSettings.IPAddress }}' $(cat ${TH_STORAGE_CID}) )

### Start the Application with the Thermostat Agent

In the above `wildfly-testapp` application case this could be done
as follows:

    $ docker run -p 8080:8080 -p 12000:12000 \
       -e THERMOSTAT_AGENT_USERNAME=agent1 \
       -e THERMOSTAT_AGENT_PASSWORD=a_secrit1 \
       -e THERMOSTAT_DB_URL=http://${TH_STORAGE_IP}:8080/thermostat/storage \
       -d wildfly-testapp

## Disabling the Thermostat Agent

For a re-deployment of your application without a Thermostat Agent running
unsetting one of the 3 `THERMOSTAT_*` environment variables is sufficient.

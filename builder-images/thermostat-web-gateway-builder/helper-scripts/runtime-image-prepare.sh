#!/bin/sh

# backup original global-config.properties
mv /deployments/etc/global-config.properties /deployments/etc/global-config.properties.orig
# make global-config.properties symlink to /tmp
ln -s /tmp/global-config.properties /deployments/etc/global-config.properties

# create script which generates actual global-config.properties from original
# to temp and starts the gateway
cat > /deployments/bin/run.sh << "EOF"
#!/bin/bash

function setProperty {
	local file="$1"
	local property="$2"
	local value="$3"

	if cat "${file}" | grep -q "^[[:space:]]*${property}[[:space:]]*=.*" ; then
		sed -i "s/^[[:space:]]*${property}[[:space:]]*=.*/${property}=${value}/g" "${file}"
	else
		echo "${property}=${value}"	>> "${file}"
	fi
}

function prepareConfig {
	local configFile=/tmp/global-config.properties

	cp /deployments/etc/global-config.properties.orig "${configFile}"
	if [ -n "${IP}" ] ; then
		setProperty "${configFile}" "IP" "${IP}"
	fi

	if [ -n "${PORT}" ] ; then
		setProperty "${configFile}" "PORT" "${PORT}"
	fi	
}

prepareConfig

export THERMOSTAT_GATEWAY_HOME=/deployments

cd /
exec /deployments/bin/thermostat-web-gateway.sh

EOF

chmod +x /deployments/bin/run.sh

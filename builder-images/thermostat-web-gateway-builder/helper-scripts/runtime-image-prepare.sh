#!/bin/sh

# This script is executed as part of runtime image creation,
# after extracted artifacts are put in runtime image,
# but until that happens it basically behaves as an artifact

set -eu

gatewayHomeDir="/deployments"
configDir="${gatewayHomeDir}/etc"
backupConfigDir="${gatewayHomeDir}/etc.orig"
runtimeConfigDir="/tmp/thermostat-web-gateway-config"

# original config files are backuped and replaced with symlink to runtime config
# directory, where config files are generated from original ones at runtime

# runtimeConfigDir is placed in /tmp so that image itself is not modified at
# runtime

mkdir -p "${backupConfigDir}"

# setup global-config.properties such as it can be modified at runtime
mv "${configDir}/global-config.properties" "${backupConfigDir}/global-config.properties"
ln -s "${runtimeConfigDir}/global-config.properties" "${configDir}/global-config.properties"

# do the same for service config files
function prepareServiceConfigFile {
    local serviceName="${1}"

    mkdir -p "${backupConfigDir}/${serviceName}"
    mv "${configDir}/${serviceName}/service-config.properties" "${backupConfigDir}/${serviceName}/service-config.properties"
    ln -s "${runtimeConfigDir}/${serviceName}/service-config.properties" "${configDir}/${serviceName}/service-config.properties"
}

prepareServiceConfigFile "jvm-memory"
prepareServiceConfigFile "jvm-gc"

# create script, which generates config files from original
# ones to the runtimeConfigDir directory and then starts the gateway
# it is executed at runtime
# ( escaping is evil here :) )
cat > /deployments/bin/run.sh << EOF
#!/bin/sh

set -eu

runtimeConfigDir="${runtimeConfigDir:-}"
backupConfigDir="${backupConfigDir:-}"
gatewayHomeDir="${gatewayHomeDir:-}"

if [ -z "\${runtimeConfigDir:-}" ] ; then
    echo "ERROR: empty runtimeConfigDir" 1>&2
    exit 1
fi

if [ -z "\${backupConfigDir}" ] ; then
    echo "ERROR: empty backupConfigDir" 1>&2
    exit 1
fi

if [ -z "\${gatewayHomeDir}" ] ; then
    echo "ERROR: empty gatewayHomeDir" 1>&2
    exit 1
fi

# escape string so it does no act as regexp
function escapeString {
    local string="\${1}"

    # escape \\ . * [ ^ \$ characters
    printf '%s' "\${string}"
    | sed 's/\\\\/\\\\\\\\/g'
    | sed 's/\\./\\\\\\./g'
    | sed 's/\\*/\\\\\\*/g'
    | sed 's/\\[/\\\\\\[/g'
    | sed 's/\\^/\\\\\\^/g'
    | sed 's/\\\$/\\\\\\\$/g'
}

# same as escapeString but also escape forward slash ( used for sed )
function escapeStringSed {
    local string="\${1}"

    escapeString "\${string}" | sed 's;/;\\\\/;g'
}

# sets single property in properties file to desired value
function setProperty {
    local file="\${1}"
    local property="\${2}"
    local value="\${3}"

    if cat "\${file}" | grep -q "^[[:space:]]*\$( escapeString "\${property}" )[[:space:]]*=.*\\\$" ; then
        sed -i "s/^[[:space:]]*\$( escapeStringSed "\${property}" )[[:space:]]*=.*\\\$/\$( escapeStringSed "\${property}=\${value}" )/g" "\${file}"
    else
        printf '%s\\n' "\${property}=\${value}" >> "\${file}"
    fi
}

function setServiceProperty {
    local serviceName="\${1}"
    local property="\${2}"
    local value="\${3}"

    setProperty "\${runtimeConfigDir}/\${serviceName}/service-config.properties" \
        "\${property}" "\${value}"
}

# prepare service config file in runtime config dir with content of
# original config file
function prepareRuntimeServiceConfigFile {
    local serviceName="\${1}"

    mkdir -p "\${runtimeConfigDir}/\${serviceName}"
    cp "\${backupConfigDir}/\${serviceName}/service-config.properties" \
        "\${runtimeConfigDir}/\${serviceName}/service-config.properties"
}

# this function should prepare config files based on env. variables
# ( supplied from openshift ) prior to starting of thermostat-gateway
function prepareConfig {
    # remove runtimeConfigDir if exists ( just in case )
    rm -rf "\${runtimeConfigDir}"
    mkdir -p "\${runtimeConfigDir}"

    # prepare global config file
    local globalConfigFile="\${runtimeConfigDir}/global-config.properties"
    cp "\${backupConfigDir}/global-config.properties" "\${globalConfigFile}"
    # set wildcard address 0.0.0.0 ( bind on all interfaces )"
    setProperty "\${globalConfigFile}" "IP" "0.0.0.0"
    # set port to 30000
    setProperty "\${globalConfigFile}" "PORT" "30000"

    # prepare service config files
    prepareRuntimeServiceConfigFile "jvm-memory"
    prepareRuntimeServiceConfigFile "jvm-gc"

    if [ -n "\${MONGO_URL:-}" ] ; then
        setServiceProperty "jvm-memory" "MONGO_URL" "\${MONGO_URL}"
        setServiceProperty "jvm-gc" "MONGO_URL" "\${MONGO_URL}"
    else
        echo "ERROR: missing MONGO_URL" 1>&2
        exit 1
    fi

    if [ -n "\${MONGO_DB:-}" ] ; then
        setServiceProperty "jvm-memory" "MONGO_DB" "\${MONGO_DB}"
        setServiceProperty "jvm-gc" "MONGO_DB" "\${MONGO_DB}"
    else
        echo "ERROR: missing MONGO_DB" 1>&2
        exit 1
    fi

    if [ -n "\${MONGO_USERNAME:-}" ] ; then
        setServiceProperty "jvm-memory" "MONGO_USERNAME" "\${MONGO_USERNAME}"
        setServiceProperty "jvm-gc" "MONGO_USERNAME" "\${MONGO_USERNAME}"
    else
        echo "ERROR: missing MONGO_USERNAME" 1>&2
        exit 1
    fi

    if [ -n "\${MONGO_PASSWORD:-}" ] ; then
        setServiceProperty "jvm-memory" "MONGO_PASSWORD" "\${MONGO_PASSWORD}"
        setServiceProperty "jvm-gc" "MONGO_PASSWORD" "\${MONGO_PASSWORD}"
    else
        echo "ERROR: missing MONGO_PASSWORD" 1>&2
        exit 1
    fi
}

if

prepareConfig

# set home of thermostat gateway using env. variable
export THERMOSTAT_GATEWAY_HOME="\${gatewayHomeDir}"

# start thermostat-gateway itself
cd /
exec "\${gatewayHomeDir}/bin/thermostat-web-gateway.sh"

EOF

# make script created higher executable
chmod +x /deployments/bin/run.sh

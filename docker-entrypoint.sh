#!/bin/bash

# Check if the JIRA_HOME and JIRA_INSTALL variable are found in ENV.
if [ -z "${JIRA_HOME}" ] || [ -z "${JIRA_INSTALL}" ]; then
  echo "Either JIRA_HOME (${JIRA_HOME}), or JIRA_INSTALL (${JIRA_INSTALL}) is undefined."
  echo "Please ensure that it is set in Dockerfile, or passed as ENV variable."
  echo "Abnormal exit ..."
  exit 1
else
  echo "Found \${JIRA_HOME}: ${JIRA_HOME}"
  echo "Found \${JIRA_INSTALL}: ${JIRA_INSTALL}"
fi

# Show additional information for system logs:
cat ${JIRA_INSTALL}/atlassian-version.txt


if [ -n "${TZ_FILE}" ]; then
  # There is a time-zone file mentioned. Lets see if it actually exists.
  if [ -r ${TZ_FILE} ]; then
    # Set the symbolic link from the timezone file to /home/OS_USERNAME/localtime, which is owned by OS_USERNAME.
    # The link from /home/OS_USERNAME/localtime is already setup as /etc/localtime as user root, in Dockerfile.
    echo "Found \${TZ_FILE}: ${TZ_FILE} , for timezone."

    USER_HOME_DIR=$(grep ${OS_USERNAME} /etc/passwd | cut -d ':' -f 6)
    ln -sf ${TZ_FILE} ${USER_HOME_DIR}/localtime
  else
    echo "Specified TZ_FILE ($TZ_FILE) was not found on the file system. Default timezone will be used instead."
    echo "Timezone related files are in /usr/share/zoneinfo/*"
  fi
else
  echo "TZ_FILE was not specified, the default TimeZone (${TZ_FILE}) will be used."
fi

# Insert proxy specific directives and values in server.xml IF they are specified as ENV variables.
if [ -n "${X_PROXY_NAME}" ]; then

  # Remove all single and double quotes from the ENV variable
  X_PROXY_NAME=$(echo ${X_PROXY_NAME} | tr -d \' | tr -d \")

  if [ ! -f ${JIRA_INSTALL}/.modified.proxyname ]; then
    echo "Modifying server.xml to use '${X_PROXY_NAME}' as a value for 'proxyName'"

    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' \
      --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${JIRA_INSTALL}/conf/server.xml"

    touch ${JIRA_INSTALL}/.modified.proxyname
  else
    echo "server.xml is already modified, and the 'proxyName' attribute is already inserted in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_PROXY_NAME is found empty. Not modifying server.xml"
fi

if [ -n "${X_PROXY_PORT}" ]; then

  # Remove all single and double quotes from the ENV variable
  X_PROXY_PORT=$(echo ${X_PROXY_PORT} | tr -d \' | tr -d \")

  if [ ! -f ${JIRA_INSTALL}/.modified.proxyport ]; then
    echo "Modifying server.xml to use '${X_PROXY_PORT}' as a value for 'proxyPort'"

    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' \
      --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"

    touch ${JIRA_INSTALL}/.modified.proxyport
  else
    echo "server.xml is already modified, and the 'proxyPort' attribute is already inserted in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_PROXY_PORT is found empty. Not modifying server.xml"
fi

if [ -n "${X_PROXY_SCHEME}" ]; then

  # Remove all single and double quotes from the ENV variable
  X_PROXY_SCHEME=$(echo ${X_PROXY_SCHEME} | tr -d \' | tr -d \")

  if [ ! -f ${JIRA_INSTALL}/.modified.scheme ]; then
    echo "Modifying server.xml to use '${X_PROXY_SCHEME}' as a value for 'scheme'"

    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' \
      --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${JIRA_INSTALL}/conf/server.xml"

    touch ${JIRA_INSTALL}/.modified.scheme

    if [ "${X_PROXY_SCHEME}" == "https" ] && [ ! -f ${JIRA_INSTALL}/.modified.secure ]; then
      echo "Modifying server.xml to use 'true' as a value for 'secure'"

      xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' \
        --type "attr" --name "secure" --value "true" "${JIRA_INSTALL}/conf/server.xml"

      touch ${JIRA_INSTALL}/.modified.secure

      echo "Modifying server.xml to set 'redirectPort' to ${X_PROXY_PORT} instead of default port 8080"

      xmlstarlet ed --inplace --pf --ps --update '//Connector[@port="8080"]/@redirectPort' \
        --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"

      touch ${JIRA_INSTALL}/.modified.redirectPort
    fi

  else
    echo "server.xml is already modified, and the 'scheme' attribute is already inserted in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_PROXY_SCHEME is found empty. Not modifying server.xml"
fi

if [ -n "${X_CONTEXT_PATH}" ]; then
  # Remove all single and double quotes from the ENV variable
  X_CONTEXT_PATH=$(echo ${X_CONTEXT_PATH} | tr -d \' | tr -d \")

  if [ ! -f ${JIRA_INSTALL}/.modified.path ]; then
    echo "Modifying server.xml to use '${X_CONTEXT_PATH}' as a value of context 'path',  instead of the default '<null>'"

    xmlstarlet ed --inplace --pf --ps --update '//Context/@path' \
      --value "${X_CONTEXT_PATH}" "${JIRA_INSTALL}/conf/server.xml"

    touch ${JIRA_INSTALL}/.modified.path

  else
    echo "server.xml is already modified, and the context 'path' attribute is already updated in the default 'Connector'. Refusing to re-modify server.xml."
  fi
else
  echo "X_CONTEXT_PATH is found empty. Not modifying server.xml"

fi


# Datacenter mode:
# ----------------

# Check if DATACENTER_MODE is set to true and JIRA_DATACENTER_SHARE is configured
if [ "${DATACENTER_MODE}" == "true" ] && [ -n "${JIRA_DATACENTER_SHARE}" ]; then

  # check if the shared home directory exists.
  # Note: The DataCenter logic for Jira differs from Confluence.
  if [ -d ${JIRA_DATACENTER_SHARE} ]; then
    echo "DATACENTER_MODE is found to be 'true', and JIRA_DATACENTER_SHARE is found as: ${JIRA_DATACENTER_SHARE}."
    echo "Proceeding to setup JIRA_HOME/cluster.properties file"

    # hostname -f returns the FQDN of the node, which includes its hostname and the k8s NAMESPACE, etc.
    JIRA_NODE_ID=$(hostname -f)

    # Create the JIRA_HOME/cluster.properties file with the information below.
    # Ensure that the EOF below the information is on a new line without any leading or trailing spaces.

    cat > ${JIRA_HOME}/cluster.properties << EOF
    # This ID must be unique across the cluster / namespace.
    # jira.node.id = JIRA_POD_NAME.jira.JIRA_NAMESPACE.svc.cluster.local
    jira.node.id = ${JIRA_NODE_ID}
    # The location of the shared home directory for all JIRA nodes
    jira.shared.home = ${JIRA_DATACENTER_SHARE}
    # Apparently this might need to be set to get the cache synchronization work
    ## ehcache.listener.hostName = JIRA_POD_NAME.jira.JIRA_NAMESPACE.svc.cluster.local
    ehcache.listener.hostName = ${JIRA_NODE_ID}
    ehcache.listener.port = 40001
    ehcache.object.port = 40011
EOF
  else
    echo "JIRA_DATACENTER_SHARE is defined as (${JIRA_DATACENTER_SHARE}), but the directory does not exist."
    echo "Refusing to setup Jira in DataCenter mode."
  fi
else
  echo "Either DATACENTER_MODE is false or JIRA_DATACENTER_SHARE is empty. Refusing to setup Jira in data-center mode."
  echo "If you are trying to run Jira in DataCenter mode, then both DATACENTER_MODE and JIRA_DATACENTER_SHARE need to be set to appropriate values."

fi

# Import SSL Certificates
# ------------------------
echo
echo "\${SSL_CERTS_PATH} is set to: ${SSL_CERTS_PATH}"
echo "\${CERTIFICATE} is set to: ${CERTIFICATE}"
echo "\${ENABLE_CERT_IMPORT} is set to: ${ENABLE_CERT_IMPORT}"

# CERTIFICATE variable existed for importing a single certificate.
# If SSL_CERTS_PATH is empty and CERTIFICATE file is mentioned, extract
#   directory path from CERTIFICATE file as SSL_CERTS_PATH.

if [ -z "${SSL_CERTS_PATH}" ] && [ -n "${CERTIFICATE}" ]; then
  echo "CERTIFICATE found without SSL_CERTS_PATH in ENV variables."
  echo "Extract dirname from CERTIFICATE variable and use it as SSL_CERTS_PATH."
  SSL_CERTS_PATH=$(dirname ${CERTIFICATE})
fi

if [ -z "${JAVA_KEYSTORE_PASSWORD}" ]; then
  echo 'The ENV variable JAVA_KEYSTORE_PASSWORD is empty.'
  echo 'Please provide JAVA_KEYSTORE_PASSWORD as an ENV variable. Using the default value for now.'
  JAVA_KEYSTORE_PASSWORD='changeit'
fi

# If SSL_CERTS_PATH exists, then we can import certificates.
# Whitelisted certificates: *.crt, *.pem
# It does not matter if the directory is empty.
#   In that case, no certificates will be imported.
# By default the keystore is stored in a file named '.keystore' in the
#   user's home directory.

if [ "${ENABLE_CERT_IMPORT}" == "true" ] && [ ! -z "${SSL_CERTS_PATH}" ]; then
  JAVA_KEYSTORE_FILE=${JIRA_INSTALL}/jre/lib/security/cacerts
  # Loop through all certificates in this directory and import them.
  for CERT in ${SSL_CERTS_PATH}/*.crt ${SSL_CERTS_PATH}/*.pem; do
    echo "Importing certificate: ${CERT} ..."
    ${JIRA_INSTALL}/jre/bin/keytool \
      -noprompt \
      -storepass ${JAVA_KEYSTORE_PASSWORD} \
      -keystore ${JAVA_KEYSTORE_FILE} \
      -import \
      -file ${CERT} \
      -alias $(basename ${CERT})
  done
  echo "The following certificates were imported:"
  ${JIRA_INSTALL}/jre/bin/keytool \
    -list -keystore ${JAVA_KEYSTORE_FILE} \
    -storepass ${JAVA_KEYSTORE_PASSWORD} \
    -v \
    | egrep "crt|pem"
fi



# Download plugins listed in ${PLUGINS_FILE}
# ------------------------------------------
echo
if [ -r ${PLUGINS_FILE} ]; then
  echo "Found plugins file: ${PLUGINS_FILE} ... Processing ..."
  PLUGIN_IDS_LIST=$(cat ${PLUGINS_FILE} |  sed -e '/\#/d' -e '/^$/d'|  awk '{print $1}')
  if [ -z "${PLUGIN_IDS_LIST}" ] ; then 
    echo "The plugins file - ${PLUGINS_FILE} is empty, skipping plugins download ..."
  else

    for PLUGIN_ID in ${PLUGIN_IDS_LIST}; do 
    echo
      PLUGIN_URL="https://marketplace.atlassian.com/download/plugins/${PLUGIN_ID}"
      echo "Searching Atlassian marketplace for plugin file related to plugin ID: ${PLUGIN_ID} ..."
      PLUGIN_FILE_URL=$(curl -s -I -L  $PLUGIN_URL | grep  -e "location.*http" | cut -d ' ' -f2 | tr -d '\r\n')
      if [ -z "${PLUGIN_FILE_URL}" ]; then
        echo "Could not find a plugin with plugin ID: ${PLUGIN_ID}. Skipping ..."
      else
        PLUGIN_FILENAME=$(basename ${PLUGIN_FILE_URL})
        echo "The plugin file for the plugin ID: ${PLUGIN_ID}, is found to be: ${PLUGIN_FILENAME} ... Downloading ..."
        echo "Saving plugin file as ${JIRA_INSTALL}/atlassian-jira/WEB-INF/atlassian-bundled-plugins/${PLUGIN_FILENAME} ..."
        curl -s $PLUGIN_FILE_URL -o ${JIRA_INSTALL}/atlassian-jira/WEB-INF/atlassian-bundled-plugins/${PLUGIN_FILENAME}
      fi
    done
    echo
  fi

else
  echo "Plugins file not found. Skipping plugin installation."
fi
echo


# Generate/ add additional information for system logs (again):
echo
echo "Jira version and related platform information:"
echo "============================================="
cat ${JIRA_INSTALL}/atlassian-version.txt

echo
echo "Finished running entrypoint script(s). Now executing: $@  ..."
echo

# Execute the command specified as CMD in Dockerfile:
exec "$@"

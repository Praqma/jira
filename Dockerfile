FROM fedora:29

LABEL maintainer="kaz@praqma.net heh@praqma.net"

# Why Fedora as base OS?
# * Fedora always has latest packages compared to CentOS.
# * Fedora does not need extra CentOS's EPEL repositories to install tools.
# * Fedora runs as 'root', and has '/' as it's default WORKDIR.

# This Dockerfile builds a container image for Atlassian Jira, 
# using atlassian-jira-*.bin installer. The advantage of using the bin-installer is
#   that it includes OracleJDK. We do not have to depend on Oracle Java 
#   or manage it in our image.
#
# Since this container image contains OracleJDK, we can not (re)distribute it 
#   as binary image, because of licensing issues. Though mentioning it in 
#   Dockerfile is ok.
#

# Note: Check build-instructions.md for building this image.

################################### START -  Environment variables #######################################
#
#

# JIRA_VERSION:
# ------------
# The value for JIRA_VERSION should be a version number, which is part of the name of the jira software bin/tarball/zip.
ENV JIRA_VERSION=8.2.1


# JIRA_DOWNLOAD_URL:
# -----------------
# User does not need to modify this ENV variable unless absolutely necessary.
ENV JIRA_DOWNLOAD_URL https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}-x64.bin 


# ADOPT_JRE_VERSION:
# -----------------
# The ADOPT_JRE's "version" is the string between "hotspot_" and ".tar.gz" in the URL.
# This must be correct as it is used to download the correct file from AdoptOpenJDK (github) website.
ENV ADOPT_JRE_VERSION=8u212b03


# ADOPT_JRE_DOWNLOAD_URL:
# ----------------------
# Becasue of the silly naming scheme, it is very difficult to find a proper pattern for a file to download.
# That's why we have to use a full URL
# User does not need to modify this ENV variable unless absolutely necessary.
ENV ADOPT_JRE_DOWNLOAD_URL=https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u212-b03/OpenJDK8U-jre_x64_linux_hotspot_${ADOPT_JRE_VERSION}.tar.gz


# OS_USERNAME:
# -----------
#  Jira bin-installer automatically creates a 'jira' user and a 'jira' group. 
#  You need to specify it's name here.
ENV OS_USERNAME jira


# OS_GROUPNAME:
# ------------
#  Jira bin-installer automatically creates a 'jira' user and a 'jira' group.
#  You need to specify it's name here.
ENV OS_GROUPNAME jira


# JIRA_HOME:
# ---------
# Persistent directory: (need persistent storage.) This can be mounted on a OS directory mount-point.
# Need to be owned by the same UID as of user jira, normally UID 1000.
# The value if this variable should be same as 'app.jiraHome' in the jira-response.varfile file.
# It is mandatory to specify JIRA_HOME.
ENV JIRA_HOME /var/atlassian/application-data/jira

# JIRA_INSTALL:
# ------------
# Jira Installation files: (persistent storage NOT needed)
# This ENV var is important to set here, as it is used by docker-entry.sh script at container startup.
# The value if this variable should be same as 'sys.installationDir' in the jira-response.varfile file.
# It is mandatory to specify JIRA_INSTALL.
ENV JIRA_INSTALL=/opt/atlassian/jira

# TZ_FILE:
# -------
# This is the timezone file to use for the container.
# Timezone files are normally found in /usr/share/zoneinfo/* .
# Set the path of the correct zone you want to use for your container.
ENV TZ_FILE="/usr/share/zoneinfo/Europe/Oslo"

# JAVA_HOME:
# ---------
# While configuring JAVA_HOME, ensure that it is the path to the directory where you find the `bin/java` executable under it.
# It is mandatory to specify JAVA_HOME.
ENV JAVA_HOME /opt/atlassian/jira/jre

# JAVA_OPTS:
# ---------
# Optional values you want to pass as JAVA_OPTS. You can pass Java memory parameters to this variable,
#    but in newer versions of Atlassian software, memory settings are done in CATALINA_OPTS.
# JAVA_OPTS  "-Dsome.javaSetting=somevalue"
# ENV JAVA_OPTS "-Dhttp.nonProxyHosts=jira.example.com"

# CATALINA settings:
# -----------------
# CATLINA_OPTS will be used by JIRA_INSTALL/bin/setenv.sh script .
# You can use this to setup internationalization options and also any Java memory settings.
# It is a good idea to use same value for -Xms and -Xmx to avoid frequence shrinking and expanding of Java memory.
# In the example below it is set to 2 GB. It should always be half (or less) of physical RAM of the server/node/pod/container.
ENV CATALINA_OPTS "-Dfile.encoding=UTF-8 -Xms1024m -Xmx1024m"


# ENABLE_CERT_IMPORT:
# ------------------
# Allow import of user defined certificates.
ENV ENABLE_CERT_IMPORT false

# SSL_CERTS_PATH:
# --------------
# If you have self signed certificates, you need to force Atlassian applications to trust those certs.
# Very useful when different atlassian applications need to talk to each other.
# This should be a path which you either volume-mount in docker or k8s.
ENV SSL_CERTS_PATH /var/atlassian/ssl


# PLUGINS_FILE (Jira plugins):
# ---------------------------
# Any additional jira plugins you need to install should be listed in file named `jira-plugins.list` - one at each line.
# Then mount that file at container-runtime at the location you specified in PLUGINS_FILE environment variable.
# This also means that you can control the location and name of this file just by controlling this variable.
# The value of this variable is the path **inside** the container.
ENV PLUGINS_FILE /tmp/jira-plugins.list

# DATACENTER_MODE:
# ----------------
# This needs to be set to true if you want to setup Jira in a data-center mode.
ENV DATACENTER_MODE=false

# JIRA_DATACENTER_SHARE:
# ---------------------
# This is only used in DataCenter mode. It needs to be a shared location, which multiple jira instances can write to.
# This location will most probably be an NFS share, and should exist on the file system.
# If it does not exist, then it will be created and chown to the jira OS user.
# NB: FOr this to work, DATACENTER_MODE should be set to true.
# ENV JIRA_DATACENTER_SHARE /var/atlassian/jira-datacenter
ENV JIRA_DATACENTER_SHARE="/mnt/shared"


# Reverse proxy specific variables:
# ================================

# X_PROXY_NAME:
# ------------
# The FQDN used by anyone accessing jira from outside (i.e. The FQDN of the proxy server/ingress controller):
# ENV X_PROXY_NAME 'jira.example.com'

# X_PROXY_PORT:
# ------------
# The public facing port, not the jira container port
# ENV X_PROXY_PORT '443'

# X_PROXY_SCHEME:
# --------------
# The scheme used by the public facing proxy (normally https)
# ENV X_PROXY_SCHEME 'https'

# X_CONTEXT_PATH:
# --------------
# (formerly X_PATH)
# IMPORTANT: BREAKING CHANGE: This was formerly X_PATH. Please adjust your scripts/YAML/TOML files accordingly.
# The context path, if any. Best to leave disabled, or set to blank.
# ENV X_CONTEXT_PATH ''

#
#
####################################### END - Environment variables #######################################

########################################### START - Build image #####################################
#
#

# Internaltionalization / i18n - Notes on OS settings (Fedora):
# ------------------------------------------------------------
# Note the file '/etc/sysconfig/i18n' does not exist by default
# RUN echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/sysconfig/i18n
# RUN echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/locale.conf

# Internaltionalization / i18n - Notes on OS settings (Debian):
# ------------------------------------------------------------
# RUN echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" > /etc/default/locale

# Unattended installation:
# -----------------------
# https://confluence.atlassian.com/jira064/installing-jira-on-linux-720411834.html
# Jira response file is used for unattended installation using bin-installer.
COPY jira-response.varfile /tmp/

# We need the following in the container image:
# * xmlstarlet to modify XML files.
# * findutils provide 'find' ,which is helpful in finding files, especially during development and trouble-shooting.
# * gunzip, hostname , ps are  needed by installer.
# * 'which' is used by the installer to find the location of gunzip
# * iputils provides ping, iproute provide ip, ss
# * jq
# * Added the ln command to set the correct timezone to Oslo
# * bind-utils provides dig, used in a crucial script in this image.
# Change ownership of /etc/localtime to OS_USERNAME, so we can sym-link to it in docker-entrypoint.sh
# The installer creats a user jira.
# After the installer is finished running, we fix some permissions, such as JIRA_INSTALL and JIRA_HOME.
# The silly syncs are for Dockerhub to process this properly.
# The fonts are added because Atlassian products rely on these, and openjdk does not provide these fonts.

RUN echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" >/etc/sysconfig/i18n \
  && echo -e "LANG=\"en_US.UTF-8\" \n LC_ALL=\"en_US.UTF-8\"" >/etc/locale.conf \
  && yum -y install xmlstarlet findutils which gzip hostname procps iputils bind-utils iproute jq fontconfig dejavu-sans-fonts \
  && sync \
  && yum -y clean all \
  && ln -sf ${TZ_FILE} /etc/localtime \
  && echo "Downloading Jira from: ${JIRA_DOWNLOAD_URL}" && curl -# -L -O ${JIRA_DOWNLOAD_URL}  && echo \
  && sync \ 
  && echo "Downloading AdoptOpenJRE from: ${ADOPT_JRE_DOWNLOAD_URL}" && curl -# -L -O ${ADOPT_JRE_DOWNLOAD_URL} \
  && sync \
  && chmod +x ./atlassian-jira-software-${JIRA_VERSION}-x64.bin \
  && sync \
  && ./atlassian-jira-software-${JIRA_VERSION}-x64.bin -q -varfile /tmp/jira-response.varfile \
  && sync \
  &&   JRE_TARBALL=$(basename ${ADOPT_JRE_DOWNLOAD_URL}) \
  &&   TEMP_DIR=$(mktemp -d) \
  &&   tar xzf ${JRE_TARBALL} -C ${TEMP_DIR}/ \
  &&   JRE_DIR=$(find  ${TEMP_DIR}  -maxdepth 1 -name "*-jre" -type d) \
  &&   rm -fr ${JAVA_HOME}/* \
  &&   cp -r ${JRE_DIR}/* ${JAVA_HOME}/ \
  && sync \ 
  && echo "Jira version: ${JIRA_VERSION}" > ${JIRA_INSTALL}/atlassian-version.txt \
  && ${JIRA_INSTALL}/jre/bin/java \
       -classpath ${JIRA_INSTALL}/lib/catalina.jar \
       org.apache.catalina.util.ServerInfo  >> ${JIRA_INSTALL}/atlassian-version.txt  \
  && sync \
  && rm -f ./atlassian-jira-software-${JIRA_VERSION}-x64.bin \
  && rm -f $JRE_TARBALL \
  && if [ -n "${JIRA_DATACENTER_SHARE}" ] && [ ! -d "${JIRA_DATACENTER_SHARE}" ]; then mkdir -p ${JIRA_DATACENTER_SHARE}; fi \
  && if [ -n "${JIRA_DATACENTER_SHARE}" ] && [ -d "${JIRA_DATACENTER_SHARE}" ]; then chown -R ${OS_USERNAME}:${OS_GROUPNAME} ${JIRA_DATACENTER_SHARE}; fi \
  && chown -R ${OS_USERNAME}:${OS_GROUPNAME} ${JIRA_INSTALL} ${JIRA_HOME} \
  && HOME_DIR=$(grep ${OS_USERNAME} /etc/passwd | cut -d ':' -f 6) \
  && cp /etc/localtime ${HOME_DIR}/ \
  && chown ${OS_USERNAME}:${OS_GROUPNAME} ${HOME_DIR}/localtime \
  && ln -sf ${HOME_DIR}/localtime /etc/localtime \
  && sync \
  && if [ -n "${SSL_CERTS_PATH}" ] && [ ! -d "${SSL_CERTS_PATH}" ]; then mkdir -p ${SSL_CERTS_PATH}; fi \
  && if [ -n "${SSL_CERTS_PATH}" ] && [ -d "${SSL_CERTS_PATH}" ]; then chown ${OS_USERNAME}:${OS_GROUPNAME} ${SSL_CERTS_PATH}; fi \
  && sync


# Docker entrypoint script:
# -------------------------
# Copy docker-entrypoint.sh to configure server.xml configuration file in order to run the service behind a reverse proxy.
COPY docker-entrypoint.sh /

#
#
########################################### END - Build image ###########################################

# Expose default HTTP connector port for Jira.
EXPOSE 8080/tcp


# Peer discovery ports for Jira running in cluster mode.
EXPOSE 40001/tcp
EXPOSE 40011/tcp

# Change the default working directory from '/' to '/var/atlassian/application-data/jira'
#   - or - whatever value you used above as JIRA_HOME.
WORKDIR ${JIRA_HOME}

# Set the default user for the image/container to user 'jira'. Jira software will be run as this user & group.
# USER jira:jira
USER ${OS_USERNAME}:${OS_GROUPNAME}

# Persistent volumes:
# Set volume mount points for home directory, because changes to the home directory needs to be persisted.
# Optionally, changes to parts of the installation directory also need persistence, eg. logs.
VOLUME ["${JIRA_HOME}", "${JIRA_INSTALL}/logs"]

# We have a custom entrypoint, which sets up server.xml with reverse proxy settings, IF provided, and some other stuff.
#  When ENTRYPOINT is present in a dockerfile, it is always run before executing CMD.
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian JIRA as a foreground process by default, using our modified startup script.
# The CMD command does not take environment variable, so it has to be an absolute path.
CMD ["/opt/atlassian/jira/bin/start-jira.sh", "-fg"]

# End of Dockerfile. Below are just some notes.
#
#
########################################### END - Build the image ###############################################

# Build this image manually:
# =========================
# docker build -t test/jira-server:7.8.0-test .
# docker push test/jira-server:7.8.0-test

# Check build-instructions.md for instructions for automated builds.


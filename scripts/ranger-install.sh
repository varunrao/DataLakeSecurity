#!/usr/bin/env bash
# @skkodali

_usage()
{
    echo "sh -x knox-install.sh \
            '10.0.1.235'
            '389'
            'CN=AWS ADMIN,CN=Users,DC=awshadoop,DC=com'
            'CheckSum123'
            'CN=Users,DC=awshadoop,DC=com'
            'sAMAccountName'
            'person'
            'dc=awshadoop,dc=com'
            'group'
            'member'
            's3://skkodali-proserve/knox-blog'
            'knox/ip-10-0-1-25.ec2.internal@EC2.INTERNAL'
            'ip-10-0-1-25.ec2.internal'
         "
}
_setEnv()
{

    AWS=aws
    S3_COPY="s3 cp"
    # OUTPUT_FILE="${SCRIPTS_HOME}/log-files/log_`date '+%Y-%m-%d-%H-%M-%S'`.out"

    KNOX_SOFTWARE_VERSION="1.0.0"
    WGET="/usr/bin/wget"
    KNOX_SOFTWARE_LOCATION="http://apache.claz.org/knox/1.0.0/"
    UNZIP="/usr/bin/unzip"
    LN="/bin/ln"
    KNOX_UNIX_USERNAME="knox"
    KNOX_UNIX_GROUPNAME="knox"
    KNOX_USER_HOME="/home/knox"
    EC2_USER="ec2-user"
    KNOX_GATEWAY_HOME="/home/knox/knox"
    KNOX_GATEWAY_MASTER_PASSWORD="CheckSum123"
    XMLSTARLET="/usr/bin/xmlstarlet"
    SCRIPTS_S3_BUCKET_LOC="skkodali-proserve/knox-blog"
    JDK_SOFTWARE_FILE_NAME="jdk-8u161-linux-x64.rpm"
    RPM="/bin/rpm"

    MAVEN_VERSION="3.5.3"
    M2_HOME=/opt/apache-maven-${MAVEN_VERSION}
    M2_BIN=${M2_HOME}/bin
    MYSQL="/usr/bin/mysql"
    RANGER_SOFTWARE_VERSION="1.0.0"
    RANGER_SOFTWARE_LOCATION="http://apache.claz.org/ranger/${RANGER_SOFTWARE_VERSION}/apache-ranger-${RANGER_SOFTWARE_VERSION}.tar.gz"
    GUNZIP="/bin/gunzip"
    TAR="/bin/tar"

    SOLR_SOFTWARE_VERSION="7.3.0"
    SOLR_SOFTWARE_LOCATION="http://apache.spinellicreations.com/lucene/solr/${SOLR_SOFTWARE_VERSION}/solr-${SOLR_SOFTWARE_VERSION}.tgz"

}

_downloadAndInstallMaven()
{
    cd;
    ${WGET} http://mirrors.gigenet.com/apache/maven/maven-3/3.5.3/binaries/apache-maven-3.5.3-bin.tar.gz;
    sudo su -c "tar -zxvf apache-maven-${MAVEN_VERSION}-bin.tar.gz -C /opt";
    sudo sh -c "echo 'export M2_HOME=/opt/apache-maven-${MAVEN_VERSION}' >> /etc/profile.d/maven.sh"
    sudo sh -c "echo 'export M2=${M2_HOME}/bin' >> /etc/profile.d/maven.sh"
    sudo sh -c "echo 'export PATH=${M2_BIN}:$PATH' >> /etc/profile.d/maven.sh"
    source /etc/profile.d/maven.sh

}

_installRequiredRPMs()
{
    sudo yum install -y mysql-connector-java
    sudo yum -y install mysql-server
    sudo yum install -y git
    sudo yum -y install gcc
}

_Check_MySql_Sql_Connection()
{
  SQL_CON=`${MYSQL} -h ${RDS_HOSTNAME} -u ${RDS_ROOT_USERNAME} -p${RDS_ROOT_PASSWORD} -e 'exit;'`
  if ! [[  ${SQL_CON} == *"CURRENT_TIMESTAMP"* ]]; then
    echo "SQL Connection to RDS Mysql database is NOT successful."
    echo "******** Exiting the setup script......"
    exit 0
  else
    echo "SQL Connection to RDS MySQL database is successful....Continuing"
  fi
}

_createKnoxUser()
{
    knoxuserexists=`id knox`
    if [ "$?" != "0" ]; then
        sudo groupadd ${KNOX_UNIX_USERNAME}
        sudo useradd -g ${KNOX_UNIX_GROUPNAME} ${KNOX_UNIX_USERNAME}
        sudo chown ${KNOX_UNIX_USERNAME}:${EC2_USER} ${KNOX_USER_HOME}
        sudo chmod -R 775 ${KNOX_USER_HOME}
    fi
}

_downloadAndInstallRangerSoftware()
{
    cd; mkdir apache-ranger; cd apache-ranger;
    git clone -b ranger-${RANGER_SOFTWARE_VERSION} https://github.com/apache/ranger.git
    #RANGER_SOFTWARE_FULL_URL=${RANGER_SOFTWARE_LOCATION}
    #${WGET} ${RANGER_SOFTWARE_FULL_URL}
    #${GUNZIP} apache-ranger-${RANGER_SOFTWARE_VERSION}.tar.gz
    #${TAR} -xvf apache-ranger-${RANGER_SOFTWARE_VERSION}.tar
    #${LN} -s apache-ranger-${RANGER_SOFTWARE_VERSION} apache-ranger
    export MAVEN_OPTS="-Xmx512M"; export JAVA_HOME=/usr/java/latest/;
    cd ~/apache-ranger/ranger;
    ${M2_BIN}/mvn clean install
    ${M2_BIN}/mvn compile package assembly:assembly
    cd /usr/local/
    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-admin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-admin ranger-admin

}
_downloadnstallAndStartSolr()
{
    cd; wget ${SOLR_SOFTWARE_LOCATION}
    tar -xvf solr-${SOLR_SOFTWARE_VERSION}.tgz
    cd ~/solr-${SOLR_SOFTWARE_VERSION}/bin
    export JAVA_HOME=/usr/java/latest
    ./solr start -p 8983
}
_setupMySQLDatabaseAndPrivileges()
{
    HOSTNAMEI=`hostname -I`
    SQL_CON=`${MYSQL} -h ${RDS_HOSTNAME} -u ${RDS_ROOT_USERNAME} -p${RDS_ROOT_PASSWORD} -e \
    CREATE USER 'rangeradmin'@'localhost' IDENTIFIED BY 'rangeradmin';
    GRANT ALL PRIVILEGES ON `%`.* TO 'rangeradmin'@'localhost';
    CREATE USER 'rangeradmin'@'%' IDENTIFIED BY 'rangeradmin';
    GRANT ALL PRIVILEGES ON `%`.* TO 'rangeradmin'@'%';
    CREATE USER 'rangeradmin'@'${HOSTNAMEI}' IDENTIFIED BY 'rangeradmin';
    GRANT ALL PRIVILEGES ON `%`.* TO 'rangeradmin'@'${HOSTNAMEI}';
    GRANT ALL PRIVILEGES ON `%`.* TO 'rangeradmin'@'${HOSTNAMEI}' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON `%`.* TO 'rangeradmin'@'localhost' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON `%`.* TO 'rangeradmin'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
    'exit;'`

}
_setupRangerAdmin()
{
    cd /usr/local/ranger-admin


}
_downloadAndInstallKnoxSoftware()
{
    #sudo su - knox
    WHOAMI=`whoami`

    KNOX_SOFTWARE_FULL_URL=${KNOX_SOFTWARE_LOCATION}/knox-${KNOX_SOFTWARE_VERSION}.zip
    cd ${KNOX_USER_HOME};
    ${WGET} ${KNOX_SOFTWARE_FULL_URL}

    if [ "$?" = "0" ]; then
        echo "Knox software from ${KNOX_SOFTWARE_FULL_URL} is downloaded successfully"
    else
        echo "ERROR : Knox software from ${KNOX_SOFTWARE_FULL_URL} failed. Please check the URL"
        exit 99
    fi
    sudo chown -R ${KNOX_UNIX_USERNAME}:${EC2_USER} ${KNOX_USER_HOME}
    sudo chmod -R 775 ${KNOX_USER_HOME}

    cd ${KNOX_USER_HOME}
    ${UNZIP} knox-${KNOX_SOFTWARE_VERSION}.zip
    ${LN} -s knox-${KNOX_SOFTWARE_VERSION} knox

    sudo chown -R ${KNOX_UNIX_USERNAME}:${EC2_USER} ${KNOX_USER_HOME}
    sudo chmod -R 775 ${KNOX_USER_HOME}

}

_createKnoxMasterSecret()
{
    if [ -d "${KNOX_GATEWAY_HOME}" ]; then
         cd ${KNOX_GATEWAY_HOME}/bin

         /usr/bin/expect << EOF
         spawn ${KNOX_GATEWAY_HOME}/bin/knoxcli.sh create-master --force
         expect "Enter master secret:\r"
         send "${KNOX_GATEWAY_MASTER_PASSWORD}\r"
         expect "Enter master secret again:\r"
         send "${KNOX_GATEWAY_MASTER_PASSWORD}\r"
EOF

         if [ "$?" = "0" ]; then
               echo "Knox's master key created successfully."
         else
               echo "ERROR : Knox's master key creation failed."
               exit 99
         fi
    fi
}

_updateKnoxGatewayPortInGatewaySiteXML()
{
    # By default, knox will start to run on port 8443. But this port is already used by aws's emr instancce controller.
    # Let's start knox on port 8449 - chosen randomly

    KNOX_GATEWAY_SITE_XML="${KNOX_GATEWAY_HOME}/conf/gateway-site.xml"
    ${XMLSTARLET} ed -L -u "/configuration/property[name='gateway.port']/value" -v 8449 ${KNOX_GATEWAY_SITE_XML}

}

_createATopologyFile()
{
    KNOX_TOPOLOGY_DIRECTORY="${KNOX_GATEWAY_HOME}/conf/topologies"
    TOPOLOGY_FILE_NAME="emr-cluster-top" # You can give any name. An XML file with this name will be created.

    cat >${KNOX_TOPOLOGY_DIRECTORY}/${TOPOLOGY_FILE_NAME}.xml <<EOF

        <topology>
          <gateway>

            <provider>
              <role>authentication</role>
              <name>ShiroProvider</name>
              <enabled>true</enabled>
              <param name="main.ldapRealm" value="org.apache.hadoop.gateway.shirorealm.KnoxLdapRealm"/>
              <param name="main.ldapContextFactory" value="org.apache.hadoop.gateway.shirorealm.KnoxLdapContextFactory"/>
              <param name="main.ldapRealm.contextFactory" value="\$ldapContextFactory"/>

              <param name="main.ldapRealm.contextFactory.url" value="ldap://${LDAP_HOST_NAME}:${LDAP_PORT}"/>
              <param name="main.ldapRealm.contextFactory.systemUsername" value="${LDAP_BIND_USERNAME}"/>
              <param name="main.ldapRealm.contextFactory.systemPassword" value="${LDAP_BIND_USER_PASSWORD}"/>

              <param name="main.ldapRealm.searchBase" value="${LDAP_SEARCH_BASE}"/>
              <param name="main.ldapRealm.userSearchAttributeName" value="${LDAP_USER_SEARCH_ATTRIBUTE_NAME}"/>
              <param name="main.ldapRealm.userObjectClass" value="${LDAP_USER_OBJECT_CLASS}"/>

              <param name="main.ldapRealm.authorizationEnabled" value="true"/>
              <param name="main.ldapRealm.groupSearchBase" value="${LDAP_GROUP_SEARCH_BASE}"/>
              <param name="main.ldapRealm.groupObjectClass" value="${LDAP_GROUP_OBJECT_CLASS}"/>
              <param name="main.ldapRealm.groupIdAttribute" value="${LDAP_USER_SEARCH_ATTRIBUTE_NAME}"/>
              <param name="main.ldapRealm.memberAttribute" value="${LDAP_MEMBER_ATTRIBUTE}"/>

              <param name="urls./**" value="authcBasic"/>
            </provider>

          </gateway>
          <service>
             <role>KNOX</role>
          </service>

          <service>
             <role>NAMENODE</role>
             <url>hdfs://${EMR_MASTER_MACHINE}:8020</url>
          </service>
          <service>
             <role>JOBTRACKER</role>
             <url>rpc://${EMR_MASTER_MACHINE}:8050</url>
          </service>
          <service>
             <role>WEBHDFS</role>
             <url>http://${EMR_MASTER_MACHINE}:50070/webhdfs</url>
          </service>
          <service>
             <role>WEBHCAT</role>
             <url>http://${EMR_MASTER_MACHINE}:50111/templeton</url>
          </service>
          <service>
             <role>OOZIE</role>
             <url>http://${EMR_MASTER_MACHINE}:11000/oozie</url>
          </service>
          <service>
             <role>WEBHBASE</role>
             <url>http://${EMR_MASTER_MACHINE}:60080</url>
          </service>
          <service>
             <role>HIVE</role>
             <url>http://${EMR_MASTER_MACHINE}:10001/cliservice</url>
          </service>
          <service>
             <role>RESOURCEMANAGER</role>
             <url>http://${EMR_MASTER_MACHINE}:8088/ws</url>
          </service>
        </topology>
EOF
# Make sure EOF keyword below start at start of the line.
}

_downloadKeyTabAndKRB5FilesFromS3Bucket()
{
    # We need to copy the /etc/krb5.conf and /mnt/var/lib/bigtop_keytabs/knox.keytab files from S3 temp bucket.
    # Make sure these files are uploaded to S3 bucket from EMR master machine.
    # In "knox-kerberos-setup-on-emr.sh" script which will be executed as an EMR step on the kerberozied cluster, we have a step to upload then to S3 bucket.
    # Check "_uploadKeyTabAndKRB5FilesToS3Bucket()" Function in "knox-kerberos-setup-on-emr.sh" script.

    ${AWS} ${S3_COPY} ${TEMP_S3_BUCKET}/knox.keytab ${KNOX_GATEWAY_HOME}/conf/
    if [ "$?" != "0" ]; then
        print "Unable to download knox.keytab file from S3. Exiting..."
        exit 99
    fi
    ${AWS} ${S3_COPY} ${TEMP_S3_BUCKET}/krb5.conf ${KNOX_GATEWAY_HOME}/conf/
    if [ "$?" != "0" ]; then
        print "Unable to download krb5.conf file from S3. Exiting..."
        exit 99
    fi
}

_createkrb5JAASLoginCOnfFile()
{
    echo "test"
    KNOX_TOPOLOGY_DIRECTORY="${KNOX_GATEWAY_HOME}/conf/topologies"
    TOPOLOGY_FILE_NAME="emr-cluster-top" # You can give any name. An XML file with this name will be created.

    cat >${KNOX_GATEWAY_HOME}/conf/krb5JAASLogin.conf <<EOF
com.sun.security.jgss.initiate {
 com.sun.security.auth.module.Krb5LoginModule required
 renewTGT=true
 doNotPrompt=true
 useKeyTab=true
 keyTab="${KNOX_GATEWAY_HOME}/conf/knox.keytab"
 principal="${KNOX_KERBEROS_PRINCIPAL}"
 isInitiator=true
 storeKey=true
 useTicketCache=true
 client=true;
};
EOF
# Make sure EOF keyword below start at start of the line.
}

_updateKerberosInfoInGatewaySiteXML()
{
    # We need to update two parameters in gateway-site.xml
    # gateway.hadoop.kerberos.secured, java.security.krb5.conf and java.security.auth.login.config properties

    KNOX_GATEWAY_SITE_XML="${KNOX_GATEWAY_HOME}/conf/gateway-site.xml"
    ${XMLSTARLET} ed -L -u "/configuration/property[name='gateway.hadoop.kerberos.secured']/value" -v true ${KNOX_GATEWAY_SITE_XML}
    ${XMLSTARLET} ed -L -u "/configuration/property[name='java.security.krb5.conf']/value" -v ${KNOX_GATEWAY_HOME}/conf/krb5.conf ${KNOX_GATEWAY_SITE_XML}
    ${XMLSTARLET} ed -L -u "/configuration/property[name='java.security.auth.login.config']/value" -v ${KNOX_GATEWAY_HOME}/conf/krb5JAASLogin.conf ${KNOX_GATEWAY_SITE_XML}

}

_startKnoxGateway()
{
    cd ${KNOX_GATEWAY_HOME}/bin/;
    ./gateway.sh start
    if [ "$?" = "0" ]; then
       echo "Knox gateway started successfully."
    else
       echo "ERROR : Knox gateway failed to start"
       exit 99
    fi
}
####MAIN#######

if [ "$#" -ne 13 ]; then
  echo "usage: knox-install.sh LDAP_HOST_NAME LDAP_PORT LDAP_BIND_USERNAME LDAP_BIND_USER_PASSWORD LDAP_SEARCH_BASE LDAP_USER_SEARCH_ATTRIBUTE_NAME \
               LDAP_USER_OBJECT_CLASS LDAP_GROUP_SEARCH_BASE LDAP_GROUP_OBJECT_CLASS LDAP_MEMBER_ATTRIBUTE TEMP_S3_BUCKET KNOX_KERBEROS_PRINCIPAL EMR_MASTER_MACHINE"
  exit 1
fi

LDAP_HOST_NAME="${1}"
LDAP_PORT="${2}"
LDAP_BIND_USERNAME="${3}"
LDAP_BIND_USER_PASSWORD="${4}"
LDAP_SEARCH_BASE="${5}"
LDAP_USER_SEARCH_ATTRIBUTE_NAME="${6}"
LDAP_USER_OBJECT_CLASS="${7}"
LDAP_GROUP_SEARCH_BASE="${8}"
LDAP_GROUP_OBJECT_CLASS="${9}"
LDAP_MEMBER_ATTRIBUTE="${10}"
TEMP_S3_BUCKET="${11}"
KNOX_KERBEROS_PRINCIPAL="${12}"
EMR_MASTER_MACHINE="${13}"

RDS_HOSTNAME="{14}"
RDS_ROOT_USERNAME="${15}"
RDS_ROOT_PASSWORD="${16}"



: <<'COMMENT'
LDAP_HOST_NAME="10.0.1.235"
LDAP_PORT="389"
LDAP_BIND_USERNAME="CN=AWS ADMIN,CN=Users,DC=awshadoop,DC=com"
LDAP_BIND_USER_PASSWORD="CheckSum123"
LDAP_SEARCH_BASE="CN=Users,DC=awshadoop,DC=com"
LDAP_USER_SEARCH_ATTRIBUTE_NAME="sAMAccountName"
LDAP_USER_OBJECT_CLASS="person"
LDAP_GROUP_SEARCH_BASE="dc=awshadoop,dc=com"
LDAP_GROUP_OBJECT_CLASS="group"
LDAP_MEMBER_ATTRIBUTE="member"
TEMP_S3_BUCKET="s3://skkodali-proserve/knox-blog"
KNOX_KERBEROS_PRINCIPAL="knox/ip-10-0-1-25.ec2.internal@EC2.INTERNAL"
EMR_MASTER_MACHINE="ip-10-0-1-25.ec2.internal"
COMMENT
#### CALLING FUNCTIONS ####

_setEnv
_downloadAndInstallJDKFromS3Bucket
_installRequiredRPMs
_createKnoxUser
_downloadAndInstallKnoxSoftware
_createKnoxMasterSecret
_updateKnoxGatewayPortInGatewaySiteXML
_createATopologyFile
_downloadKeyTabAndKRB5FilesFromS3Bucket
_createkrb5JAASLoginCOnfFile
_updateKerberosInfoInGatewaySiteXML
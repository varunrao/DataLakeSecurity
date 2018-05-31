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

    RANGER_S3_BUCKET="s3://skkodali-public/blogs/apache-ranger"
    SOLR_SOFTWARE_VERSION="7.3.1"
    SOLR_SOFTWARE_LOCATION="s3://skkodali-public/blogs/solr"
    RANGER_UNIX_USERNAME="ranger"
    RANGER_UNIX_GROUPNAME="ranger"
    RANGER_USER_HOME="/home/ranger"
    EC2_USER="ec2-user"

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
  SQL_CON=`${MYSQL} -h ${RDS_HOSTNAME} -u ${RDS_ROOT_USERNAME} -p${RDS_ROOT_PASSWORD} -e 'exit'`
  if ! [  $? == "0" ]; then
    echo "SQL Connection to RDS Mysql database is NOT successful."
    echo "******** Exiting the setup script......"
    exit 99
  else
    echo "SQL Connection to RDS MySQL database is successful....Continuing"
  fi
}
_downloadAndInstallRangerSoftwareFromS3()
{
    cd;
    mkdir apache-ranger; cd apache-ranger;
    aws s3 cp ${RANGER_S3_BUCKET} . --recursive
}
_setupRangerAdminsAndOtherPlugins()
{
    cd /usr/local/
    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-admin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-admin ranger-admin

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-hbase-plugin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-hbase-plugin ranger-habse-plugin

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-hive-plugin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-hive-plugin ranger-hive-plugin

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-hdfs-plugin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-hdfs-plugin ranger-hdfs-plugin

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-knox-plugin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-knox-plugin ranger-knox-plugin

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-ranger-tools.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-ranger-tools ranger-tools

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-usersync.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-usersync ranger-usersync

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-yarn-plugin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-yarn-plugin ranger-yarn-plugin

}
_downloadAndInstallAndStartSolr()
{
    cd; mkdir solr; cd solr;
    ${AWS} ${S3_COPY} ${SOLR_SOFTWARE_LOCATION} . --recursive
    unzip solr-${SOLR_SOFTWARE_VERSION}.zip
    cd ~/solr/solr-${SOLR_SOFTWARE_VERSION}/bin
    export JAVA_HOME=/usr/java/latest
    ./solr start -p 8983
}

_generateSQLGrantsAndCreateUser()
{
    touch ~/generate_grants.sql
    HOSTNAMEI=`hostname -I`
    HOSTNAMEI=`echo ${HOSTNAMEI}`
    cat >~/generate_grants.sql <<EOF
CREATE USER '${RDS_RANGER_SCHEMA_DBUSER}'@'localhost' IDENTIFIED BY '${RDS_RANGER_SCHEMA_DBPASSWORD}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'localhost';
CREATE USER '${RDS_RANGER_SCHEMA_DBUSER}'@'%' IDENTIFIED BY '${RDS_RANGER_SCHEMA_DBPASSWORD}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'%';
CREATE USER '${RDS_RANGER_SCHEMA_DBUSER}'@'${HOSTNAMEI}' IDENTIFIED BY '${RDS_RANGER_SCHEMA_DBPASSWORD}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'${HOSTNAMEI}';
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'${HOSTNAMEI}' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON \`%\`.* TO '${RDS_RANGER_SCHEMA_DBUSER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
exit
EOF

}
_setupMySQLDatabaseAndPrivileges()
{
    HOSTNAMEI=`hostname -I`
    ${MYSQL} -h ${RDS_HOSTNAME} -u ${RDS_ROOT_USERNAME} -p${RDS_ROOT_PASSWORD} < ~/generate_grants.sql
    echo $?
}

_updateRangerAdminProperties()
{

    cd /usr/local/ranger-admin;
    #sudo cp install.properties install.properties.orig
    #sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=$installpath/$mysql_jar|g" install.properties
    sudo sed -i "s|db_root_user=.*|db_root_user=${RDS_ROOT_USERNAME}|g" install.properties
    sudo sed -i "s|db_root_password=.*|db_root_password=${RDS_ROOT_PASSWORD}|g" install.properties
    sudo sed -i "s|db_host=.*|db_host=${RDS_HOSTNAME}|g" install.properties

    sudo sed -i "s|db_name=.*|db_name=${RDS_RANGER_SCHEMA_DBNAME}|g" install.properties
    sudo sed -i "s|db_user=.*|db_user=${RDS_RANGER_SCHEMA_DBUSER}|g" install.properties
    sudo sed -i "s|db_password=.*|db_password=${RDS_RANGER_SCHEMA_DBPASSWORD}|g" install.properties

    sudo sed -i "s|audit_db_password=.*|audit_db_password=rangerlogger|g" install.properties
    sudo sed -i "s|audit_store=.*|audit_store=solr|g" install.properties
    sudo sed -i "s|audit_solr_urls=.*|audit_solr_urls=http://localhost:8983/solr/ranger_audits|g" install.properties
    #sudo sed -i "s|policymgr_external_url=.*|policymgr_external_url=http://$hostname:6080|g" install.properties


    sudo sed -i "s|authentication_method=.*|authentication_method=LDAP|g" install.properties
    sudo sed -i "s|xa_ldap_url=.*|xa_ldap_url=${LDAP_SERVER_URL}|g" install.properties
    sudo sed -i "s|xa_ldap_userDNpattern=.*|xa_ldap_userDNpattern=${LDAP_USERDNPATTERN}|g" install.properties
    sudo sed -i "s|xa_ldap_groupSearchBase=.*|xa_ldap_groupSearchBase=${LDAP_GROUP_SEARCH_BASE}|g" install.properties
    sudo sed -i "s|xa_ldap_groupSearchFilter=.*|xa_ldap_groupSearchFilter=${LDAP_GROUP_SEARCHFILTER}|g" install.properties
    sudo sed -i "s|xa_ldap_groupRoleAttribute=.*|xa_ldap_groupRoleAttribute=${LDAP_GROUP_ROLEATTRIBUTE}|g" install.properties
    sudo sed -i "s|xa_ldap_base_dn=.*|xa_ldap_base_dn=${LDAP_BASE_DN}|g" install.properties
    sudo sed -i "s|xa_ldap_bind_dn=.*|xa_ldap_bind_dn=${LDAP_BIND_DN}|g" install.properties
    sudo sed -i "s|xa_ldap_bind_password=.*|xa_ldap_bind_password=${LDAP_BIND_USER_PASSWORD}|g" install.properties
    sudo sed -i "s|xa_ldap_referral=.*|xa_ldap_referral=${LDAP_REFERRAL}|g" install.properties
    sudo sed -i "s|xa_ldap_userSearchFilter=.*|xa_ldap_userSearchFilter=${LDAP_USER_SEARCH_FILTER}|g" install.properties

}


_startRangerAdmin()
{
    cd /usr/local/ranger-admin;
    export JAVA_HOME=/usr/java/latest
    sudo -E ./setup.sh
    sudo -E ./set_globals.sh
    cd /usr/bin
    sudo ln -sf /usr/local/ranger-admin/ews/start-ranger-admin.sh ranger-admin-start
    sudo ln -sf /usr/local/ranger-admin/ews/stop-ranger-admin.sh ranger-admin-stop
    cd /usr/local/ranger-admin;
    sudo -E ./setup.sh
    sudo service ranger-admin start
}

_updateRangerUserSyncProperties()
{

    cd /usr/local/ranger-usersync;
    HOSTNAMEI=`hostname -I`
    HOSTNAMEI=`echo ${HOSTNAMEI}`
    #sudo cp install.properties install.properties.orig
    #sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=$installpath/$mysql_jar|g" install.properties
    sudo sed -i "s|logdir=.*|logdir=/var/log/ranger/usersync|g" install.properties
    sudo sed -i "s|POLICY_MGR_URL=.*|POLICY_MGR_URL=http://${HOSTNAMEI}:6080|g" install.properties
    sudo sed -i "s|SYNC_SOURCE=.*|SYNC_SOURCE=ldap|g" install.properties

    sudo sed -i "s|SYNC_LDAP_URL=.*|SYNC_LDAP_URL=${LDAP_SERVER_URL}|g" install.properties
    sudo sed -i "s|SYNC_LDAP_BIND_DN=.*|SYNC_LDAP_BIND_DN=${LDAP_BIND_DN}|g" install.properties
    sudo sed -i "s|SYNC_LDAP_BIND_PASSWORD=.*|SYNC_LDAP_BIND_PASSWORD=${LDAP_BIND_USER_PASSWORD}|g" install.properties

    sudo sed -i "s|SYNC_LDAP_SEARCH_BASE=.*|SYNC_LDAP_SEARCH_BASE=${LDAP_GROUP_SEARCH_BASE}|g" install.properties
    sudo sed -i "s|SYNC_LDAP_USER_SEARCH_BASE=.*|SYNC_LDAP_USER_SEARCH_BASE=${LDAP_GROUP_SEARCH_BASE}|g" install.properties
    sudo sed -i "s|SYNC_LDAP_USER_SEARCH_FILTER=.*|SYNC_LDAP_USER_SEARCH_FILTER=${LDAP_USER_SYNC_SEARCH_FILTER}|g" install.properties

    sudo sed -i "s|SYNC_LDAP_USER_NAME_ATTRIBUTE=.*|SYNC_LDAP_USER_NAME_ATTRIBUTE=${LDAP_USER_NAME_SYNC_ATTRIBUTE}|g" install.properties
    sudo sed -i "s|SYNC_INTERVAL=.*|SYNC_INTERVAL=2|g" install.properties
    sudo sed -i "s|SYNC_LDAP_REFERRAL=.*|SYNC_LDAP_REFERRAL=follow|g" install.properties

}

_startRangerUserSync()
{
    cd /usr/local/ranger-usersync;
    export JAVA_HOME=/usr/java/latest
    sudo -E ./setup.sh

    sudo mkdir -p /var/log/usersync
    sudo ln -s /var/log/ranger/usersync/ logs

    cd /usr/bin
    sudo service ranger-usersync start

}

####MAIN#######
: <<'COMMENT'
if [ "$#" -ne 19 ]; then
  echo "usage: ranger-install.sh RDS_HOSTNAME \
                RDS_ROOT_USERNAME \
                RDS_ROOT_PASSWORD \
                RDS_RANGER_SCHEMA_DBNAME \
                RDS_RANGER_SCHEMA_DBUSER \
                RDS_RANGER_SCHEMA_DBPASSWORD \

                LDAP_HOST_NAME \
                LDAP_PORT \
                LDAP_USERDNPATTERN \
                LDAP_GROUP_SEARCH_BASE \
                LDAP_GROUP_SEARCHFILTER \
                LDAP_GROUP_ROLEATTRIBUTE \
                LDAP_BASE_DN \
                LDAP_BIND_DN \
                LDAP_BIND_USER_PASSWORD \
                LDAP_REFERRAL \
                LDAP_USER_SEARCH_FILTER \
                LDAP_USER_SYNC_SEARCH_FILTER \
                LDAP_USER_NAME_SYNC_ATTRIBUTE \
                "
  exit 1
fi


RDS_HOSTNAME="{1}"
RDS_ROOT_USERNAME="${2}"
RDS_ROOT_PASSWORD="${3}"

RDS_RANGER_SCHEMA_DBNAME="${4}"
RDS_RANGER_SCHEMA_DBUSER="${5}"
RDS_RANGER_SCHEMA_DBPASSWORD="${6}"

LDAP_HOST_NAME="${7}"
LDAP_PORT="${8}"
LDAP_USERDNPATTERN="${9}"
LDAP_GROUP_SEARCH_BASE="${10}"
LDAP_GROUP_SEARCHFILTER="${11}"
LDAP_GROUP_ROLEATTRIBUTE="${12}"
LDAP_BASE_DN="${13}"
LDAP_BIND_DN="${14}"
LDAP_BIND_USER_PASSWORD="${15}"
LDAP_REFERRAL="${16}"
LDAP_USER_SEARCH_FILTER="${17}"
LDAP_USER_SYNC_SEARCH_FILTER="${18}"
LDAP_USER_NAME_SYNC_ATTRIBUTE="${19}"
#LDAP_BIND_USERNAME="${9}"

LDAP_SERVER_URL="ldap://${LDAP_HOST_NAME}:${LDAP_PORT}"
COMMENT

RDS_HOSTNAME="rangerwork.cxyqwul72jqt.us-east-1.rds.amazonaws.com"
RDS_ROOT_USERNAME="root"
RDS_ROOT_PASSWORD="Rootroot123"

RDS_RANGER_SCHEMA_DBNAME="rangerdb"
RDS_RANGER_SCHEMA_DBUSER="rangeradmin"
RDS_RANGER_SCHEMA_DBPASSWORD="rangeradmin"

LDAP_HOST_NAME="10.0.1.82"
LDAP_PORT="389"
LDAP_USERDNPATTERN="uid={0},ou=users,DC=awsknox,DC=com"
LDAP_GROUP_SEARCH_BASE="dc=awsknox,dc=com"
LDAP_GROUP_SEARCHFILTER="objectclass=group"
LDAP_GROUP_ROLEATTRIBUTE="cn"
LDAP_BASE_DN="DC=awsknox,DC=com"
LDAP_BIND_DN="awsadmin@awsknox.com"
LDAP_BIND_USER_PASSWORD="CheckSum123"
LDAP_REFERRAL="ignore"
LDAP_USER_SEARCH_FILTER="(sAMAccountName={0})"
LDAP_USER_SYNC_SEARCH_FILTER="sAMAccountName=*"
LDAP_USER_NAME_SYNC_ATTRIBUTE="sAMAccountName"
LDAP_SERVER_URL="ldap://${LDAP_HOST_NAME}:${LDAP_PORT}"
#LDAP_BIND_USERNAME="CN=AWS ADMIN,CN=Users,DC=awsknox,DC=com"

#### CALLING FUNCTIONS ####

_setEnv
#_installRequiredRPMs
#_Check_MySql_Sql_Connection
#_downloadAndInstallRangerSoftwareFromS3
#_setupRangerAdminsAndOtherPlugins
#_downloadAndInstallAndStartSolr
#_generateSQLGrantsAndCreateUser
#_setupMySQLDatabaseAndPrivileges
#_updateRangerAdminProperties
#_startRangerAdmin
_updateRangerUserSyncProperties
_startRangerUserSync
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
    KEY_TAB_LOCATION="/mnt/var/lib/bigtop_keytabs/"
    MYSQL_CONNECTOR_JAR="/usr/share/java/mysql-connector-java.jar"

    RANGER_ADMIN_KEYTAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangeradmin.keytab"
    RANGER_LOOKUP_KEYTAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangerlookup.keytab"
    RANGER_USERSYNC_KEYTAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangerusersync.keytab"
    RANGER_TAGSYNC_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangertagsync.keytab"

    FULL_HOSTNAME=`hostname -f`
    DOMAIN_NAME="EC2.INTERNAL"
    RANGER_ADMIN_FQDN="ip-10-0-1-67.ec2.internal"

}
_installRequiredRPMs()
{
    sudo yum install -y mysql-connector-java
    sudo yum -y install mysql-server
    sudo yum install -y git
    sudo yum -y install gcc
}

_createRangerPluginsPrincipals()
{

: <<'COMMENT'
    ### The below get-user command was run in windows powershell (In AD server). Make sure this user "rangerlookup" was created in AD.
    ### From this output notedown the "UserPrincipalName : rangerlookup@awsknox.com"

    PS C:\Users\Administrator> get-aduser rangerlookup
    DistinguishedName : CN=RangerLookup,CN=Users,DC=awsknox,DC=com
    Enabled           : True
    GivenName         : Ranger
    Name              : RangerLookup
    ObjectClass       : user
    ObjectGUID        : 20fcb397-fb12-4601-9841-9c449cdab459
    SamAccountName    : rangerlookup
    SID               : S-1-5-21-1099734870-3676000271-2251895312-1107
    Surname           : Lookup
    UserPrincipalName : rangerlookup@awsknox.com
COMMENT

    # For Ranger Tagsync
    echo "addprinc -pw rangerlookup rangerlookup@awsknox.com" | sudo kadmin.local > /dev/null
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

    sudo tar zxf ~/apache-ranger/ranger/target/ranger-1.0.1-SNAPSHOT-yarn-plugin.tar.gz
    sudo ln -s ranger-1.0.1-SNAPSHOT-yarn-plugin ranger-yarn-plugin

}

_updateRangerHDFSPluginProperties()
{
    cd /usr/local/ranger-hdfs-plugin;
    sudo sed -i "s|POLICY_MGR_URL=.*|POLICY_MGR_URL=http://${RANGER_ADMIN_FQDN}:6080|g" install.properties
    sudo sed -i "s|REPOSITORY_NAME=.*|REPOSITORY_NAME=hadoopdev|g" install.properties
}

_startHDFSPlugin()
{
    cd /usr/local/ranger-hdfs-plugin;
    export JAVA_HOME=/usr/java/latest
    sudo -E ./setup.sh
    cd /usr/bin
    sudo service ranger-usersync start
}

_updateRangerHivePluginProperties()
{
    cd /usr/local/ranger-hive-plugin;
    HOSTNAMEI=`hostname -I`
    HOSTNAMEI=`echo ${HOSTNAMEI}`

    sudo sed -i "s|POLICY_MGR_URL =.*|POLICY_MGR_URL=http://${HOSTNAMEI}:6080|g" install.properties
    sudo sed -i "s|XAAUDIT.DB.HOSTNAME=.*|XAAUDIT.DB.HOSTNAME=localhost|g" install.properties
    sudo sed -i "s|XAAUDIT.DB.DATABASE_NAME=.*|XAAUDIT.DB.DATABASE_NAME=ranger_audit|g" install.properties
    sudo sed -i "s|XAAUDIT.DB.USER_NAME=.*|XAAUDIT.DB.USER_NAME=rangerlogger|g" install.properties
    sudo sed -i "s|XAAUDIT.DB.PASSWORD=.*|XAAUDIT.DB.PASSWORD=rangerlogger|g" install.properties
    sudo sed -i "s|SQL_CONNECTOR_JAR=.*|SQL_CONNECTOR_JAR=${MYSQL_CONNECTOR_JAR}|g" install.properties
    sudo sed -i "s|REPOSITORY_NAME=.*|REPOSITORY_NAME=hadoopdev|g" install.properties
    sudo sed -i "s|XAAUDIT.SOLR.URL=.*|XAAUDIT.SOLR.URL=http://${HOSTNAMEI}:8983/solr/ranger_audits|g" install.properties
    sudo sed -i "s|XAAUDIT.SOLR.SOLR_URL=.*|XAAUDIT.SOLR.SOLR_URL=http://${HOSTNAMEI}:8983/solr/ranger_audits|g" install.properties
    sudo sed -i "s|XAAUDIT.SOLR.ENABLE=.*|XAAUDIT.SOLR.ENABLE=true|g" install.properties
    sudo sed -i "s|XAAUDIT.DB.IS_ENABLED=.*|XAAUDIT.DB.IS_ENABLED=true|g" install.properties
    sudo sed -i "s|XAAUDIT.DB.HOSTNAME=.*|XAAUDIT.DB.HOSTNAME=${HOSTNAMEI}|g" install.properties
}

_startHivePlugin()
{
    cd /usr/local/ranger-hive-plugin;
    export JAVA_HOME=/usr/java/latest
    sudo -E ./enable-hive-plugin.sh
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
                TEMP_S3_LOCATION \
                EMR_MASTER_MACHINE \
                DOMAIN_NAME \
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
TEMP_S3_LOCATION="${20}"
EMR_MASTER_MACHINE="${21}"
DOMAIN_NAME="${22}"
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
TEMP_S3_LOCATION="s3://skkodali-public/blogs/keytab-files"
EMR_MASTER_MACHINE="ip-10-0-1-25.ec2.internal"
DOMAIN_NAME="EC2.INTERNAL"

#LDAP_BIND_USERNAME="CN=AWS ADMIN,CN=Users,DC=awsknox,DC=com"

#### CALLING FUNCTIONS ####

_setEnv
#_installRequiredRPMs
#_downloadAndInstallRangerSoftwareFromS3
_setupRangerAdminsAndOtherPlugins
_updateRangerHDFSPluginProperties
#_downloadAndInstallAndStartSolr
#_generateSQLGrantsAndCreateUser
#_setupMySQLDatabaseAndPrivileges
#_downloadKeyTabAndKRB5FilesFromS3Bucket
#_updateRangerAdminProperties
#_startRangerAdmin
#_updateRangerUserSyncProperties
#_startRangerUserSync
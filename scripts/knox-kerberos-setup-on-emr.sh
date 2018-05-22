#!/usr/bin/env bash

# @skkodali

_usage()
{
    echo "sh -x knox-kerberos-setup-on-emr.sh s3://skkodali-proserve/knox-blog 389 'CN=AWS ADMIN,CN=Users,DC=awshadoop,DC=com' \
            'CheckSum123' 'CN=Users,DC=awshadoop,DC=com' \
            'sAMAccountName' 'person' 'dc=awshadoop,dc=com' 'group' 'member' \
         "
}
_setEnv()
{
    AWS=aws
    S3_COPY="s3 cp"
    #OUTPUT_FILE="${SCRIPTS_HOME}/log-files/log_`date '+%Y-%m-%d-%H-%M-%S'`.out"

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
    KNOX_KEYYAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/knox.keytab"
    FULL_HOSTNAME=`hostname -f`
    DOMAIN_NAME="EC2.INTERNAL"
}

_createKnoxPrincipal()
{
    echo "addprinc -randkey knox/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null
    echo "ktadd -k ${KNOX_KEYYAB_FILE_PATH_NAME} -norandkey knox/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null
}

_uploadKeyTabAndKRB5FilesToS3Bucket()
{
    # We need to copy the krb5.conf and keytab files from EMR master machine to Knox ec2 instance's ${KNOX_GATEWAY_HOME}/conf/ directory.
    # To copy the files from one ec2 instance to other instance, requires .pem file.
    # To avoid this, we will upload the keytab file to S3 bucket first.
    # Then download the keytab file from S3 to Knox's ec2 instance using aws s3 cp command - This will be part of the shell script that will run on Knox's instance.
    # Instead of doing these steps automatically, you can manually copy this file as well.
    # To demonstrate the automate process, we are following this method.

    #
    sudo ${AWS} ${S3_COPY} ${KNOX_KEYYAB_FILE_PATH_NAME} ${TEMP_S3_BUCKET_PATH}/
    sudo ${AWS} ${S3_COPY} /etc/krb5.conf ${TEMP_S3_BUCKET_PATH}/

}

####MAIN#######

# if [ "$#" -ne 1 ]; then
#  echo "usage: read_individual_files.sh TABLE_NAME FILE_TO_LOAD ORA_USERNAME ORA_PASSWORD ORA_TNS_SID"
#  exit 1
# fi

: <<'COMMENT'
TEMP_S3_BUCKET_PATH="${1}"
LDAP_PORT="${2}"
LDAP_BIND_USERNAME="${3}"
LDAP_BIND_USER_PASSWORD="${4}"
LDAP_SEARCH_BASE="${5}"
LDAP_USER_SEARCH_ATTRIBUTE_NAME="${6}"
LDAP_USER_OBJECT_CLASS="${7}"
LDAP_GROUP_SEARCH_BASE="${8}"
LDAP_GROUP_OBJECT_CLASS="${9}"
LDAP_MEMBER_ATTRIBUTE="${10}"
COMMENT

TEMP_S3_BUCKET_PATH="s3://skkodali-proserve/knox-blog"
LDAP_PORT="389"
LDAP_BIND_USERNAME="CN=AWS ADMIN,CN=Users,DC=awshadoop,DC=com"
LDAP_BIND_USER_PASSWORD="CheckSum123"
LDAP_SEARCH_BASE="CN=Users,DC=awshadoop,DC=com"
LDAP_USER_SEARCH_ATTRIBUTE_NAME="sAMAccountName"
LDAP_USER_OBJECT_CLASS="person"
LDAP_GROUP_SEARCH_BASE="dc=awshadoop,dc=com"
LDAP_GROUP_OBJECT_CLASS="group"
LDAP_MEMBER_ATTRIBUTE="member"


#### CALLING FUNCTIONS ####

_setEnv
_createKnoxPrincipal
_uploadKeyTabAndKRB5FilesToS3Bucket
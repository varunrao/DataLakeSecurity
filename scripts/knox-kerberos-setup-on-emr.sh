#!/usr/bin/env bash

# @skkodali

_usage()
{
    echo "sh -x knox-kerberos-setup-on-emr.sh s3://skkodali-proserve/knox-blog"

}
_setEnv()
{
    AWS=aws
    S3_COPY="s3 cp"
    #OUTPUT_FILE="${SCRIPTS_HOME}/log-files/log_`date '+%Y-%m-%d-%H-%M-%S'`.out"
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
#  echo "usage: read_individual_files.sh TEMP_S3_BUCKET_PATH"
#  exit 1
# fi


TEMP_S3_BUCKET_PATH="${1}"

# TEMP_S3_BUCKET_PATH="s3://skkodali-proserve/knox-blog"

#### CALLING FUNCTIONS ####

_setEnv
_createKnoxPrincipal
_uploadKeyTabAndKRB5FilesToS3Bucket
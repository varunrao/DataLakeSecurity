#!/usr/bin/env bash

# @skkodali

_usage()
{
    echo "sh -x ranger-kerberos-setup-on-emr.sh"

}
_setEnv()
{

    AWS=aws
    S3_COPY="s3 cp"

    RANGER_ADMIN_KEYTAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangeradmin.keytab"
    RANGER_LOOKUP_KEYTAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangerlookup.keytab"
    RANGER_USERSYNC_KEYTAB_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangerusersync.keytab"
    RANGER_TAGSYNC_FILE_PATH_NAME="/mnt/var/lib/bigtop_keytabs/rangertagsync.keytab"

    SPNEGO_KEYTAB="/mnt/var/lib/bigtop_keytabs/HTTP.keytab"

    FULL_HOSTNAME=`hostname -f`
    DOMAIN_NAME="EC2.INTERNAL"

    RANGER_UNIX_USERNAME="ranger"
    RANGER_UNIX_GROUPNAME="ranger"
    RANGER_USER_HOME="/home/ranger"
    EC2_USER="ec2-user"

}

_createRangerPrincipals()
{
    # For Ranger Admin
    echo "addprinc -randkey rangeradmin/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null
    echo "ktadd -k ${RANGER_ADMIN_KEYTAB_FILE_PATH_NAME} -norandkey rangeradmin/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null

    # For Ranger Lookup
    echo "addprinc -randkey rangerlookup/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null
    echo "ktadd -k ${RANGER_LOOKUP_KEYTAB_FILE_PATH_NAME} -norandkey rangerlookup/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null

    # For Ranger Usersync
    echo "addprinc -randkey rangerusersync/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null
    echo "ktadd -k ${RANGER_USERSYNC_KEYTAB_FILE_PATH_NAME} -norandkey rangerusersync/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null

    # For Ranger Tagsync
    echo "addprinc -randkey rangertagsync/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null
    echo "ktadd -k ${RANGER_TAGSYNC_FILE_PATH_NAME} -norandkey rangertagsync/${FULL_HOSTNAME}@${DOMAIN_NAME}" | sudo kadmin.local > /dev/null

}

_uploadKeyTabAndKRB5FilesToS3Bucket()
{
    # We need to copy the keytab files from EMR master machine to ranger ec2 instance's directory in some location.
    # In this case, we will copy in "/mnt/var/lib/bigtop_keytabs/" in Ranger instance.
    # We are installing Ranger and Knox on the same ec2 instance, and it is not part of the EMR cluster.
    # So we need to create "/mnt/var/lib/bigtop_keytabs/" directory on the ranger instance.
    # To copy the files from one ec2 instance to other instance, requires .pem file.
    # To avoid this, we will upload the keytab file to S3 bucket first.
    # Then download the keytab file from S3 to Knox's ec2 instance using aws s3 cp command - This will be part of the shell script that will run on Knox's instance.
    # Instead of doing these steps automatically, you can manually copy this file as well.
    # To demonstrate the automate process, we are following this method.

    #
    sudo ${AWS} ${S3_COPY} ${RANGER_ADMIN_KEYTAB_FILE_PATH_NAME} ${TEMP_S3_BUCKET_PATH}/
    sudo ${AWS} ${S3_COPY} ${RANGER_LOOKUP_KEYTAB_FILE_PATH_NAME} ${TEMP_S3_BUCKET_PATH}/
    sudo ${AWS} ${S3_COPY} ${RANGER_USERSYNC_KEYTAB_FILE_PATH_NAME} ${TEMP_S3_BUCKET_PATH}/
    sudo ${AWS} ${S3_COPY} ${RANGER_TAGSYNC_FILE_PATH_NAME} ${TEMP_S3_BUCKET_PATH}/
    sudo ${AWS} ${S3_COPY} ${SPNEGO_KEYTAB} ${TEMP_S3_BUCKET_PATH}/
}

####MAIN#######

# if [ "$#" -ne 1 ]; then
#  echo "usage: read_individual_files.sh TEMP_S3_BUCKET_PATH"
#  exit 1
# fi

: <<'COMMENT'
TEMP_S3_BUCKET_PATH="${1}"
COMMENT

TEMP_S3_BUCKET_PATH="s3://skkodali-public/blogs/keytab-files"

#### CALLING FUNCTIONS ####

_setEnv
_createRangerPrincipals
_uploadKeyTabAndKRB5FilesToS3Bucket
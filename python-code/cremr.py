import crhelper
import boto3

# initialise logger
logger = crhelper.log_config({"RequestId": "CONTAINER_INIT"})
logger.info("Logging configured")
# set global to track init failures
init_failed = False

try:
    # Place initialization code here
    logger.info("Container initialization completed")
except Exception as e:
    logger.error(e, exc_info=True)
    init_failed = e


def create(event, context):
    apps = event["ResourceProperties"]["AppsEMR"]
    formatted_applist = apps.split(",")
    applist = []
    for app in formatted_applist:
        applist.append({"Name": app.strip()})

    try:
        client = boto3.client("emr", region_name=event["ResourceProperties"]["StackRegion"])
        cluster_id = client.run_job_flow(
            Name="CustomResourceCluster",
            ReleaseLabel="emr-5.11.0",
            Instances={
                "InstanceGroups": [
                    {
                        "Name": "Master nodes",
                        "Market": "ON_DEMAND",
                        "InstanceRole": "MASTER",
                        "InstanceType": event["ResourceProperties"]["TypeOfInstance"],
                        "InstanceCount": 1,
                    },
                    {
                        "Name": "Slave nodes",
                        "Market": "ON_DEMAND",
                        "InstanceRole": "CORE",
                        "InstanceType": event["ResourceProperties"]["TypeOfInstance"],
                        "InstanceCount": int(event["ResourceProperties"]["InstanceCount"])
                    }
                ],
                "Ec2KeyName": event["ResourceProperties"]["KeyName"],
                "KeepJobFlowAliveWhenNoSteps": True,
                "TerminationProtected": False,
                "Ec2SubnetId": event["ResourceProperties"]["subnetID"],
                "EmrManagedMasterSecurityGroup": event["ResourceProperties"]["masterSG"],
                "EmrManagedSlaveSecurityGroup": event["ResourceProperties"]["slaveSG"]
            },
            BootstrapActions=[
                {
                    "Name": "create-hfds-home",
                    "ScriptBootstrapAction": {
                        "Path": "s3://aws-bigdata-blog/artifacts/emr-kerberos-ad/create-hdfs-home-ba.sh"
                    }
                },
            ],
            Applications=applist,
            Steps=[
                {
                    "Name": "CFN-SIGNAL-STEP",
                    "ActionOnFailure": "CONTINUE",
                    "HadoopJarStep": {
                        "Jar": "s3://elasticmapreduce/libs/script-runner/script-runner.jar",
                        "Args": [
                            "s3://aws-bigdata-blog/artifacts/emr-kerberos-ad/send-cf-signal.sh",
                            event["ResourceProperties"]["SignalURL"]
                        ]
                    }
                },
                {
                    "Name": "KNOX-KERBEROS-SETUP",
                    "ActionOnFailure": "CONTINUE",
                    "HadoopJarStep": {
                        "Jar": "s3://elasticmapreduce/libs/script-runner/script-runner.jar",
                        "Args": [
                            "s3://skkodali-proserv-us-west-2/knox-blog/scripts/knox/knox-kerberos-setup-on-emr.sh",
                            event["ResourceProperties"]["TempS3Location"]
                        ]
                    }
                },
            ],
            VisibleToAllUsers=True,
            JobFlowRole=event["ResourceProperties"]["JobFlowRole"],
            ServiceRole=event["ResourceProperties"]["ServiceRole"],
            Tags=[
                {
                    "Key": "Name",
                    "Value": "CustomerResourceTestLaunch"
                }
            ],
            SecurityConfiguration=event["ResourceProperties"]["EMRSecurityConfig"],
            KerberosAttributes={
                "Realm": event["ResourceProperties"]["KerberosRealm"],
                "KdcAdminPassword": event["ResourceProperties"]["CrossRealmPass"],
                "CrossRealmTrustPrincipalPassword": event["ResourceProperties"]["CrossRealmPass"],
                "ADDomainJoinUser": event["ResourceProperties"]["ADDomainUser"],
                "ADDomainJoinPassword": event["ResourceProperties"]["ADDomainUserPassword"]
            },
            Configurations=[
                {
                    "Classification": "core-site",
                    "Properties": {
                        "hadoop.proxyuser.knox.groups": "*",
                        "hadoop.proxyuser.knox.hosts": "*"
                    }
                },
                {
                    "Classification": "hive-site",
                    "Properties": {
                        "hive.server2.allow.user.substitution": "true",
                        "hive.server2.transport.mode": "http",
                        "hive.server2.thrift.http.port": "10001",
                        "hive.server2.thrift.http.path": "cliservice"
                    }
                },
                {
                    "Classification": "hcatalog-webhcat-site",
                    "Properties": {
                        "webhcat.proxyuser.knox.groups": "*",
                        "webhcat.proxyuser.knox.hosts": "*"
                    }
                },
                {
                    "Classification": "oozie-site",
                    "Properties": {
                        "oozie.service.ProxyUserService.proxyuser.knox.groups": "*",
                        "oozie.service.ProxyUserService.proxyuser.knox.hosts": "*"
                    }
                }
            ]
        )

        physical_resource_id = cluster_id["JobFlowId"]
        response_data = {
            "ClusterID": cluster_id["JobFlowId"]
        }
        return physical_resource_id, response_data

    except Exception as E:
        raise


def update(event, context):
    """
    Place your code to handle Update events here

    To return a failure to CloudFormation simply raise an exception, the exception message will be sent to
    CloudFormation Events.
    """
    physical_resource_id = event["PhysicalResourceId"]
    response_data = {}
    return physical_resource_id, response_data


def delete(event, context):
    client = boto3.client("emr", region_name=event["ResourceProperties"]["StackRegion"])

    deleteresponse = client.terminate_job_flows(
        JobFlowIds=[
            event["PhysicalResourceId"]
        ]
    )

    response = client.describe_cluster(
        ClusterId=event["PhysicalResourceId"]
    )
    status = response["Cluster"]["Status"]["State"]

    response_data = {
        "ClusterStatus": status
    }

    return response_data


def handler(event, context):
    """
    Main handler function, passes off it's work to crhelper's cfn_handler
    """
    # update the logger with event info
    global logger
    logger = crhelper.log_config(event)
    return crhelper.cfn_handler(event, context, create, update, delete, logger,
                                init_failed)

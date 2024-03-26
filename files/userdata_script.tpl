#!/usr/bin/env bash

# Update Cloudfront distribution
echo Updating Cloudfront distribution
PUBLIC_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
# Need the ETag from the original response before modifying to make it a valid request, save to temp file
aws cloudfront get-distribution --id E3LAHTKSLN65G9 | jq -r ".Distribution.DistributionConfig.Origins.Items[].DomainName = \"$PUBLIC_HOSTNAME\"" > temp-dist-config.json
DISTRIBUTION_ETAG=$(cat temp-dist-config.json | jq -r .ETag)
# Can't read and write to the same file, we'll delete them both in a second anyway
jq .Distribution.DistributionConfig temp-dist-config.json > final-dist-config.json
aws cloudfront update-distribution --id E3LAHTKSLN65G9 --if-match $DISTRIBUTION_ETAG --distribution-config file://final-dist-config.json
rm temp-dist-config.json final-dist-config.json

ebs_id="${ebs_id}"
ebs_device="${ebs_device}"
ebs_path="${ebs_path}"

efs_id="${efs_id}"
efs_path="${efs_path}"

# Attach secondary EBS volume
echo Attaching database EBS volume
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
while [ ! -e $ebs_device ]
do
    aws ec2 attach-volume --volume-id $ebs_id --device /dev/sdf --instance-id $INSTANCE_ID --region us-east-2
    echo Waiting for EBS volume to attach
    sleep 5
done

mount -t ext4 $ebs_device $ebs_path
mount -t efs $efs_id $efs_path

ebs_uuid=$(blkid | grep "/dev/sdf" | awk '{print $2}')
# Edit fstab so EBS and EFS automatically loads on reboot
echo Adding mounts to /etc/fstab
echo $efs_id:/ $efs_path efs iam,tls,_netdev 0 0 >> /etc/fstab
echo $ebs_uuid $ebs_path ext4 defaults,nofail 0 0 >> /etc/fstab

service mariadb restart
service httpd restart

ami_image="${ami_image}"
instance_type="${instance_type}"
sns_alarm_topic="${sns_alarm_topic}"

echo Updating Cloudwatch alarms
aws cloudwatch put-metric-alarm \
--region us-east-2 \
--alarm-name "Wordpress CPU util" \
--alarm-description "Excessive CPU util on Wordpress instance" \
--namespace AWS/EC2 \
--metric-name CPUUtilization \
--statistic Average \
--ok-actions $sns_alarm_topic \
--alarm-actions $sns_alarm_topic \
--period 300 \
--evaluation-periods 3 \
--datapoints-to-alarm 3 \
--threshold 90 \
--comparison-operator GreaterThanOrEqualToThreshold \
--dimensions Name=InstanceId,Value=$INSTANCE_ID

aws cloudwatch put-metric-alarm \
--region us-east-2 \
--alarm-name "Wordpress excessive memory use" \
--alarm-description "Wordpress using more memory than expected" \
--namespace CWAgent \
--metric-name mem_used_percent \
--statistic Average \
--ok-actions $sns_alarm_topic \
--alarm-actions $sns_alarm_topic \
--period 300 \
--evaluation-periods 3 \
--datapoints-to-alarm 3 \
--threshold 85 \
--comparison-operator GreaterThanOrEqualToThreshold \
--dimensions Name=InstanceId,Value=$INSTANCE_ID Name=InstanceType,Value=$instance_type Name=ImageId,Value=$ami_image

#!/usr/bin/env bash

# Attach secondary EBS volume
INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 attach-volume --volume-id vol-0ce4bc29e315a9bb6 --device /dev/sdf --instance-id $INSTANCE_ID --region us-east-2

# Update Cloudfront distribution
PUBLIC_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/public-hostname)
# Need the ETag from the original response before modifying to make it a valid request, save to temp file
aws cloudfront get-distribution --id E3LAHTKSLN65G9 | jq -r ".Distribution.DistributionConfig.Origins.Items[].DomainName = \"$PUBLIC_HOSTNAME\"" > temp-dist-config.json
DISTRIBUTION_ETAG=$(cat temp-dist-config.json | jq -r .ETag)
# Can't read and write to the same file, we'll delete them both in a second anyway
jq .Distribution.DistributionConfig temp-dist-config.json > final-dist-config.json
aws cloudfront update-distribution --id E3LAHTKSLN65G9 --if-match $DISTRIBUTION_ETAG --distribution-config file://final-dist-config.json
rm temp-dist-config.json final-dist-config.json

ebs_device="${ebs_device}"
ebs_path="${ebs_path}"

efs_id="${efs_id}"
efs_path="${efs_path}"

mount $ebs_device $ebs_path
mount -t efs $efs_id $efs_path

ebs_uuid=$(blkid | grep "/dev/sdf" | awk '{print $2}')
# Edit fstab so EBS and EFS automatically loads on reboot
echo $efs_id:/ $efs_path efs iam,tls,_netdev 0 0 >> /etc/fstab
echo $ebs_uuid $ebs_path ext4 defaults,nofail 0 0 >> /etc/fstab

service mariadb restart
service httpd restart
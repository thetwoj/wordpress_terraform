#!/usr/bin/env bash

ebs_device="${ebs_device}"
ebs_path="${ebs_path}"

efs_id="${efs_id}"
efs_path="${efs_path}"

mount $ebs_device $ebs_path
mount -t efs $efs_id $efs_path

ebs_uuid=$(blkid | grep "/dev/xvdf" | awk '{print $2}')
# Edit fstab so EBS and EFS automatically loads on reboot
echo $efs_id:/ $efs_path efs iam,tls,_netdev 0 0 >> /etc/fstab
echo $ebs_uuid $ebs_path ext4 defaults,nofail 0 0 >> /etc/fstab

service mariadb restart
service httpd restart
#!/bin/bash
sudo yum -y install ec2-instance-connect

# for the moment install nginx for testing:
sudo amazon-linux-extras enable nginx1
sudo yum -y install nginx
sudo service nginx start


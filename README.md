# JupyterLab on AWS

This repository contains the Terraform code to deploy the AWS Lab: an infrastructure hosted on Amazon Web Services that allows users to do data analysis via the [JupyterLab](https://jupyterlab.readthedocs.io/en/stable/) interface.

The public-facing component of the infrastructure is an [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/introduction.html) (ALB), which is associated to a configurable domain name via a [Route 53](https://aws.amazon.com/route53/) alias record. The ALB also gets a verified TLS certificate via the [Certificate Manager](https://aws.amazon.com/certificate-manager/) service.

Traffic is forwarded from the ALB to a set of [EC2](https://aws.amazon.com/ec2) Lab instances. Each instance is created from an image (AMI) with [JupyterHub](https://jupyter.org/hub), where users can log in and start JupyterLab sessions in Docker containers, based on a container image that includes libraries for data analysis in Python, R and Julia ([jupyter/datascience-notebook](https://hub.docker.com/r/jupyter/datascience-notebook/)).

Lab instances belong to an auto scaling group, for which auto scaling policies are defined depending on the average number of user sessions per instance (a custom metric). As new users log in and start their JupyterLab sessions, an alarm created in [CloudWatch](https://aws.amazon.com/cloudwatch/) triggers an automatic scale-up action to increase the capacity of the instance group accordingly. Similarly, when the custom metric goes below a certain threshold, scale-down is applied.

Both the ALB and its target instances are spawned in multiple AZs of a configurable AWS region for high availability. Lab instances live in public [VPC](https://aws.amazon.com/vpc/?vpc-blogs.sort-by=item.additionalFields.createdDate&vpc-blogs.sort-order=desc) subnets so that users can access the Internet from their JupyterLab sessions (e.g. to install additional packages or query external data sources). However, a security group is attached to the instances so that only the ALB can initiate connections to them.

The figure below shows the architecture of the AWS Lab.

![JupyterLab deployment on AWS](./aws-lab.png)

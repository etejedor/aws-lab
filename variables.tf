## Region

variable "region" {
  description = "AWS region where to deploy the infrastructure"
  type        = string
}

## VPC

variable "vpc_id" {
  description = "ID of the VPC where to allocate the resources"
  type        = string
}

## Domain

variable "domain_name" {
  description = "Name of the (sub)domain to associate with the load balancer"
  type        = string

}

variable "hosted_zone_name" {
  description = "Name of the hosted zone of the domain"
  type        = string
}

## Lab instances

variable "image_id" {
  description = "ID of the AMI of lab instances"
  type        = string
}

variable "instance_type" {
  description = "Type of lab instances"
  type        = string
}

variable "hub_port" {
  description = "Port on which JupyterHub listens in lab instances"
  type        = number
}

## Auto-scaling

variable "asg_min" {
  description = "Minimum size of the auto-scaling group"
  type        = number
}

variable "asg_max" {
  description = "Maximum size of the auto-scaling group"
  type        = number
}

variable "asg_desired" {
  description = "Number of instances that should be running in the auto-scaling group"
  type        = number
}

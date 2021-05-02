region = "eu-west-3"

vpc_id = "vpc-336e9c5b"

domain_name      = "lab.parallelody.com"
hosted_zone_name = "parallelody.com"

image_id      = "ami-0dcbcd4b8531a7012"
instance_type = "t2.micro"
hub_port      = 8000

asg_min     = 1
asg_max     = 3
asg_desired = 1

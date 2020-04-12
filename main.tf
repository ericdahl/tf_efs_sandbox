provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source        = "github.com/ericdahl/tf-vpc"
  admin_ip_cidr = "${var.admin_cidr}"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true

  owners = [137112412989]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "tf_efs_sandbox" {
  ami                    = "${data.aws_ami.amazon_linux_2.image_id}"
  instance_type          = "t2.small"
  subnet_id              = "${module.vpc.subnet_public1}"
  vpc_security_group_ids = ["${module.vpc.sg_allow_22}", "${module.vpc.sg_allow_egress}"]
  key_name               = "${var.key_name}"

  user_data = <<EOF
#!/bin/bash

yum install -y amazon-efs-utils
EOF

  tags {
    Name = "${var.name}"
  }
}

resource "aws_efs_file_system" "efs" {
  encrypted        = false
  performance_mode = "generalPurpose"

  tags {
    Name = "${var.name}"
  }
}

resource "aws_security_group" "efs" {
  vpc_id = "${module.vpc.vpc_id}"

  tags {
    Name = "${var.name}"
  }
}

resource "aws_security_group_rule" "efs" {
  security_group_id = "${aws_security_group.efs.id}"

  type      = "ingress"
  protocol  = "tcp"
  from_port = 2049
  to_port   = 2049

  source_security_group_id = "${module.vpc.sg_allow_22}"
}

resource "aws_efs_mount_target" "private1" {
  file_system_id  = "${aws_efs_file_system.efs.id}"
  subnet_id       = "${module.vpc.subnet_private1}"
  security_groups = ["${aws_security_group.efs.id}"]
}

# TF currently doesn't support Access Points: https://github.com/terraform-providers/terraform-provider-aws/issues/12118
resource "null_resource" "efs_access_point_foo" {
  provisioner "local-exec" {
    command = "aws efs create-access-point --client-token foo --file-system-id ${aws_efs_file_system.efs.id} --root-directory 'Path=/foo,CreationInfo={OwnerUid=1001,OwnerGid=1001,Permissions=755}'"
  }

  depends_on = ["aws_efs_file_system.efs"]
}

resource "null_resource" "efs_access_point_bar" {
  provisioner "local-exec" {
    command = "aws efs create-access-point --client-token bar --file-system-id ${aws_efs_file_system.efs.id} --root-directory 'Path=/bar'"
  }

  depends_on = ["aws_efs_file_system.efs"]
}

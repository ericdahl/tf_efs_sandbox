output "aws_instance.tf_efs_sandbox.public_ipip" {
  value = "${aws_instance.tf_efs_sandbox.public_ip}"
}

output "aws_efs_file_system.efs.id" {
  value = "${aws_efs_file_system.efs.id}"
}

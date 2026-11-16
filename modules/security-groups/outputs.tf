output "ssh_security_group_id" {
  description = "SSH security group ID"
  value       = aws_security_group.ec2_ssh.id
}

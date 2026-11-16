resource "aws_security_group" "ec2_ssh" {
  name        = "${var.project_name}-ec2-ssh-sg"
  description = "Allow SSH only from approved public IP"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-ec2-ssh-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ec2_ssh.id

  description = "SSH access from approved public IP"
  cidr_ipv4   = var.ssh_allowed_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.ec2_ssh.id

  description = "Allow outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

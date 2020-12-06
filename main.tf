#################################### PROVIDER - KEY - ROLE - POLICY - SECURITY GROUP ########################################

variable "access_key" {
  type = string
}
variable "secret_key" {
  type = string
}

provider "aws" {
   region = "us-east-1"
   access_key = var.access_key
   secret_key = var.secret_key
}

resource "tls_private_key" "testenv_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "testenv_keypair" {
   key_name = "testenv_keypair"
   #public_key = "${tls_private_key.testenv_key.public_key_openssh}"
   public_key = "${file("/home/dome/.ssh/id_rsa.pub")}"
}

resource "aws_iam_role" "testenv_role" {
  name = "testenv_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "testenv_profile" {
  name = "testenv_profile"
  role = "${aws_iam_role.testenv_role.name}"
}

resource "aws_iam_role_policy" "testenv_policy" {
  name = "testenv_policy"
  role = "${aws_iam_role.testenv_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:*", "ecs:Describe*", "ecs:List*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_security_group" "testenv_sg" {
  name = "testenv_sg"
  description = "Web Security Group"
  
  ingress {
  from_port = 0
  to_port = 0
  protocol = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }    
  
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#################################### INFRA NODE ########################################

resource "aws_instance" "infra" {
   ami = "ami-05801d0a3c8e4c443"
   instance_type = "t2.micro"
   key_name = "testenv_keypair"
   security_groups = ["${aws_security_group.testenv_sg.name}"]
   iam_instance_profile = aws_iam_instance_profile.testenv_profile.name

   tags = {
     Name = "Infra"
  }

  provisioner "file" {
    source      = "./infra_setup_script.sh"
    destination = "./infra_setup_script.sh"

    connection {
      user     = "ubuntu"
      private_key = "${file("/home/dome/.ssh/id_rsa")}"
      host = self.public_ip
    }    
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x infra_setup_script.sh",
      "sudo sh infra_setup_script.sh",
    ]

    connection {
      user     = "ubuntu"
      private_key = "${file("/home/dome/.ssh/id_rsa")}"
      host = self.public_ip
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.aws_region
  profile = "khalid"
}
resource "aws_security_group" "devops-sg" {
  name        = "devops-sg"
  description = "DevOps security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Dynamically create rules for port ranges
  dynamic "ingress" {
    for_each = toset([1000, 1001, 1002, 1003, 1004, 1005]) # Example port list
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-sg"
  }
}

resource "aws_instance" "Server" {
  instance_type          = var.instance_type
  ami                    = var.ami
  vpc_security_group_ids = [aws_security_group.devops-sg.id] # Use vpc_security_group_ids
  key_name               = var.key_name
  root_block_device {
    volume_size = 20
  }
  tags = {
    Name = "Server"
  }
  provisioner "remote-exec" {
    # ESTABLISHING SSH CONNECTION WITH EC2
    connection {
      type        = "ssh"
      private_key = file("./ec2.pem") # replace with your key-name 
      user        = "ubuntu"
      host        = self.public_ip
    }

    inline = [
      "sudo apt-get update -y",
      # Install AWS CLI
      # Ref: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
      "sudo apt install unzip wget -y",
      "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
      "unzip awscliv2.zip",
      "sudo ./aws/install",

      # install terraform
      "sudo snap install -y terraform --classic",

      # Install Docker
      # Ref: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
      "sudo apt-get update -y",
      "sudo apt-get install -y ca-certificates curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu",
      "sudo chmod 777 /var/run/docker.sock",
      "docker --version",

      # Install Kubectl
      # Ref: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html#kubectl-install-update
      "curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.4/2024-09-11/bin/linux/amd64/kubectl",
      "curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.4/2024-09-11/bin/linux/amd64/kubectl.sha256",
      "sha256sum -c kubectl.sha256",
      "openssl sha1 -sha256 kubectl",
      "chmod +x ./kubectl",
      "mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH",
      "echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc",
      "sudo mv $HOME/bin/kubectl /usr/local/bin/kubectl",
      "sudo chmod +x /usr/local/bin/kubectl",
      "kubectl version --client",

      # Install Helm
      # Ref: https://helm.sh/docs/intro/install/
      # Ref (for .tar.gz file): https://github.com/helm/helm/releases
      "wget https://get.helm.sh/helm-v3.16.1-linux-amd64.tar.gz",
      "tar -zxvf helm-v3.16.1-linux-amd64.tar.gz",
      "sudo mv linux-amd64/helm /usr/local/bin/helm",
      "helm version",
    ]
  }
}
resource "aws_instance" "Jenkins" {
  instance_type          = var.instance_type
  ami                    = var.ami
  vpc_security_group_ids = [aws_security_group.devops-sg.id] # Use vpc_security_group_ids
  key_name               = var.key_name
  root_block_device {
    volume_size = 20
  }
  tags = {
    Name = "Jenkins"
  }
  provisioner "remote-exec" {
    # ESTABLISHING SSH CONNECTION WITH EC2
    connection {
      type        = "ssh"
      private_key = file("./ec2.pem") # replace with your key-name 
      user        = "ubuntu"
      host        = self.public_ip
    }

    inline = [
      "sudo apt-get update -y",
      # Install Java 17
      # Ref: https://www.rosehosting.com/blog/how-to-install-java-17-lts-on-ubuntu-20-04/
      "sudo apt update -y",
      "sudo apt install openjdk-17-jdk openjdk-17-jre -y",
      "java -version",

      # Install Jenkins
      # Ref: https://www.jenkins.io/doc/book/installing/linux/#debianubuntu
      "sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key",
      "echo \"deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/\" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y jenkins",
      "sudo systemctl start jenkins",
      "sudo systemctl enable jenkins",

      # Get Jenkins initial login password
      "ip=$(curl -s ifconfig.me)",
      "pass=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)",

      "echo 'Access Jenkins Server here --> http://'$ip':8080'",
      "echo 'Jenkins Initial Password: '$pass''"
    ]
  }
}
resource "aws_instance" "SonarQube" {
  instance_type          = var.instance_type
  ami                    = var.ami
  vpc_security_group_ids = [aws_security_group.devops-sg.id] # Use vpc_security_group_ids
  key_name               = var.key_name
  root_block_device {
    volume_size = 20
  }
  tags = {
    Name = "SonrQube"
  }
  provisioner "remote-exec" {
    # ESTABLISHING SSH CONNECTION WITH EC2
    connection {
      type        = "ssh"
      private_key = file("./ec2.pem") # replace with your key-name 
      user        = "ubuntu"
      host        = self.public_ip
    }

    inline = [
      "sudo apt-get update -y",

      # Install Docker
      # Ref: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
      "sudo apt-get update -y",
      "sudo apt-get install -y ca-certificates curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc",
      "sudo chmod a+r /etc/apt/keyrings/docker.asc",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "sudo usermod -aG docker ubuntu",
      "sudo chmod 777 /var/run/docker.sock",
      "docker --version",

      # Install SonarQube (as container)
      "docker run -d --name sonar -p 9000:9000 sonarqube:lts-community",
      "echo 'Access SonarQube Server here --> http://'$ip':9000'",
      "echo 'SonarQube Username & Password: admin'"
    ]
  }
}
resource "aws_instance" "Nexus" {
  instance_type          = var.instance_type
  ami                    = var.ami
  vpc_security_group_ids = [aws_security_group.devops-sg.id]
  key_name               = var.key_name
  root_block_device {
    volume_size = 20
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt install -y vim openjdk-17-jdk
    cd /opt
    sudo wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz
    sudo tar -xvzf latest-unix.tar.gz
    sudo mv /opt/nexus-3.73.0-12 /opt/nexus
    sudo adduser nexus
    sudo visudo
    echo "nexus ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    sudo chown -R nexus:nexus /opt/nexus
    sudo chown -R nexus:nexus /opt/sonatype-work
    # Nexus RC
    if [ ! -f /opt/nexus/bin/nexus.rc ]; then echo 'run_as_user="nexus"' | sudo tee /opt/nexus/bin/nexus.rc; fi
    sudo chown nexus:nexus /opt/nexus/bin/nexus.rc
    sudo chmod 644 /opt/nexus/bin/nexus.rc
    # Create systemd service
    echo '[Unit]' | sudo tee /etc/systemd/system/nexus.service
    echo 'Description=nexus service' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'After=network.target' | sudo tee -a /etc/systemd/system/nexus.service
    echo '' | sudo tee -a /etc/systemd/system/nexus.service
    echo '[Service]' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'Type=forking' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'LimitNOFILE=65536' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'ExecStart=/opt/nexus/bin/nexus start' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'ExecStop=/opt/nexus/bin/nexus stop' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'User=nexus' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'Restart=on-abort' | sudo tee -a /etc/systemd/system/nexus.service
    echo '' | sudo tee -a /etc/systemd/system/nexus.service
    echo '[Install]' | sudo tee -a /etc/systemd/system/nexus.service
    echo 'WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/nexus.service
    sudo systemctl daemon-reload
    sudo systemctl enable nexus.service
    sudo systemctl start nexus.service
  EOF

  tags = {
    Name = "Nexus"
  }
}
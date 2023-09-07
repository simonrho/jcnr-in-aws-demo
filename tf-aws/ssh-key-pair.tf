# Generate an SSH key pair
resource "tls_private_key" "my_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store the private key in a local file
resource "local_sensitive_file" "my_private_key_file" {
  content         = tls_private_key.my_private_key.private_key_pem
  filename        = "my-ssh-key.pem"
  file_permission = "0600"
}

# Use the public key in the EC2 instance
resource "aws_key_pair" "my_public_ssh_key" {
  key_name   = "my-jcnr-public-key"
  public_key = tls_private_key.my_private_key.public_key_openssh
}


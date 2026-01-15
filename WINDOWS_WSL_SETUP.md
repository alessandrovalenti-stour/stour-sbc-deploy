# Windows Local Machine Setup with WSL

This guide shows how to set up a Windows 10/11 machine using WSL2 and install the tools needed for this project:

- WSL2 with Ubuntu
- Git
- AWS CLI v2
- Terraform
- Ansible
- SSH key for AWS access

All commands below are run inside the WSL Ubuntu shell unless otherwise noted.

## 1. Enable WSL2 and install Ubuntu

On Windows PowerShell (run as Administrator):

```powershell
wsl --install
```

If you already have WSL but not WSL2:

```powershell
wsl --set-default-version 2
```

Reboot if requested, then install Ubuntu from the Microsoft Store (Ubuntu 22.04 or similar). Launch Ubuntu once and create your Linux user.

## 2. Update Ubuntu and basic tools

Inside your Ubuntu WSL terminal:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl unzip software-properties-common
```

## 3. Install AWS CLI v2

Still inside Ubuntu:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

Configure AWS credentials (requires your access key/secret or SSO):

```bash
aws configure
```

## 4. Install Terraform

Add the official HashiCorp APT repository and install Terraform:

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y terraform
terraform version
```

## 5. Install Ansible

For Ubuntu 22.04, the packaged Ansible is sufficient:

```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```

## 6. Prepare SSH access

You need an SSH key that matches the AWS EC2 key pair used by this project (for example `stour-sbc-key.pem`).

Place the key under your Windows home directory and make it visible in WSL, for example:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<YourWindowsUser>/Downloads/stour-sbc-key.pem ~/.ssh/
chmod 600 ~/.ssh/stour-sbc-key.pem
```

Replace `<YourWindowsUser>` with your actual Windows username.

## 7. Clone this repository in WSL

Inside Ubuntu:

```bash
cd ~
git clone https://github.com/<your-org>/stour-libresbc-aws.git
cd stour-libresbc-aws
```

Adjust the repository URL if you are using a private fork.

## 8. Run Terraform and Ansible from WSL

From the project directory:

```bash
./deploy.sh --apply
```

Or to run only infrastructure:

```bash
./deploy.sh --apply --stage infra
```

Or only Ansible on existing instances:

```bash
./deploy.sh --apply --stage ansible
```

Ensure your AWS credentials in WSL have permissions to create EC2 instances, security groups, EIPs and CloudWatch resources.


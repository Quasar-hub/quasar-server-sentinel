# 🔒 Basic Security Settings

### Firewall Configuration
```bash
# Reset and configure UFW
sudo ufw disable
sudo ufw reset

# Allow essential ports
sudo ufw allow 22/tcp        # SSH
sudo ufw allow 26656/tcp     # Cosmos P2P

# Set default policy and enable
sudo ufw default deny incoming
sudo ufw enable
```

### SSH & User Security

First, you need to add your SSH public key to authorize access to the server:
```bash
# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh

# Create or edit authorized_keys file
nano ~/.ssh/authorized_keys

# Add your public key (example format):
# ssh-rsa AAAAB3NzaC1yc2EAAAADA... your.email@example.com

# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

After adding your SSH key, secure the SSH configuration:
```bash
# Disable password authentication completely (only SSH keys allowed)
# This prevents brute force attacks by requiring SSH key authentication
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restrict root login to only allow SSH key authentication
# Prevents direct root login attempts and adds additional security layer
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
sudo systemctl restart ssh

# Edit sudoers file to prevent user 'ubuntu' from using 'sudo su'
sudo visudo
# Add line:
ubuntu ALL=(ALL:ALL) !/bin/su
```

### Check Settings
```bash
# Check UFW status
sudo ufw status

# Verify SSH configuration
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'

# Check current user
whoami
```

#!/bin/bash

# Install dependencies
sudo apt-get update
sudo apt-get install -y net-tools docker.io nginx logrotate

# Copy devopsfetch.sh to /usr/local/bin
sudo cp devopsfetch.sh /usr/local/bin/devopsfetch
sudo chmod +x /usr/local/bin/devopsfetch

# Create systemd service
sudo bash -c 'cat <<EOL > /etc/systemd/system/devopsfetch.service
[Unit]
Description=DevOps Fetch Service

[Service]
ExecStart=/usr/local/bin/devopsfetch -t
Restart=always

[Install]
WantedBy=multi-user.target
EOL'

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable devopsfetch.service
sudo systemctl start devopsfetch.service

# Configure logrotate
sudo bash -c 'cat <<EOL > /etc/logrotate.d/devopsfetch
/var/log/devopsfetch.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0640 root root
    postrotate
        systemctl reload devopsfetch.service > /dev/null 2>&1 || true
    endscript
}
EOL'

echo "Installation completed."


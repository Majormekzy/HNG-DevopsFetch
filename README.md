# HNG-DevopsFetch

## DevOpsFetch Script Documentation

### Overview
`devopsfetch.sh` is a tool designed to collect and display system information for DevOps purposes. It provides details about active ports, Docker containers, Nginx configurations, user logins, and system activities within specified time ranges. The script includes a logging mechanism to monitor and log activities continuously.

### Installation and Configuration Steps

#### Prerequisites
- Ensure your system has the necessary permissions to run the script as root.
- Ensure `netstat`, `docker`, `nginx`, and other relevant commands are available on your system.

#### Installation
1. **Clone or Download the Script:**
   Download the `devopsfetch.sh` script to your desired directory.

2. **Make the Script Executable:**
   ```bash
   sudo chmod +x /usr/local/bin/devopsfetch.sh
   ```

3. **Create a Log File:**
   Ensure the log file exists and has the appropriate permissions:
   ```bash
   sudo touch /var/log/devopsfetch.log
   sudo chmod 664 /var/log/devopsfetch.log
   ```

4. **Create and Edit the Installation Script:**
   ```bash
   sudo nano /usr/local/bin/install_devopsfetch.sh
   ```

5. **Paste the Following Script:**

   ```bash
   #!/bin/bash

   # Ensure script is run with root privileges
   if [ "$EUID" -ne 0 ]; then 
     echo "Please run as root"
     exit
   fi

   # Update package list and install necessary packages
   apt update
   apt install -y net-tools docker.io nginx

   # Ensure Nginx and Docker services are running
   systemctl enable nginx
   systemctl start nginx
   systemctl enable docker
   systemctl start docker

   # Create log file and set appropriate permissions
   touch /var/log/devopsfetch.log
   chmod 664 /var/log/devopsfetch.log

   # Make the devopsfetch script executable
   chmod +x /usr/local/bin/devopsfetch.sh

   echo "Installation and configuration complete."
   ```

6. **Save and Close the Script:**
   Press `CTRL+X`, then `Y`, and then `Enter` to save and exit the editor.

7. **Make the Script Executable:**
   ```bash
   sudo chmod +x /usr/local/bin/install_devopsfetch.sh
   ```

8. **Run the Installation Script:**
   ```bash
   sudo /usr/local/bin/install_devopsfetch.sh
   ```

#### Configuration
- The script assumes the standard paths for Nginx configuration files (`/etc/nginx/sites-available/` and `/etc/nginx/conf.d/`). Adjust the script if your configuration files are located elsewhere.

#### Create the `devopsfetch.sh` Script

1. **Create and Edit the Script:**
   ```bash
   sudo nano /usr/local/bin/devopsfetch.sh
   ```

2. **Paste the Following Script:**

   ```bash
   #!/bin/bash

   # Ensure script is run with root privileges
   if [ "$EUID" -ne 0 ]; then 
     echo "Please run as root"
     exit
   fi

   # Define log file
   LOG_FILE="/var/log/devopsfetch.log"

   # Function to display help
   show_help() {
       echo "Usage: $0 [options]"
       echo "Options:"
       echo "  -p, --port              Display all active ports and services"
       echo "  -p <port_number>        Provide detailed information about a specific port"
       echo "  -d, --docker            List all Docker images and containers"
       echo "  -d <container_name>     Provide detailed information about a specific container"
       echo "  -n, --nginx             Display all Nginx domains and their ports"
       echo "  -n <domain>             Provide detailed configuration information for a specific domain"
       echo "  -u, --users             List all users and their last login times"
       echo "  -u <username>           Provide detailed information about a specific user"
       echo "  -t, --time <start> [end] Display activities within a specified time range"
       echo "  -h, --help              Show this help message"
   }

   # Function to display all active ports and services
   show_ports() {
       netstat -tuln
   }

   # Function to display information about a specific port
   show_port_details() {
       local port=$1
       netstat -tuln | grep ":$port"
   }

   # Function to list all Docker images and containers
   show_docker() {
       docker images
       docker ps -a
   }

   # Function to display information about a specific Docker container
   show_docker_details() {
       local container_name=$1
       docker inspect $container_name
   }

   # Function to display all Nginx domains and their ports
   show_nginx() {
       if [ -d /etc/nginx/sites-available ] || [ -d /etc/nginx/conf.d ]; then
           echo -e "CONF PATH\t\t\t\t\tDOMAIN\t\t\tURL"
           echo -e "---------\t\t\t\t\t------\t\t\t---"
           for file in /etc/nginx/sites-available/* /etc/nginx/conf.d/*; do
               if [ -f "$file" ]; then
                   server_names=$(grep -E "^\s*server_name" "$file" | awk '{print $2}' | sed 's/;//')
                   ports=$(grep -E "^\s*listen" "$file" | awk '{print $2}' | sed 's/;//')
                   for server_name in $server_names; do
                       for port in $ports; do
                           if [ "$server_name" == "_" ]; then
                               server_name="(default_server)"
                           fi
                           echo -e "$file\t$server_name\t\thttp://$server_name"
                       done
                   done
               fi
           done
       else
           echo "No Nginx configuration files found."
       fi
   }

   # Function to display Nginx configuration for a specific domain
   show_nginx_details() {
       local domain=$1
       local config_files=$(grep -H -l "server_name.*$domain" /etc/nginx/sites-available/* /etc/nginx/conf.d/* 2>/dev/null)
       if [ -z "$config_files" ]; then
           echo "Domain $domain not found in Nginx configuration."
       else
           grep -H -A 10 "server_name.*$domain" $config_files
       fi
   }

   # Function to list all users and their last login times
   show_users() {
       lastlog
   }

   # Function to display information about a specific user
   show_user_details() {
       local username=$1
       getent passwd $username
       last $username
   }

   # Function to parse log dates
   parse_log_date() {
       local log_date=$1
       local date_formats=(
           "%Y-%m-%d %H:%M:%S"
           "%a %b %d %H:%M:%S %Z %Y"
       )
       for fmt in "${date_formats[@]}"; do
           date_epoch=$(date -d "$log_date" +"%s" 2>/dev/null)
           if [ $? -eq 0 ]; then
               echo $date_epoch
               return
           fi
       done
       echo ""
   }

   # Function to display activities within a specified time range
   show_time_range() {
       local start=$1
       local end=${2:-$(date +"%Y-%m-%d")}
       echo "Debug: start=$start, end=$end" >&2
       
       start_epoch=$(date -d "$start 00:00:00" +%s)
       end_epoch=$(date -d "$end 23:59:59" +%s)
       
       echo "Debug: start_epoch=$start_epoch, end_epoch=$end_epoch" >&2

       while read -r line; do
           # Extract the date and time from the log entry
           log_date=$(echo "$line" | awk -F: '{print $1":"$2":"$3}')
           log_epoch=$(parse_log_date "$log_date")
           
           if [ -n "$log_epoch" ]; then
               echo "Debug: log_date=$log_date, log_epoch=$log_epoch" >&2
               
               if [ "$log_epoch" -ge "$start_epoch" ] && [ "$log_epoch" -le "$end_epoch" ]; then
                   echo "$line"
               else
                   echo "Debug: log entry out of range: $line" >&2
               fi
           else
               echo "Debug: Unable to parse log date from line: $line" >&2
           fi
       done < "$LOG_FILE"
   }

   # Main script logic
   case "$1" in
       -p|--port)
           if [ -z "$2" ]; then
               show_ports
           else
               show_port_details $2
           fi
           ;;
       -d|--docker)
           if [ -z "$2" ]; then
               show_docker
           else
               show_docker_details $2
           fi
           ;;
       -n|--nginx)
           if

 [ -z "$2" ]; then
               show_nginx
           else
               show_nginx_details $2
           fi
           ;;
       -u|--users)
           if [ -z "$2" ]; then
               show_users
           else
               show_user_details $2
           fi
           ;;
       -t|--time)
           show_time_range $2 $3
           ;;
       -h|--help)
           show_help
           ;;
       *)
           echo "Invalid option"
           show_help
           ;;
   esac

   # Log activities
   {
       echo "$(date +'%Y-%m-%d %H:%M:%S'): $0 $@"
   } >> $LOG_FILE
   ```

3. **Save and Close the Script:**
   Press `CTRL+X`, then `Y`, and then `Enter` to save and exit the editor.

### Set Up the Systemd Service

1. **Create and Edit the Systemd Service File:**
   ```bash
   sudo nano /etc/systemd/system/devopsfetch.service
   ```

2. **Paste the Following Service Configuration:**

   ```ini
   [Unit]
   Description=DevOpsFetch Service
   After=network.target

   [Service]
   ExecStart=/usr/local/bin/devopsfetch.sh
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target
   ```

3. **Save and Close the Service File:**
   Press `CTRL+X`, then `Y`, and then `Enter` to save and exit the editor.

4. **Reload Systemd to Recognize the New Service:**
   ```bash
   sudo systemctl daemon-reload
   ```

5. **Enable and Start the Service:**
   ```bash
   sudo systemctl enable devopsfetch.service
   sudo systemctl start devopsfetch.service
   ```

### Usage Examples

#### Display All Active Ports and Services
```bash
sudo /usr/local/bin/devopsfetch.sh -p
```

#### Display Detailed Information About a Specific Port
```bash
sudo /usr/local/bin/devopsfetch.sh -p <port_number>
```
Example:
```bash
sudo /usr/local/bin/devopsfetch.sh -p 80
```

#### List All Docker Images and Containers
```bash
sudo /usr/local/bin/devopsfetch.sh -d
```

#### Display Detailed Information About a Specific Docker Container
```bash
sudo /usr/local/bin/devopsfetch.sh -d <container_name>
```
Example:
```bash
sudo /usr/local/bin/devopsfetch.sh -d my_container
```

#### Display All Nginx Domains and Their Ports
```bash
sudo /usr/local/bin/devopsfetch.sh -n
```

#### Display Detailed Configuration Information for a Specific Nginx Domain
```bash
sudo /usr/local/bin/devopsfetch.sh -n <domain>
```
Example:
```bash
sudo /usr/local/bin/devopsfetch.sh -n www.example.com
```

#### List All Users and Their Last Login Times
```bash
sudo /usr/local/bin/devopsfetch.sh -u
```

#### Display Detailed Information About a Specific User
```bash
sudo /usr/local/bin/devopsfetch.sh -u <username>
```
Example:
```bash
sudo /usr/local/bin/devopsfetch.sh -u john
```

#### Display Activities Within a Specified Time Range
```bash
sudo /usr/local/bin/devopsfetch.sh -t <start_date> [end_date]
```
Example:
```bash
sudo /usr/local/bin/devopsfetch.sh -t 2024-07-18 2024-07-22
sudo /usr/local/bin/devopsfetch.sh -t 2024-07-21
```

#### Display Help Message
```bash
sudo /usr/local/bin/devopsfetch.sh -h
```

### Logging Mechanism and How to Retrieve Logs

#### Logging Mechanism
- The script logs all activities to `/var/log/devopsfetch.log`.
- Each command executed by the script is logged with a timestamp.

#### Retrieve Logs
- To view the log file:
  ```bash
  sudo cat /var/log/devopsfetch.log
  ```

- To view logs for a specific date range, use the `-t` option with the script:
  ```bash
  sudo /usr/local/bin/devopsfetch.sh -t <start_date> [end_date]
  ```

Example:
```bash
sudo /usr/local/bin/devopsfetch.sh -t 2024-07-18 2024-07-22
```

This comprehensive guide provides all the necessary steps to implement, configure, and use the `devopsfetch` project, ensuring that no details are left out.

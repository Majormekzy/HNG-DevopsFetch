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
    echo -e "CONF PATH\t\t\t\t\tDOMAIN\t\t\tURL"
    echo -e "---------\t\t\t\t\t------\t\t\t---"
    if [ -d /etc/nginx/sites-available ] || [ -d /etc/nginx/conf.d ]; then
        for file in /etc/nginx/sites-available/* /etc/nginx/conf.d/*; do
            if [ -f "$file" ]; then
                server_names=$(grep -E "^\s*server_name" "$file" | awk '{print $2}' | sed 's/;//')
                ports=$(grep -E "^\s*listen" "$file" | awk '{print $2}' | sed 's/;//')
                for server_name in $server_names; do
                    for port in $ports; do
                        if [ "$server_name" == "_" ]; then
                            server_name="(default_server)"
                        fi
                        url="http://${server_name}:${port}"
                        printf "%-40s %-30s %-40s\n" "$file" "$server_name" "$url"
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
        if [ -z "$2" ]; then
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


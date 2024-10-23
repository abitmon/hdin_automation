#!/bin/bash

# Apache Optimization Script for cPanel Server with Comprehensive Variables and Modules

# Function to get current configuration values
get_current_values() {
    echo "Gathering current Apache configuration values..."

    # Read current configuration values
    max_request_workers=$(grep -i '^MaxRequestWorkers' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    server_limit=$(grep -i '^ServerLimit' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    keep_alive_timeout=$(grep -i '^KeepAliveTimeout' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    timeout=$(grep -i '^Timeout' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    start_servers=$(grep -i '^StartServers' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    min_spare_servers=$(grep -i '^MinSpareServers' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    max_spare_servers=$(grep -i '^MaxSpareServers' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    max_connections_per_child=$(grep -i '^MaxConnectionsPerChild' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    max_requests_per_connection=$(grep -i '^MaxRequestsPerConnection' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    max_requests=$(grep -i '^MaxRequests' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    max_connections=$(grep -i '^MaxConnections' /etc/httpd/conf/httpd.conf | awk '{print $2}')
    mod_cache=$(grep -i '^LoadModule cache_module' /etc/httpd/conf/httpd.conf | wc -l)
    compression=$(grep -i '^<IfModule deflate_module>' /etc/httpd/conf/httpd.conf | wc -l)

    # Set defaults if values are not present
    max_request_workers=${max_request_workers:-150}
    server_limit=${server_limit:-150}
    keep_alive_timeout=${keep_alive_timeout:-5}
    timeout=${timeout:-300}
    start_servers=${start_servers:-5}
    min_spare_servers=${min_spare_servers:-5}
    max_spare_servers=${max_spare_servers:-10}
    max_connections_per_child=${max_connections_per_child:-1000}
    max_requests_per_connection=${max_requests_per_connection:-1000}
    max_requests=${max_requests:-10000}
    max_connections=${max_connections:-150}

    echo "Current configuration values gathered."
}

# Function to gather system metrics
gather_metrics() {
    echo "Gathering system metrics..."

    # Get total memory
    total_mem=$(free -m | grep Mem: | awk '{print $2}')

    # Get number of CPU cores
    cpu_cores=$(nproc)

    # Get average CPU load
    cpu_load=$(uptime | awk -F'[a-z]:' '{ print $2 }' | cut -d, -f1)

    # Get current active HTTP and HTTPS connections
    http_connections=$(netstat -an | grep ':80 ' | grep ESTABLISHED | wc -l)
    https_connections=$(netstat -an | grep ':443 ' | grep ESTABLISHED | wc -l)

    # Print gathered metrics
    echo "Total Memory: ${total_mem}MB"
    echo "CPU Cores: ${cpu_cores}"
    echo "Average CPU Load: ${cpu_load}"
    echo "Active HTTP Connections: ${http_connections}"
    echo "Active HTTPS Connections: ${https_connections}"

    echo "System metrics gathered."
}

# Function to suggest optimized Apache settings based on metrics
suggest_apache_settings() {
    echo "Suggesting optimized Apache settings based on current metrics..."

    # Calculate average memory usage of the Apache process in MB
    average_memory=$(ps -ylC httpd --sort:rss | awk '{sum+=$8; ++n} END {avg=sum/n/1024; print avg}')

    # Calculate suggested_max_request_workers using bc for floating-point arithmetic
    suggested_max_request_workers=$(echo "scale=0; $total_mem / $average_memory" | bc)
    if [ $suggested_max_request_workers -gt 256 ]; then
        suggested_max_request_workers=256
    fi

    # Calculate ServerLimit as a fraction of MaxRequestWorkers
    suggested_server_limit=$((suggested_max_request_workers / 10))
    if [ $suggested_server_limit -lt 10 ]; then
        suggested_server_limit=10
    fi

    # Adjust other parameters based on system load
    suggested_keep_alive_timeout=$([ $(echo "$cpu_load > 1.0" | bc -l) ] && echo "2" || echo "5")
    suggested_timeout=$([ $(echo "$cpu_load > 1.0" | bc -l) ] && echo "150" || echo "300")

    # Compute dynamic values for other settings
    suggested_start_servers=$((cpu_cores * 2))
    suggested_min_spare_servers=$((cpu_cores * 2))
    suggested_max_spare_servers=$((cpu_cores * 4))
    suggested_max_connections_per_child=$((total_mem * 2))
    suggested_max_requests_per_connection=$((max_request_workers / 10))
    suggested_max_requests=$((max_request_workers * 100))
    suggested_max_connections=$((max_request_workers * 2))

    # Print suggested and current values side by side
    echo "Configuration settings (Suggested Value (Current Value)):"
    echo "MaxRequestWorkers: ${suggested_max_request_workers} (${max_request_workers})"
    echo "ServerLimit: ${suggested_server_limit} (${server_limit})"
    echo "KeepAliveTimeout: ${suggested_keep_alive_timeout} (${keep_alive_timeout})"
    echo "Timeout: ${suggested_timeout} (${timeout})"
    echo "StartServers: ${suggested_start_servers} (${start_servers})"
    echo "MinSpareServers: ${suggested_min_spare_servers} (${min_spare_servers})"
    echo "MaxSpareServers: ${suggested_max_spare_servers} (${max_spare_servers})"
    echo "MaxConnectionsPerChild: ${suggested_max_connections_per_child} (${max_connections_per_child})"
    echo "MaxRequestsPerConnection: ${suggested_max_requests_per_connection} (${max_requests_per_connection})"
    echo "MaxRequests: ${suggested_max_requests} (${max_requests})"
    echo "MaxConnections: ${suggested_max_connections} (${max_connections})"
    echo "Mod_cache: $( [ $mod_cache -eq 0 ] && echo 'Off (Suggested: On)' || echo 'On')"
    echo "Compression: $( [ $compression -eq 0 ] && echo 'Off (Suggested: On)' || echo 'On')"

    # Recommendations based on network connections
    echo "Recommendations based on network connections:"
    echo "Active HTTP Connections: ${http_connections} (Consider adjusting MaxRequestWorkers if high)"
    echo "Active HTTPS Connections: ${https_connections} (Consider adjusting MaxConnections if high)"

    echo "Suggested settings based on current metrics provided."
}

# Execute functions
get_current_values
gather_metrics
suggest_apache_settings

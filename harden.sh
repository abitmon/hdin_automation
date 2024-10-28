#!/bin/bash
#Tweaking audit log storage size and audit logs are not automatically deleted
echo "Tweaking audit configuration"
cp -rp /etc/audit/auditd.conf /etc/audit/auditd.conf-`date +%d-%m-%y-%T`
sed -i 's/^max_log_file = .*/max_log_file = 32/' /etc/audit/auditd.conf
sed -i 's/^max_log_file_action = .*/max_log_file_action = ROTATE/' /etc/audit/auditd.conf

#Tweaking sysctl configuration
echo "Tweaking sysctl configuration"
cp -rpf /etc/sysctl.conf /etc/sysctl.conf-`date +%d-%m-%y-%T`
cat <<EOT > /etc/sysctl.conf

# Disables packet forwarding
net.ipv4.ip_forward=0
# Disables IP source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.lo.accept_source_route = 0
net.ipv4.conf.eth0.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Enable IP spoofing protection, turn on source route verification
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.lo.rp_filter = 1
net.ipv4.conf.eth0.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP Redirect Acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.lo.accept_redirects = 0
net.ipv4.conf.eth0.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Enable Log Spoofed Packets, Source Routed Packets, Redirect Packets
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.lo.log_martians = 0
net.ipv4.conf.eth0.log_martians = 0

# Disables the magic-sysrq key
kernel.sysrq = 0

# Decrease the time default value for tcp_fin_timeout connection
net.ipv4.tcp_fin_timeout = 15

# Decrease the time default value for tcp_keepalive_time connection
net.ipv4.tcp_keepalive_time = 1800

# Controls IP packet forwarding
net.ipv4.ip_forward = 0

# Controls source route verification
net.ipv4.conf.default.rp_filter = 1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route = 0

# Controls the System Request debugging functionality of the kernel
kernel.sysrq = 0

# Controls whether core dumps will append the PID to the core filename.
# Useful for debugging multi-threaded applications.
kernel.core_uses_pid = 1

# Controls the use of TCP syncookies
net.ipv4.tcp_syncookies = 1

# Controls the default maxmimum size of a mesage queue
kernel.msgmnb = 65536

# Controls the maximum size of a message, in bytes
kernel.msgmax = 65536

# Controls the maximum shared segment size, in bytes
kernel.shmmax = 68719476736

# Controls the maximum number of shared memory segments, in pages
kernel.shmall = 4294967296

# disable ipv6 if not required
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# sysctl kernel.randomize_va_space
kernel.randomize_va_space = 2
EOT
sysctl -p > /dev/null 2>&1

#securing TMP partition.
echo "Secuiring the tmp partition"
/scripts/restartsrv_tailwatchd --stop > /dev/null 2>&1
service cpanel stop > /dev/null 2>&1
service mysqld stop > /dev/null 2>&1
service httpd stop > /dev/null 2>&1
# Check if /tmp is already mounted with tmpfs
is_tmp_secured() {
    grep -q '/tmp' /etc/fstab && grep -q 'tmpfs' /etc/fstab
}

# Main script logic
echo "Checking the security status of /tmp and /var/tmp..."

if is_tmp_secured; then
    echo "/tmp is already secured. Skipping the securetmp script."
else
    echo "/tmp is not secured. Running /usr/local/cpanel/scripts/securetmp..."
    /usr/local/cpanel/scripts/securetmp
fi

echo "Script complete."
/scripts/restartsrv_tailwatchd --start > /dev/null 2>&1
service cpanel start > /dev/null 2>&1
service mysqld start > /dev/null 2>&1
service httpd start > /dev/null 2>&1

#CHKROOTKIT INSTALLATION
echo -e "\e[1;36;40m Installing chkrootkit\e[0m"
cd /usr/local/src
rm -rf chkrootkit*
wget ftp://ftp.chkrootkit.org/pub/seg/pac/chkrootkit.tar.gz  > /dev/null 2>&1
tar -xzf chkrootkit.tar.gz  > /dev/null 2>&1
mkdir /usr/local/chkrootkit  > /dev/null 2>&1
mv chkrootkit*/* /usr/local/chkrootkit    > /dev/null 2>&1
cd /usr/local/chkrootkit  > /dev/null 2>&1
ln -s /usr/local/chkrootkit/chkrootkit /usr/local/bin/chkrootkit  > /dev/null 2>&1
make sense  > /dev/null 2>&1
sleep 2s;
echo -e "\e[1;36;40m Done.\e[0m"

#Tweaking apache settings
cp -rp /etc/cpanel/ea4/ea4.conf /etc/cpanel/ea4/ea4.conf-`date +%d-%m-%y-%T`
cp -rp /etc/apache2/conf/httpd.conf /etc/apache2/conf/httpd.conf-`date +%d-%m-%y-%T`
trace=$(grep -i TraceEnable /etc/cpanel/ea4/ea4.conf)
sed -i "s/$trace/   \"traceenable\" : \"Off\"/g" /etc/cpanel/ea4/ea4.conf
ssignature=$(grep -i ServerSignature /etc/cpanel/ea4/ea4.conf)
sed -i "s/$ssignature/   \"serversignature\" : \"Off\",/g" /etc/cpanel/ea4/ea4.conf
stokens=$(grep -i ServerTokens /etc/cpanel/ea4/ea4.conf)
sed -i "s/$stokens/   \"servertokens\" : \"ProductOnly\",/g" /etc/cpanel/ea4/ea4.conf
ftag=$(grep -i FileETag /etc/cpanel/ea4/ea4.conf)
sed -i "s/$ftag/   \"fileetag\" : \"None\",/g" /etc/cpanel/ea4/ea4.conf
inde=$(grep -i Indexes  /etc/cpanel/ea4/ea4.conf)
sed -i "s/$inde/   \"root_options\" : \"ExecCGI FollowSymLinks IncludesNOEXEC \",/g" /etc/cpanel/ea4/ea4.conf > /dev/null 2>&1
/scripts/rebuildhttpdconf > /dev/null 2>&1
service httpd restart > /dev/null 2>&1


#disabling PHP functions
# Define the functions to disable
DISABLED_FUNCTIONS="symlink,shell_exec,exec,proc_close,proc_open,popen,system,dl,passthru,escapeshellarg,escapeshellcmd,phpinfo"

# Disable functions in EA-PHP versions
for PHP_INI in /opt/cpanel/ea-php*/root/etc/php.ini; do
    echo "Updating $PHP_INI"

    # Backup the php.ini file
    cp -p "$PHP_INI" "$PHP_INI.bak-$(date +%F-%T)"

    # Check if disable_functions is already present
    if grep -q "^disable_functions" "$PHP_INI"; then
        # Update the existing disable_functions line
        sed -i "s/^disable_functions.*/disable_functions = $DISABLED_FUNCTIONS/" "$PHP_INI"
    else
        # Add disable_functions line
        sed -i "/;disable_functions/a\disable_functions = $DISABLED_FUNCTIONS" "$PHP_INI"
    fi
done

# Disable functions in ALT-PHP versions
if [ -d /opt/alt/php56 ]; then
    for PHP_INI in /opt/alt/php*/etc/php.ini; do
        echo "Updating $PHP_INI"

        # Backup the php.ini file
        cp -p "$PHP_INI" "$PHP_INI.bak-$(date +%F-%T)"

        # Check if disable_functions is already present
        if grep -q "^disable_functions" "$PHP_INI"; then
            # Update the existing disable_functions line
            sed -i "s/^disable_functions.*/disable_functions = $DISABLED_FUNCTIONS/" "$PHP_INI"
        else
            # Add disable_functions line
            sed -i "/;disable_functions/a\disable_functions = $DISABLED_FUNCTIONS" "$PHP_INI"
        fi
    done
fi
echo -e "\e[1;32;40mPHP functions have been successfully disabled in all EA-PHP and ALT-PHP versions.\e[0m"
### Adding local-infile=0 to mysql configuration
add_local_infile_setting() {

    if grep -q "local-infile=0" /etc/my.cnf; then
        echo -e "\e[1;36;40m local-infile=0 already exists in the MySQL configuration. Skipping addition... \e[0m"
        echo -e "\e[1;36;40m Removing duplicate entries of local-infile=0... \e[0m"
        sed -i '/local-infile=0/!b;n;/local-infile=0/d' /etc/my.cnf
    else
        echo -e "\e[1;36;40m Adding local-infile=0 to MySQL configuration \e[0m"
        echo "local-infile=0" >> /etc/my.cnf
    fi

    echo -e "\e[1;36;40m Restarting MySQL \e[0m"
    service mysql restart > /dev/null 2>&1
}

#Tweaking WHM
#disabling compiler
echo -e " \e[1;36;40m Disabling compliers \e[0m "
/scripts/compilers off > /dev/null 2>&1

#enabling the cPHulk Brute Force Protection
whmapi1 enable_cphulk > /dev/null 2>&1

#Disabling Greylisting
whmapi1 disable_cpgreylist > /dev/null 2>&1

# Enable Referrer Security. WHM > Tweak Settings > Cookie IP validation
echo -e " \e[1;36;40m Referrer Security  \e[0m "
sed -i "s/^cookieipvalidation=strict$/cookieipvalidation=loose/g" /var/cpanel/cpanel.config

# Enable Referrer Security. WHM > Tweak Settings > Hide login password from cgi scripts
echo -e " \e[1;36;40m Referrer Security  \e[0m "
sed -i "s/^cgihidepass=0$/cgihidepass=1/g" /var/cpanel/cpanel.config

#Background Process Killer
echo -e "\e[1;36;40m Enabling Background Process Killer \e[0m"
cat <<EOT > /var/cpanel/killproc.conf
BitchX
bnc
eggdrop
generic-sniffers
guardservices
ircd
psyBNC
ptlink
services
EOT

# Enable shell bomb protection
/usr/local/cpanel/bin/install-login-profile --install limits

#Enable open_base_dir for the user
open_dir=$(grep -i phpopenbasedirhome /var/cpanel/cpanel.config)
sed -i "s/$open_dir/phpopenbasedirhome=1/g" /var/cpanel/cpanel.config
/scripts/restartsrv_cpsrvd > /dev/null 2>&1

# Enable Referrer Security. WHM > Tweak Settings > Referrer safety check
echo -e " \e[1;36;40m Referrer Security  \e[0m "
sed -i "s/^referrersafety=0$/referrersafety=1/g" /var/cpanel/cpanel.config

# Max hourly emails per domain. WHM > Tweak Settings > Max hourly emails per domain
echo -e " \e[1;36;40m Setting hourly email to 150  \e[0m "
sed -i "s/^maxemailsperhour$/maxemailsperhour=150/g" /var/cpanel/cpanel.config

#Disallow with Root Password on FTP
permroot=$(grep -i RootPassLogins /var/cpanel/conf/pureftpd/main)
sed -i "s/$permroot/RootPassLogins: \'no\'/g" /var/cpanel/conf/pureftpd/main

service cpanel restart > /dev/null 2>&1

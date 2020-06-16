#!/bin/bash

# System Upgrade
yum -y -q upgrade

# Disable SELinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Add Nginx Repo
echo -e "[nginx]\nname=nginx repo\nbaseurl=http://nginx.org/packages/centos/7/\$basearch/\ngpgcheck=0 \nenabled=1" > /etc/yum.repos.d/nginx.repo

# Add various other repos
yum install -y -q https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm https://centos7.iuscommunity.org/ius-release.rpm https://repo.percona.com/yum/percona-release-latest.noarch.rpm

# Replace pre-installed mariadb-libs with Percona dependency to avoid conflict
yum install -y -q Percona-Server-shared-compat-57

# Install various components
yum install -y -q nginx php71u-mcrypt php71u-tidy php71u-intl php71u-gd php71u-cli php71u-opcache php71u-common php71u-xmlrpc php71u-ldap php71u-mbstring php71u-process php71u-mysqlnd php71u-soap php71u-pdo php71u-json php71u-xml php71u-fpm php71u-bcmath Percona-Server-server-57 aspell graphviz

# MySQL Config
>/etc/my.cnf cat << EOF
[client]
default-character-set = utf8mb4

[mysqld]
innodb_buffer_pool_size = 128M
join_buffer_size = 128M
sort_buffer_size = 2M
read_rnd_buffer_size = 2M
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mysqld.log
innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_large_prefix
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
skip-character-set-client-handshake

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# Recommended in standard MySQL setup
sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES

[mysqld_safe]
pid-file=/var/run/mysqld/mysqld.pid

[mysql]
default-character-set = utf8mb4
EOF

# Moodle Config in nginx
>/etc/nginx/conf.d/moodle.conf cat << EOF
 #### GENERAL CONFIG OPTIONS // It is recommended to have this as a general common config in case we have multiple Moodle sites
 ## Compression
  gzip  on;
  gzip_buffers      16 24k;
  gzip_comp_level   6;
  gzip_http_version 1.1;
  gzip_min_length   50;
  gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/rss+xml
    application/rdf+xmli
    application/vnd.ms-fontobject
    application/x-font-opentype
    application/x-font-ttf
    application/x-javascript
    application/xhtml+xml
    application/xml
    application/xml+rss
    font/opentype
    image/svg+xml
    image/x-icon
    text/css
    text/javascript
    text/plain
    text/xml;
  gzip_vary         on;
  gzip_proxied      any;
  gzip_disable msie6;

## Size Limits
  client_body_buffer_size        64k;
  client_header_buffer_size      32k;
  client_max_body_size          512m;
  fastcgi_buffer_size           128k;
  fastcgi_buffers             256 8k;
  fastcgi_busy_buffers_size     256k;
  fastcgi_temp_file_write_size  256k;
  large_client_header_buffers 32 32k;
  map_hash_bucket_size           192;
  server_names_hash_bucket_size  512;
  server_names_hash_max_size    8192;
  types_hash_bucket_size         512;
  variables_hash_max_size       1024;

 ## Timeouts
  client_body_timeout            180;
  client_header_timeout          180;
  fastcgi_connect_timeout        120;
  fastcgi_read_timeout          1200;
  fastcgi_send_timeout          1200;
  send_timeout                  1200;
  proxy_read_timeout            1200;
  proxy_connect_timeout          120;


 ## Open File Performance
  open_file_cache max=100000 inactive=2m;
  open_file_cache_valid          2m;
  open_file_cache_min_uses         1;
  open_file_cache_errors          on;

 ## General Options
  ignore_invalid_headers          on;
  recursive_error_pages           on;
  reset_timedout_connection       on;
  fastcgi_intercept_errors        on;
  keepalive_requests           10000;
  server_tokens                  off;
  tcp_nopush                      on;
  tcp_nodelay                     on;

server {
    listen      80 default_server;

    server_name  "";
    root   /var/www/moodle/html;
    index  index.php index.html index.htm;

    location ~ \.php\$ {
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
    }

    location ~ ^(?P<script_name>.+\.php)(?P<path_info>/.+)$ {
        fastcgi_pass  127.0.0.1:9000;
        fastcgi_index  index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$script_name;
        fastcgi_param PATH_INFO \$path_info;
        fastcgi_param PATH_TRANSLATED \$document_root\$path_info;
    }

    location ~* \.(?:ico|css|js|gif|jpe?g|png)$ {
        expires 30d;
        add_header Pragma public;
        add_header Cache-Control "public";
    }
}
EOF

# Configure Moodle code
mkdir -p /var/www/moodle/html
mkdir -p /var/www/moodle/moodledata
wget -O /tmp/moodle.tgz https://download.moodle.org/stable37/moodle-latest-37.tgz
tar -xzf /tmp/moodle.tgz --strip-components=1 -C /var/www/moodle/html/
chown -R php-fpm.nginx /var/www/moodle/html
chown -R php-fpm.nginx /var/www/moodle/moodledata

# Moodle Config
>/var/www/moodle/html/config.php cat << EOF
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mysqli';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodle';
\$CFG->dbuser    = 'root'; //UNSECURE
\$CFG->dbpass    = 'Admin*123'; //UNSECURE
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot = 'http://moodle.vidyamantra.com';
\$CFG->dataroot  = '/var/www/moodle/moodledata';
\$CFG->admin     = 'admin';

\$CFG->directorypermissions = 0777;

// Enable debugging
@error_reporting(E_ALL | E_STRICT);   // NOT FOR PRODUCTION SERVERS!
@ini_set('display_errors', '1');         // NOT FOR PRODUCTION SERVERS!
\$CFG->debug = (E_ALL | E_STRICT);   // === DEBUG_DEVELOPER - NOT FOR PRODUCTION SERVERS!
\$CFG->debugdisplay = 1;              // NOT FOR PRODUCTION SERVERS!

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

# php
sed -i 's/max_execution_time =.*/max_execution_time=300/' /etc/php.ini
sed -i 's/max_input_time =.*/max_input_time=600/' /etc/php.ini
sed -i 's/memory_limit =.*/memory_limit=2048M/' /etc/php.ini
sed -i 's/post_max_size =.*/post_max_size=512M/' /etc/php.ini
sed -i 's/upload_max_filesize =.*/upload_max_filesize=512M/' /etc/php.ini

# opcache
mkdir -p /var/www/.opcache
sed -i 's/;opcache.file_cache=.*/opcache.file_cache=\/var\/www\/.opcache/' /etc/php.d/10-opcache.ini
sed -i 's/opcache.memory_consumption=.*/opcache.memory_consumption=512/' /etc/php.d/10-opcache.ini
sed -i 's/opcache.max_accelerated_files=.*/opcache.max_accelerated_files=12000/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.revalidate_freq=.*/opcache.revalidate_freq=60/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.use_cwd=.*/opcache.use_cwd=1/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.validate_timestamps=.*/opcache.validate_timestamps=1/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.save_comments=.*/opcache.save_comments=1/' /etc/php.d/10-opcache.ini
sed -i 's/;opcache.enable_file_override=.*/opcache.enable_file_override=0/' /etc/php.d/10-opcache.ini

# Add to startup
systemctl enable nginx
systemctl enable php-fpm
systemctl enable mysqld

# Start services
systemctl start nginx
systemctl start php-fpm
systemctl start mysql

# Change MySQL default password
export PW=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $11}')
mysqladmin -u root -p$PW password Admin*123

# Create database, create user & grant permission
mysql -uroot -pAdmin*123 -e "create database moodle"

# Redirect wwwroot to host file
echo "127.0.0.1  moodle.vidyamantra.com" >> /etc/hosts

# Setup Moodle cron
# Remove HTTP_HOST from Moodle config and cron
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/php /var/www/moodle/html/admin/cli/cron.php  >/dev/null") | crontab -

# Open Moodle in Browser
gio open "http://moodle.vidyamantra.com"

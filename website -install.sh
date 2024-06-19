#!/bin/bash

# Variables
DOMAIN=$1
MYSQL_ROOT_PASSWORD=""
MYSQL_WP_DB="XXXX"
MYSQL_WP_USER="XXXX"
MYSQL_WP_PASSWORD="XXXX"

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Ensure a domain name is provided
if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 PUTYOURDOMAINNAME.HERE"
  exit 1
fi

# Update and install necessary packages
apt update
apt install -y apache2 mysql-server php php-mysql libapache2-mod-php php-cli certbot python3-certbot-apache unzip wget

# Secure MySQL installation (optional)
mysql_secure_installation <<EOF

y
$MYSQL_ROOT_PASSWORD
$MYSQL_ROOT_PASSWORD
y
y
y
y
EOF

# Create MySQL database and user for WordPress
mysql -u root -p$MYSQL_ROOT_PASSWORD <<EOF
CREATE DATABASE $MYSQL_WP_DB;
CREATE USER '$MYSQL_WP_USER'@'localhost' IDENTIFIED BY '$MYSQL_WP_PASSWORD';
GRANT ALL PRIVILEGES ON $MYSQL_WP_DB.* TO '$MYSQL_WP_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# Download and install WordPress
wget https://wordpress.org/latest.zip
unzip latest.zip
mv wordpress /var/www/$DOMAIN

# Set the correct permissions
chown -R www-data:www-data /var/www/$DOMAIN
chmod -R 755 /var/www/$DOMAIN

# Create Apache virtual host configuration
cat <<EOL >/etc/apache2/sites-available/$DOMAIN.conf
<VirtualHost *:80>
    ServerAdmin admin@$DOMAIN
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot /var/www/$DOMAIN
    <Directory /var/www/$DOMAIN>
        AllowOverride All
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN_error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN_access.log combined
</VirtualHost>
EOL

# Enable the new site and rewrite module
a2ensite $DOMAIN.conf
a2enmod rewrite

# Restart Apache to apply changes
systemctl restart apache2

# Obtain SSL certificate and configure HTTPS
certbot --apache -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email PUT@EMAIL.HERE

# Create wp-config.php for WordPress
cp /var/www/$DOMAIN/wp-config-sample.php /var/www/$DOMAIN/wp-config.php

sed -i "s/database_name_here/$MYSQL_WP_DB/" /var/www/$DOMAIN/wp-config.php
sed -i "s/username_here/$MYSQL_WP_USER/" /var/www/$DOMAIN/wp-config.php
sed -i "s/password_here/$MYSQL_WP_PASSWORD/" /var/www/$DOMAIN/wp-config.php

# Generate unique salts and keys for WordPress
SALT=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s /var/www/$DOMAIN/wp-config.php

# Finalize
systemctl reload apache2

echo "Installation and configuration complete. Visit http://$DOMAIN to finish the WordPress setup."

#!/usr/bin/env bash

# vagrant provision --provision-with install_magento

set -ex

# Determine external IP address
set +x
IP=`ifconfig eth1 | grep inet | awk '{print $2}' | sed 's/addr://'`
echo "IP address is '${IP}'"
set -x

# Determine hostname for Magento web-site
HOST=`hostname -f`
if [ -z ${HOST} ]; then
    # Use external IP address as hostname
    set +x
    HOST=${IP}
    echo "Use IP address '${HOST}' as hostname"
    set -x
fi

magento_dir="/var/www/magento2ce"
cd ${magento_dir}

# Clear cache
mv var/.htaccess .var_htaccess.back && rm -rf var/* && mv .var_htaccess.back var/.htaccess
mv pub/static/.htaccess pub/static_htaccess.back && rm -rf pub/static/* && mv pub/static_htaccess.back pub/static/.htaccess
cd "${magento_dir}/dev/tests/integration" && mv tmp/.gitignore tmp_gitignore.back && rm -rf tmp/* && mv tmp_gitignore.back tmp/.gitignore
cd "${magento_dir}/dev/tests/unit" && rm -rf tmp/*

# Remove configuration files
rm -f "${magento_dir}/app/etc/config.php"
rm -f "${magento_dir}/app/etc/env.php"

# Create DB
db_name="magento"
mysql -u root -ppassword -e "drop database if exists ${db_name}; create database ${db_name};"
mysql -u root -ppassword -e "GRANT ALL ON ${db_name}.* TO magento@localhost IDENTIFIED BY 'magento';"

# Install Magento application
cd ${magento_dir}
github_token="/vagrant/local.config/github.oauth.token"
if [ -f ${github_token} ]; then
    set +x
    echo "Installing GitHub OAuth token from ${github_token}..."
    composer config -g github-oauth.github.com `cat ${github_token}`
    set -x
    composer install
else
    composer install --prefer-source
fi

admin_frontame="admin"
install_cmd="./bin/magento setup:install \
    --db-host=localhost \
    --db-name=magento \
    --db-user=magento \
    --db-password=magento \
    --backend-frontname=${admin_frontame} \
    --base-url=http://${HOST}/ \
    --language=en_US \
    --timezone=America/Chicago \
    --currency=USD \
    --admin-lastname=Admin \
    --admin-firstname=Admin \
    --admin-email=admin@example.com \
    --admin-user=admin \
    --admin-password=123123q \
    --cleanup-database \
    --use-rewrites=1"
chmod +x bin/magento
php ${install_cmd}

chown -R vagrant:vagrant ${magento_dir}

# Enable Magento cron jobs
echo "* * * * * php ${magento_dir}/bin/magento cron:run &" | crontab -u vagrant -

set +x
echo "
Magento application was deployed in ${magento_dir} and installed successfully
Access storefront at http://${HOST}/
Access admin panel at http://${HOST}/${admin_frontame}/

Don't forget to update your 'hosts' file with '${IP} ${HOST}'

[Optional] To finish developer environment set up:
    1. Please create new PHPStorm project using 'magento2ce' directory on your host
    (this directory should already contain Magento repository cloned earlier)

    2. Use instructions provided here https://github.com/paliarush/vagrant-magento/blob/master/docs/phpstorm-configuration.md
    to set up synchronization in PHPStorm (or using rsync) with ${magento_dir} directory"
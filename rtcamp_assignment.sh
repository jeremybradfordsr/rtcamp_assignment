#!/usr/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
export 'DEBIAN_FRONTEND=noninteractive'
services='nginx mysql php7.3-fpm'
packages='nginx mysql-server php-fpm php-mysql wget unzip links'
echo "Updating package lists"
apt-get update &> /dev/null
echo "Downloading the following packages and dependencies for nginx, php, mysql, links, unzip and wget"
for package in $packages
 do
 dpkg -s $package &> /dev/null
if [ $? -eq 0 ];
then
    echo  $package "is installed! No action needed"
else
    echo  $package "is NOT installed. Installing "$package

     apt-get install -y  --no-install-recommends $package &> /dev/null
fi
done


for service in $services
do
 service $service start
done


while true; do
  echo "Enter FQDN name of host"
  read hostname
  fqdn=`echo $hostname | grep -P '(?=^.{1,254}$)(^(?>(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+(?:[a-zA-Z]{2,})$)'`

    if [[ -z "$fqdn" ]]
      then
        echo "Please enter FQDN name of host"
      else
         echo "bad"
         break
    fi
done


 echo "127.0.0.2 $hostname" >> /etc/hosts

 echo "server {
listen 80;
root /var/www/$hostname;
server_name $hostname;
access_log /var/log/nginx/$hostname-client_access.log;
error_log /var/log/nginx/'$hostname-client_error.log;

location / {
    index                               index.php index.html;
    try_files                           \$uri \$uri/ /index.php?\$args;
}

        charset                         utf-8;
        gzip                            off;
        rewrite /wp-admin\$ \$scheme://\$host\$uri/ permanent;
location ~ /\. {
        access_log                      off;
        log_not_found                   off;
        deny                            all;
}
location ~* ^.+.(xml|ogg|ogv|svg|svgz|eot|otf|woff|mp4|ttf|css|rss|atom|js|jpg|jpeg|gif|png|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf)\$ {
        access_log                      off;
        log_not_found                   off;
        expires                         max;
}

location ~ \.php\$ {
        try_files                       \$uri =404;
        include                         /etc/nginx/fastcgi_params;
        fastcgi_read_timeout            3600s;
        fastcgi_buffer_size             128k;
        fastcgi_buffers                 4 128k;
        fastcgi_param                   SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass                    unix:/run/php/php7.3-fpm.sock;
        fastcgi_index                   index.php;
}
         location = /robots.txt {
               allow all;
               log_not_found off;
               access_log off;
        }
location ~* /(?:uploads|files)/.*\.php\$ {
 deny all;
}
}" >  /etc/nginx/conf.d/"$hostname".conf


mySQLPasswordTemp=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
mySQLRootPasswordTemp=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
mySQLRootPassword=$mySQLRootPasswordTemp
mySQLPassword=$mySQLPasswordTemp
hostname_db=$(echo $hostname"_db")
 mysqladmin create $hostname_db;
 echo "CREATE USER '$hostname'@'localhost' IDENTIFIED BY '$mysqlPassword'" |  mysql
 echo "GRANT ALL PRIVILEGES ON *.* TO '$hostname'@'localhost';" |  mysql
 echo "ALTER USER '$hostname'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mySQLPassword';"|  mysql
 echo "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mySQLRootPassword';"|  mysql
 service mysql restart

 wget -O /tmp/wordpress.zip http://wordpress.org/latest.zip
 unzip /tmp/wordpress.zip > /dev/null
 mv wordpress/ /var/www/$hostname

 cp /var/www/$hostname/wp-config-sample.php /var/www/$hostname/wp-config.php
 sed -i "s/database_name_here/$hostname_db/g" /var/www/$hostname/wp-config.php
 sed -i "s/username_here/$hostname/g" /var/www/$hostname/wp-config.php
 sed -i "s/password_here/$mySQLPassword/g" /var/www/$hostname/wp-config.php

for service in $services
do
 service $service restart
done

chown -R www-data:www-data /var/www/$hostname/

wpAdminPasswordTemp=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
wpAdminPassword=$wpAdminPasswordTemp
 wget -O /usr/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
 chmod +x /usr/bin/wp
(cd /var/www/$hostname/ ;sudo -u www-data wp db create)
(cd /var/www/$hostname/ ;sudo -u www-data wp core install --url=$hostname --title="$hostname's blog" --admin_user=$hostname-admin --admin_password=wpAdminPasswordTemp --admin_email=info@$hostname)
echo "Success: WordPress installed successfully."


echo "Site URL: http://$hostname Database: $hostname_db"
echo "Root Database Password: $mySQLRootPassword"
echo "$hostname Database password: $mySQLPassword"
echo "Do you wish to launch a browser and load the site?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) links http://$hostname; break;;
        No ) exit;;
    esac
done

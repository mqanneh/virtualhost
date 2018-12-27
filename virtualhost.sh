#!/bin/bash
### Set Language
TEXTDOMAIN=virtualhost

### Set default parameters
action=$1
domain=$2
rootDir=$3
webRootDir=$4
owner=$(who am i | awk '{print $1}')
apacheUser=$(ps -ef | egrep '(httpd|apache2|apache)' | grep -v root | head -n1 | awk '{print $1}')
email='mqanneh@gmail.com'
sitesEnabled='/etc/apache2/sites-enabled/'
sitesAvailable='/etc/apache2/sites-available/'
userDir='/home/mqanneh/Projects/'
sitesAvailabledomain=$sitesAvailable$domain.conf

### don't modify from here unless you know what you are doing ####

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
		exit 1;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"You need to prompt for action (create or delete) -- Lower-case only"
		exit 1;
fi

while [ "$domain" == "" ]
do
	echo -e $"Please provide domain. e.g. dev.drupal8site.local, stg.drupal8site.local"
	read domain
done

while [ "$rootDir" == "" ]
do
	echo -e $"Please provide root directory. e.g. drupal8site"
	read rootDir
done

while [ "$webRootDir" == "" ]
do
	echo -e $"Please provide web root directory. e.g. web, docroot"
	read webRootDir
done

### if root dir starts with '/', don't use /var/www as default starting point
if [[ "$rootDir" =~ ^/ ]]; then
	userDir=''
fi

rootDir=$userDir$rootDir

if [ "$action" == 'create' ]
	then
		### check if domain already exists
		if [ -e $sitesAvailable$domain.conf ]; then
			echo -e $"This domain $sitesAvailable$domain already exists.\nPlease Try Another one"
			exit;
		fi

		### check if directory exists or not
		if ! [ -d $rootDir ]; then
			### create the directory
			mkdir $rootDir
			### give permission to root dir
			chmod 775 $rootDir
			### create additional sub directories
			mkdir $rootDir/db_backups
			mkdir $rootDir/designs
			mkdir $rootDir/docs
			mkdir $rootDir/logs
			mkdir $rootDir/www
			mkdir $rootDir/www/$webRootDir
			### give permission to root dir
			chmod 775 $rootDir
			chmod 775 $rootDir/db_backups
			chmod 775 $rootDir/designs
			chmod 775 $rootDir/docs
			chmod 775 $rootDir/logs
			chmod 775 $rootDir/www
			chmod 775 $rootDir/www/$webRootDir
			### write test file in the new domain dir
			if ! echo "<?php echo phpinfo(); ?>" > $rootDir/www/$webRootDir/index.php
			then
				echo $"ERROR: Not able to write in file $rootDir/www/$webRootDir/index.php. Please check permissions"
				exit;
			else
				echo $"Added content to $rootDir/www/$webRootDir/index.php"
			fi
		fi

		### create virtual host rules file
		if ! echo "<VirtualHost *:80>
	ServerAdmin $email
	ServerName $domain
	ServerAlias $domain www.$domain
	DocumentRoot $rootDir/www/$webRootDir
	<Directory />
		Options Indexes FollowSymLinks MultiViews
		AllowOverride all
		Require all granted
	</Directory>
	<Directory $rootDir/www/$webRootDir>
		Options Indexes FollowSymLinks MultiViews
		AllowOverride all
		Require all granted
	</Directory>
	ErrorLog $rootDir/logs/error_log.log
	LogLevel error
	CustomLog $rootDir/logs/access_log.log combined
</VirtualHost>" > $sitesAvailable$domain.conf
		then
			echo -e $"There is an ERROR creating $domain file"
			exit;
		else
			echo -e $"\nNew Virtual Host Created\n"
		fi

		### Add domain in /etc/hosts
		if ! echo "127.0.0.1	$domain www.$domain" >> /etc/hosts
		then
			echo $"ERROR: Not able to write in /etc/hosts"
			exit;
		else
			echo -e $"Host added to /etc/hosts file \n"
		fi

		if [ "$owner" == "" ]; then
			chown -R mqanneh:mqanneh $rootDir
		fi

		### enable website
		echo $domain
		a2ensite $domain

		### restart Apache
		/etc/init.d/apache2 reload

		### show the finished message
		echo -e $"Complete! \nYou now have a new Virtual Host \nYour new host is: http://$domain \nAnd its located at $rootDir"
		exit;
	else
		### check whether domain already exists
		if ! [ -e $sitesAvailable$domain.conf ]; then
			echo -e $"This domain does not exist.\nPlease try another one"
			exit;
		else
			### Delete domain in /etc/hosts
			newhost=${domain//./\\.}
			sed -i "/$newhost/d" /etc/hosts

			### disable website
			a2dissite $domain

			### restart Apache
			/etc/init.d/apache2 reload

			### Delete virtual host rules files
			rm $sitesAvailable$domain.conf
		fi

		### check if directory exists or not
		if [ -d $rootDir ]; then
			echo -e $"Delete host root directory ? (y/n)"
			read deldir

			if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then
				### Delete the directory
				rm -rf $rootDir
				echo -e $"Directory deleted"
			else
				echo -e $"Host directory conserved"
			fi
		else
			echo -e $"Host directory not found. Ignored"
		fi

		### show the finished message
		echo -e $"Complete!\nYou just removed Virtual Host $domain"
		exit 0;
fi

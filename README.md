# Janus container [work in progress - !!DOES NOT WORK YET!!]

## Introduction
This is an experimental project attempting to put Janus gatweay into a Docker container using the default *bridge* network driver. 
Please note that this project is not intended to be used as a *product* (although in the future it may evolve in that direction) but instead as 
an experimentation and conclusion sharing platform.

## Installation procedure
This section provides the default installation procedure. This is a single host installation, the host will allow to build and run the 
docker image. The default configuration allows to access the server only through HTTPs using the host's obtanied Letsencrypt certificates. 
Please note that this project is using Ubuntu 18.04-LTS Linux distribution. Although it has been tried 
only on that specific distribution, a priori, there are no reasons for it not to work on any other fairly recent distribution.

### Build/docker experimental host installation
First let's install a Janus host for building and running the docker image. 
1. Install Ubuntu 18.04 physical or virtual host with the default packages and using the default parameters. Make sure that you have 
access to a sudo capable user. We assume that the host is directly connected to the internet through a 1-to-1 NAT. 
	1. Make sure that the 1-to-1 NAT redirects the following ports: 80 (http), 443 (https), 8089 (janus-api), 7889 (janus-admin) to the Janus host.
	1. Reserve a name for your host in your domain (e.g. <host>.<domain>) and update the */etc/hosts* file accordingly
		```bash
		127.0.0.1 localhost <host>.<domain>
		[...]
		```
1. Install docker following [these](https://docs.docker.com/engine/install/ubuntu/) instructions then follow [these](https://docs.docker.com/engine/install/linux-postinstall/)
steps for some additional convenience settings.
1. Install Nginx HTTP server. We need NGINX to automate the [Letsencrypt](https://letsencrypt.org/) certificate updates using the 
[Certbot](https://certbot.eff.org/) and for serving the janus html examples (from the /var/www/html/container directory) 
	```bash
	sudo apt install nginx
	sudo apt update
	```
1. Install the TLS certificates and the automatic certificate update service
	1. Add the Certbot PPA to your list of repositories
		```bash
		sudo apt install software-properties-common
		sudo add-apt-repository universe
		sudo add-apt-repository ppa:certbot/certbot
		sudo apt update
		```
	1. Install Certbot
		```bash
		sudo apt install certbot python-certbot-nginx
		```
	1. Get the certificates
		>>>
		<b>sudo certbot certonly --nginx</b>
		
		Saving debug log to /var/log/letsencrypt/letsencrypt.log
		Plugins selected: Authenticator nginx, Installer nginx
		Enter email address (used for urgent renewal and security notices) (Enter 'c' to
		cancel): <b>\<your e-mail address\></b>

		- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		Please read the Terms of Service at
		https://letsencrypt.org/documents/LE-SA-v1.2-November-15-2017.pdf. You must
		agree in order to register with the ACME server at
		https://acme-v02.api.letsencrypt.org/directory
		- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		(A)gree/(C)ancel: <b>A</b>

		- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		Would you be willing to share your email address with the Electronic Frontier
		Foundation, a founding partner of the Let's Encrypt project and the non-profit
		organization that develops Certbot? We'd like to send you email about our work
		encrypting the web, EFF news, campaigns, and ways to support digital freedom.
		- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
		(Y)es/(N)o: <b>N</b>
		No names were found in your configuration files. Please enter in your domain
		name(s) (comma and/or space separated) (Enter 'c' to cancel): <b>\<host\>.\<domain\><b/>
		
		Obtaining a new certificate
		Performing the following challenges:
		http-01 challenge for bart-test-access.eastus.cloudapp.azure.com
		Waiting for verification...
		Cleaning up challenges

		IMPORTANT NOTES:
		- Congratulations! Your certificate and chain have been saved at:
		/etc/letsencrypt/live/bart-test-access.eastus.cloudapp.azure.com/fullchain.pem
		Your key file has been saved at:
		/etc/letsencrypt/live/bart-test-access.eastus.cloudapp.azure.com/privkey.pem
		Your cert will expire on 2020-05-04. To obtain a new or tweaked
		version of this certificate in the future, simply run certbot
		again. To non-interactively renew *all* of your certificates, run
		"certbot renew"
		- If you like Certbot, please consider supporting our work by:

		Donating to ISRG / Let's Encrypt: https://letsencrypt.org/donate
		Donating to EFF: https://eff.org/donate-le
		>>>
	1. As specified in the output above the certificates may be found here:
		```bash
		/etc/letsencrypt/live/<host>.<domain>/fullchain.pem
		/etc/letsencrypt/live/<host>.<domain>/privkey.pem
		```
	**These files are links from the */etc/letsencrypt/live/archive* directory. Make sure the non *root* user has 
	read access to these files.**
	1. You may test the Certbot certificate renewal by issuing the following command:
		```bash
		certbot renew --dry-run --allow-subset-of-names
		```
1. Clone the project repo
	```bash
	git clone https://github.com/bartbalaz/janus-container.git
	cd janus-container
	```
1. Create a http server configuration
	1. Copy the configuration file 
		```bash
		sudo mkdir /var/www/html/container
		sudo cp ./scripts/nginx.conf /etc/nginx/sites-available/<host>.<domain>.conf
		sudo ln -s /etc/nginx/sites-available/<host>.<domain>.conf /etc/nginx/sites-enabled/
		```
	1. Edit the configuration file */etc/nginx/sites-available/<host>.<domain>.conf* and replace the *<host>.<domain>* place holder
	with your appropriate value.
	1. Restart the Nginx server
		```bash
		sudo systemctl restart nginx
		```
	
1. Install the tools necessary for building janus-gateway
	```bash
	sudo apt update
	sudo apt install -y python3-pip libcurl4-openssl-dev libconfig-dev libjansson-dev libglib2.0-dev libssl-dev build-essential graphviz default-jdk flex bison cmake libtool automake liblua5.3-dev pkg-config gengetopt 
	sudo pip3 install meson
	sudo pip3 install ninja
	```
	These additional dependencies are required for building the post-processing tool
	```bash
	sudo apt install -y libavutil-dev libavcodec-dev libavformat-dev libogg-dev
	```
	
## Build procedure



## Experimentation and observations



## Conclusion






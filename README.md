# Janus container

## Introduction
This project creates the Janus Gateway Docker image and provides the procedure to set up the container using the default *bridge* network driver. There are multiple 
advantages to support this configuration such as it avoids having to reserve dedicated IP address per container, configuring/parameterizing the image to use different
 sets of ports internally and makes automatic scaling much easier. The default *bridge* configuration has the most constraints hence images supporting it will support 
 most of other configurations.

The strategy followed in this project is to create a build Docker image (build image for short) first. The build image runs the Docker tools as well as the Janus build environment. 
It compiles and creates the target Janus gateway image (target image for short). This allows to create a substantially smaller target image than if a single image combining 
the build and execution was built (~300MB vs ~1.6GB). We provide two ways of building the images, the first one is manual that requires a Docker 
host that purpose is to build, store and run the target images. This build process is orchestrated by the _container.sh_ script. The second build method is directly using 
[GitLab](https://about.gitlab.com/) Continous Integration (CI) scheme orchestrated by the _.gitlab-ci.yml_ script. This method requires a GitLab setup that includes Kubernetes 
executors and has access to a registry (e.g. the GitLab internal container registry) for storing the created images. The second method also requires a Docker host for 
executing the target image.\
We also provide a very simple procedure for deploying the target Janus Gteway image on Azure Kubernetes Service (AKS) using [Helm charts](https://helm.sh/docs/topics/charts/).\
Finally, at the bottom of this page in the _Experimentation and observations section_, we have added a discussion about some limitations that need to be considered 
when deploying the target image.

Notes:
* Please visit [Meetecho Janus project](https://janus.conf.meetecho.com/docs/) for a detailed description of the Janus gateway.
* Out-of-the-box this project provides the simplest single host Docker configuration which may be tailored to any other more complex configuration. The 
procedure below allows to setup a single host running the Janus Gateway in a Docker container accessed using HTTPS only and relying on the host for certificate management. 
This procedure may be greately simplified by modifying the Janus Gateway configuraiton to avoid mounting multiple host folders, avoiding the installation of Certbot and 
the HTTP server (Nginx) etc. and, allowing instead, to simply run the Janus Gateway image.
* Only the video room plug-in (and echo test plug-in) with HTTP transport have been tried. Possibly, other plug-ins and transports will require adjustments in the content of the 
target image (e.g. included Ubuntu packages).
* The author welcomes questions, comments and suggestions!

## Execution host setup
The figure below depicts the host configuration.

![Host setup](doc/host_setup.jpg)

The host contains the following components:
* Docker engine for executing the build and target images.
* Nginx HTTP server for allowing Certbot automatic Letsencrypt certificates update and for serving the Janus HTML samples.
* Cetbot certificate renewal service.

The Janus target image mounts the following host volumes:
* */var/www/html/container* (to container */html*): Upon startup the target image copies the content of the folder containing the Janus HTML samples. This folder is accessible through HTTPS. 
Please note that the /var/www/html folder contains the Nginx default index.html page which is accessible through HTTP. Its purpose is to allow Letsencrypt host validation.
* */var/janus/recordings* (to container */janus/bin/janus-recordings*): This folder is used by the target image to store the video room recordings (when enabled).
* */etc/letsencrypt/live/* (to container */etc/certs*) and */etc/letsecrypt/archive* (to container */archive*): These folders contain the links and Letsencrypt certificates required for TLS and DTLS 
shared by both Nginx and Janus gateway
* *\<Janus config host folder\>* (to container */janus/etc/janus_host*: Optionally (when the _RUN_WITH_HOST_CONFIGURATION_DIR_ environment variable is set) 
the target image may mount a configuration folder from the host, this configuration will override the built-in configuration.

The Janus build image mounts the following host volume:
* */var/run/docker.sock* (to container */var/run/docker.sock*) enables the build image to use the Docker service from the host.
* *\<clone directory\>/janus_config*, when the BUILD_WITH_HOST_CONFIG_DIR build parameter is set to 'true' the host janus configuration directory will be mounted and used in the 
target image creation process instead of using the default configuration that has been embedded into the build image during the build image creation.

## Process
The figure below depicts the target image creation process.

![Process](doc/process.jpg)

The process consists in the following steps:
1. *Preparation*: The project is cloned from the Github repository. The default Janus gateway server configuration in _\<clone directory\>/janus_config_ sub-folder is reviewed and modified according 
to the requirements of the target image. It is possible to add a _bash_ script that will create the configuration Janus Gateway configuration files (see *Target image execution* step). 
When building using the GitLab CI this step has to be performed before the commit that triggers the build process.
1. *Build image creation*: Triggered by manually invoking the *container.sh* or automatically (CI) invoking *.gitlab-ci.yml*. The build relies on *Dockerfile.build* and *setup.sh* scripts along with 
some environment variables (*see below*) to install the necessary components of the build image. The Janus gateway configuration along with the *start.sh* script are stored in the build image making 
it self contained during the *Target Image creation* step (i.e. when the _BUILD_WITH_HOST_CONFIG_DIR_ is set to false).
1. *Target Image creation*: Once the build image is created the *container.sh* or *.gitlab-ci.yml* scripts trigger the target image build process that relies on *Dockerfile.exec* and *build.sh* scripts, 
stored in the build image (*/image* directory) in the previous step. In this step, the required version of the Janus software is cloned and checked out as specified by the _JANUS_REPO_ and _JANUS_VERSION_ 
environment variables. Binary and source dependencies are fetched. The whole package is compiled and the target image is created. When building using the manual procedure (*container.sh*), instead of using 
the embedded Janus gateway configuration it is possible, by defining the _BUILD_WITH_HOST_CONFIG_DIR_ variable, to mount the _\<clone directory\>/janus_config_, containing Janus gateway configuration. 
In that case configuration from the mounted directory will be copied into the target image instead of using the configuration embedded into the build image. Please note that if you would like to update 
files that are used by the target image or target image build porcess (so far only the _start.sh_ and _Dockerfile.exec_ scripts fall into this category) you must **recreate** the build image.
1. *Target image execution*: The created target image contains a *start.sh* script that is configured as the entry point. This scripts copies the Janus HTML samples, if the environment 
variable _COPY_JANUS_SAMPLES_ is set to "true", and invokes the Janus gateway application. If _RUN_WITH_HOST_CONFIGURATION_DIR_ is set to "true" the *start.sh* script will use the Janus 
configuration host folder mounted inside the container at _/janus/etc/janus_host_ instead of using the embedded configuration located in _/janus/etc/janus_ directory. Also _CONFIG_GEN_SCRIPT_
may specify the name of a _bash_ script that creates the configuraiton files. This variable conains the name of the script that may either be embedded in the Target image (_/janus/etc/janus_ directory)
or provided by the host (_/janus/etc/janus_host_ directory) when the _RUN_WITH_HOST_CONFIGURATION_DIR_ is set to "true". The configuration creation script will be triggered by the _start.sh_ script 
at container startup. The script for generating the configuration may rely on additional environment vaiable parameters.

## Build/execution host installation
This section provides the default installation procedure. The default configuration allows to access the Janus Gateway server only through HTTPs using the host's 
obtanied Letsencrypt certificates. Please note that this project is using Ubuntu 18.04-LTS Linux distribution. Although it has been tried 
only on that specific version, a priori, there are no reasons for it not to work on any other recent version of the Ubuntu distribution.

1. Provision  Ubuntu 18.04 physical or virtual host with the default packages and using the default parameters. Make sure that you have 
access to a *sudo* capable user. We assume that the host is directly connected to the Internet through a 1-to-1 NAT. 
	1. Make sure that the 1-to-1 NAT redirects the following ports: 80 (http), 443 (https), 8089 (janus-api), 7889 (janus-admin) to the Janus host.
	1. Reserve a name for your host in your domain (e.g. \<host\>.\<domain\>) and update the */etc/hosts* file accordingly, for example:
		```bash
		127.0.0.1 localhost <host>.<domain>
		[...]
		```
1. Install Docker following [these](https://docs.docker.com/engine/install/ubuntu/) instructions then follow 
[these](https://docs.docker.com/engine/install/linux-postinstall/) steps for some additional convenience settings. Please note that the 
build process includes also the option to use Podman instead of Docker but Podman only allows to create the build image. It does not work 
yet for the target image creation. If yo wish to experiment with Podman you may use [these](https://podman.io/getting-started/installation.html)
installation instructions. Both Podman and Docker may be installed on the same host.
1. Install Nginx HTTP server. We need NGINX to automate the [Letsencrypt](https://letsencrypt.org/) certificate updates using the 
[Certbot](https://certbot.eff.org/) and for serving the janus HTML examples (from the /var/www/html/container host directory) 
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
		```bash
		sudo certbot certonly --nginx
		```
		>>>
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
		name(s) (comma and/or space separated) (Enter 'c' to cancel): <b>\<host\>.\<domain\></b>
		
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
	**These files are links from the */etc/letsencrypt/archive* directory.**
	
	**!!VERY IMPORTANT!! Make sure that NON _root_ users have _read_ access to the links and the certificates.**
	```bash
	chmod -R a+r+x /etc/letsencrypt/live
	chmod -R a+r+x /etc/letsencrypt/archive
	```
	1. You may test the Certbot certificate renewal by issuing the following command:
		```bash
		sudo certbot renew --dry-run --allow-subset-of-names
		```
1. Clone the project repo
	```bash
	git clone https://github.com/bartbalaz/janus-container.git <clone directory>
	cd <clone directory>
	```
1. Create a http server configuration
	1. Copy the configuration file 
		```bash
		sudo mkdir /var/www/html/container
		cd <clone directory>
		sudo cp ./scripts/nginx.conf /etc/nginx/sites-available/<host>.<domain>.conf
		sudo ln -s /etc/nginx/sites-available/<host>.<domain>.conf /etc/nginx/sites-enabled/
		```
		Note that the */var/www/html/container* directory will be used to store the Janus HTML samples.
	1. Edit the configuration file */etc/nginx/sites-available/\<host\>.\<domain\>.conf* and replace the *\<host\>.\<domain\>* place holder
	with your host and domain name.
	1. Restart the Nginx server
		```bash
		sudo systemctl restart nginx
		```
1. Create a recording folder
	```bash
	sudo mkdir -p /var/janus/recordings
	```
## Manual build procedure
This procedure allows to create build and target images on a simple Docker host.

1. Set the build parameters environment variables by issuing the _export_ command for each parameter or by editing the _\<clone directory\>/scripts/config_ file and 
issuing the _source_ command. All the available parameters are sumarized in the table below.
	```bash 
	# Set each parmeter individually 
	export SOME_PARAMETER=some_value
	
	# Or set all the parameters saved in the config file
	cd <clone directory>
	source scripts/config
	```

Parameter | Mandatory (Y/N/C) | Default | Process step | Description 
 :---: | :---: | :---: | :---: |:--- 
_IMAGE_REGISTRY_ | N | not set | 2, 3 | Registry for storing both the build and target images, including the project/user folder if necessary (i.e. docker.io/some_project).
_IMAGE_REGISTRY_USER_ | N | not set | 2, 3 | Registry user name
_IMAGE_REGISTRY_PASSWORD_ | N | not set | 2, 3 | Registry user password
_BUILD_IMAGE_NAME_ | N | janus_build | 2, 3 | Name of the build image
_BUILD_IMAGE_TAG_ | N | latest | 2, 3 | The version to tag the build image with
_IMAGE_TOOL_ | N | docker | 2, 3 | Tool for creating and managing the images, either "podman", "docker" or "external" when image building is handled outside of the project scripts (e.g. by Gitlab CI )
_HOST_NAME_ | N | \<host\>.\<domain\> | 3 |  Name of the host in full fqdn format. This value is only used in displaying the execution command at the end of an successful build
_JANUS_REPO_ | N | https://github.com/meetecho/janus-gateway.git | 3 | Repository to fetch Janus gatway sources from
_JANUS_VERSION_ | N | master | 3 |  Version of the Janus gateway sources to checkout (e.g. v0.10.0). If none is specified the master branch latest available version will be used
_TARGET_IMAGE_NAME_ | N | janus | 3 | Target image name
_TARGET_IMAGE_TAG_ | N | latest | 3 | The version to tag the target image with
_SKIP_BUILD_IMAGE_ | N | false | 3 | When set to "true" the build image will not be build
_SKIP_TARGET_IMAGE_ | N | false | 3 | When set to "true" the target image will not be build
_BUILD_WITH_HOST_CONFIG_DIR_ | N | false | 3 | When set to "true" the build image will mount the host Janus gateway configuration directory (i.e. <clone directory>/janus-config) instead of using the one that was copied during the build image creation
_RUN_WITH_HOST_CONFIGURATION_DIR_ | N | false | 4 | When set to "true" the image execution command displayed at the end of the successful build will add an option to use host Janus server configuration directory (i.e. <clone directory>/janus-config) instead of the embedded configuration during the target image creation process
_COPY_JANUS_SAMPLES_ | N | false | 4 | When set to "true" the image execution command displayed at the end of the successful build will add an option to trigger the image to copy the Janus HTML samples to a mounted folder
_CONFIG_GEN_SCRIPT_ | N | empty | 4 | When set to the name of the script that generates the Janus Gateway configuration upon the container startup, the image execution command displayed at the end of the successful build will add an option to trigger that process. Note the referred script may be placed in the mounted configuration folder (when using _RUN_WITH_HOST_CONFIGURATION_DIR_) or embeddd in the /janus_config folder (created during the Target image creation)

2. Review the Janus gateway configuration files stored in *<clone directory>/janus_config* directory these files will be integrated into the build image and into the target image.
1. Launch the build process, this process performs two steps: creates the build image (unless the *SKIP_BUILD_IMAGE* is set to *"true"*), 
then creates the target image (unless *SKIP_TARGET_IMAGE* is set to *"true"*). Both images will appear in the local image Docker registry (issue *"docker images"* to verify). To perform either 
step set the above mentioned *"SKIP_"* parameters to the appropriate values.
	```bash
	cd <clone directory>
	./container.sh
	```

## Gitlab CI build procedure
This procedure is integrated into GitLab and provides a full automation pipeline of the build and target images creation. The procedure relies 
on the [Kaniko](https://github.com/GoogleContainerTools/kaniko) tool for creating the container images. The main advantage of Kaniko is that 
it is self contained and does not require proviledged access to any host resources. The automation pipeline defined in the _.gitlab-ci.yml_ is 
divided into three steps that are triggered by committing two different types of tags:

1. Create the build image, triggered by committing a tag that has the form _build-x.y.z_. The resulting build image will be tagged with _build-x.y.z_ and _latest_ tags.
2. Create the target image content, triggered by committing a tag that has the form _x.y.z_ (i.e. release) or a branch that starts with _dev-_ (i.e. development branch).
3. Create the target image, triggered by the same conditions as the previous step. The resulting target image will be tagged with _x.y.z_ and _latest_ tags.

As stated earlier, the automation relies on GitLab [Kubernetes executor](https://docs.gitlab.com/runner/executors/kubernetes.html). Although, we did not try, the GitLab Docker 
executor perhaps may also work.\
The following parameters have to be defined in your environment. Please note that the current CI configuration pushes the images to two registries (ACR and NCR) if you would
like to use a single registry instead simply remove the lines referring either to ACR or NCR from the _.gitlab-ci.yml_ file and ignore the related parameters below.

Parameter | Description 
 :---: | :--- 
 ACR_AUTH | Base64 encoded value of ACR image registry credentials "<username>:<password>" values, see section "Define an image from a private Container Registry" on [this page](https://docs.gitlab.com/ee/ci/docker/using_docker_images.html)
 NCR_AUTH | Base64 encoded value of NCR image registry credentials "<username>:<password>" values, see section "Define an image from a private Container Registry" on [this page](https://docs.gitlab.com/ee/ci/docker/using_docker_images.html)
 ACR_REGISTRY | ACR registry location (e.g. "gcr.io") 
 NCR_REGISTRY | NCR registry location (e.g. "gcr.io") 
 ACR_PROJECT | The project in the ACR registry where the images will be stored (e.g. "some_project_name"), may be left empty
 NCR_PROJECT | The project in the NCR registry where the images will be stored (e.g. "some_project_name"), may be left empty
 DOCKER_AUTH_CONFIG | See section "Define an image from a private Container Registry" on [this page](https://docs.gitlab.com/ee/ci/docker/using_docker_images.html)
 JANUS_BUILD_IMAGE | Name of the Janus build image (e.g. "janus_build")
 JANUS_TARGET_IMAGE | Name of the Janus Gateway target image (e.g. "janus")

The following two parameters are defined in the _.gitlab-ci.yml_ file in the _create_target_image_content_ stage to ensure that they are version controlled.

Parameter | Description 
 :---: | :--- 
 JANUS_REPO | The repository to fetch the Janus Gateway source code (e.g. https://github.com/meetecho/janus-gateway.git)
 JANUS_VERSION | The Janus Gateway source code version to checkout (e.g. "v0.10.0")

**Please note that further tuning of the _.gitlab-ci.yml_ is required to fit into your setup. For example, you must set the right location and version of the build image and you may need to tag 
the jobs with different tags so they get picked up by the appropriate runner, set the right version of the janus buld image etc.**

## Running the target image on the build/execution host
1. Launch the target image by invoking either of the commands on the build/execution host that are displayed at the end of a **successful** manual
 target image build (if *SKIP_TARGET_IMAGE* was set to *"false"* or not exported). For example:
	```bash 
	docker run --rm -d -p 8089:8089 -p 7889:7889 \
		-v /etc/letsencrypt/live/<host>.<domain>:/etc/certs \
		-v /etc/letsencrypt/archive:/archive \
		-v /var/janus/recordings:/janus/bin/janus-recordings \
		-v <clone folder>/janus_config:/janus/etc/janus_host -e "RUN_WITH_HOST_CONFIGURATION_DIR=true" \
		-v /var/www/html/container:/html -e "COPY_JANUS_SAMPLES=true" \
    -e "CONFIG_GEN_SCRIPT=<configuration_generation_script>"
		some.container.registry.com/janus:some_tag
	```
	Notes: 
	* If the _RUN_WITH_HOST_CONFIGURATION_DIR_ parameter is set to "false" or not specified (see above) it is not necessary to mount the _\<clone folder\>\/janus_config_ folder.
	* If the _COPY_JANUS_SAMPLES_ parameter is set to "false" or not specified (see above)it is not necessary to mount the _\/var\/www\/html\/container_ folder.
2. Try the image by browsing to *https://\<host\>.\<domain\>/container* Please note that:
	* By default the video room plugin configuration (configuration file: _\<clone directory\>/janus_config/janus.plugin.videoroom.jcfg_) is set to require string video room names which is not the Janus gateway default configuraiton.
	* The default configuration allows *only* HTTPS transport through secure ports 8089 - janus-api and 7889 - janus-admin.

## Quick Docker tips
1. List all the images available locally
	```bash
	docker images
	```
1. List all the containers that are stopped but have not been removed
	```bash
	docker ps -a
	```
1. Remove a stopped container
	```bash
	docker rm <first few chars of the container id as displayed by "ps" command>
	```
1. Remove an image
	```bash
	docker rmi <first few chars of the image id as displayed by "images" command>
	```
1. Stop a container
	```bash
	docker stop <first few chars of the container id as displayed by "ps" command>
	```
1. Start a container in interactive mode, that will be removed when stopped, overriding the defined entrypoint, exposes a port, mounts a volume and sets an environment variable
	```bash
	docker run --rm -it -p <host port>:<container port> -v <host volume/directory>:<container directory> -e "VARIABLE_NAME=VARIABLE_VALUE" --entrypoint <new entrypoint command (e.g. "/bin/bash"> <image name>:<image tag>
	```
1. Execute an interactive command in a running container
	```bash
	docker exec -it <first few chars of the container id as displayed by "ps" command> <command to execute (e.g. "/bin/bash")>
	```

## Deploying the target image on Azure Kubernetes Service (AKS) using Helm charts
This is an example of procedure for deploying and running the Janus target image on AKS. Plese note that we have only tried this deployment with the video
room sample application. The other applications will require some adjustments in the procedure.
 
### Prerequisites 
The following prerequisites must be satisfied
1. MS Azure subscription and a user able to create Azure resources groups because each cluster requires one additional resource group that 
gets created during cluster creation. As explained [here](https://docs.microsoft.com/en-us/azure/aks/faq#why-are-two-resource-groups-created-with-aks) the purpose 
of this resource group is to contain the resources that are solely dedicated to a cluster. For example, the cluster networking resources are part of this dedicated resource group.
1. A configurable domain that will allow to assign \<host\>.\<domain\> to the static IP address assigned to the AKS cluster
1. TLS certificate and the associated key file for \<host\>.\<domain\>

### Add AKS/Kubernetes tools to the build/execution host
The build/execution host will be used to interact with the Azure Kubernetes cluster. 
1. Follow [these instructions](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-apt) to setup the Azure CLI. 
1. After installing the Azure CLI issue ```sudo bash az aks install-cli``` to install _kubectl_ the Kubernetes CLI and then 
```bash az login --use-device-code``` to login to Azure. 
1. For greater convenience we also suggest to install the _kubectl_ shell autocompletion as presented
on [this](https://kubernetes.io/docs/tasks/tools/install-kubectl/#optional-kubectl-configurations) page. 
1. Finally, you need to install Helm following [these](https://helm.sh/docs/intro/install/) instructions.

### Create the Kubernetes cluster
For creating a Kubernetes cluster the user has to be able to create Azure resources groups because each cluster requires one additional resource group that 
gets created during cluster creation. As explained [here](https://docs.microsoft.com/en-us/azure/aks/faq#why-are-two-resource-groups-created-with-aks) the purpose 
of this resource group is to contain the resources that are solely dedicated to a cluster. For example, the cluster networking resources are part of this dedicated resource group. 
To create the Kubernetes cluster follow the following steps:
1. Create a new resource group, note this step may be skipped if a suitable resource group already exists
	```bash 
	az group create --name <resource group> --location eastus
	```
1. Create the Kubernetes cluster. To run the Janus compact deployment for testing and demonstration purposes a single node cluster is sufficient. As explained above, 
the following command will also create a resource group with the default name _MC\_\<resource group\>\_\<cluster name\>\_eastus_ 
	```bash
	az aks create --resource-group <resource group> --name <cluster name> --node-count <desired nuber of nodes> --generate-ssh-keys
	```
1. Login into the cluster
	```bash
	az aks get-credentials --resource-group <resource group> --name <cluster name>
	```
1. It should be possible now to see the cluster nodes by issuing
	```bash 
	kubectl get nodes
	```

### Create a static IP address
Create the _cluster IP address_, it has to belong to the resource group dedicated to the cluster, namely _MC\_\<resource group\>\_\<cluster name\>\_eastus_

	```bash
	az network public-ip create --resource-group MC_<resource group>_<cluster name>_eastus --name <IP address name> --sku Standard --allocation-method static
	```

After creating the static IP address it is a good time to configure your DNS to point the \<host\>.\<domain\> to that address

### Storage account and file share
A file share is required in a storage account for saving the conference room recordings.
1. Create a azure storage account
	```bash
	az storage account create --name <storage account> --resource-group <ressource group> --location eastus --sku Standard_RaGRS --kind StorageV2
	```
1. Get the connection string from the storage account. The account name/user name follows _AccountName=_ while the key follows _AccountKey=_ in the command output 
	```bash
	az storage account show-connection-string --name <storage account> -g <resource group> -o tsv
	DefaultEndpointsProtocol=https;EndpointSuffix=core.windows.net;AccountName=<storage account>;AccountKey=<account key>
	```
1. Create the file share
	```bash
	az storage share create -n <file share> --account-name <storage account> --account-key <key obtained in the previous step>
	```
1. Get the storage account keys
	```bash
	az storage account keys list --resource-group <resource group> --account-name <storage account>
	```
1. Mount the file share on a Linux host. Please note that the host has to have CIFS installed. This directory will contain the raw recordings.
	```bash
	mkdir <mount point>
	sudo mount -t cifs //<storage account>.file.core.windows.net/<file share> <mount point> -o vers=3.0,username=<storage account>,password=<account key>,dir_mode=0777,file_mode=0777,serverino
	```

### Secrets
Once all the resources are created we need to create several Kubernetes secrets that will store the TLS certificates, the required information for accessing the 
file share and the registry credentials (if necessary) for fetching the target image.
1. Create the secret containing the TLS keys
	```bash 
	cd <home directory>
	kubectl create secret tls certs  \
	--cert=tls.crt\
	--key=tls.key
	```
1. Create the secret allowing to mount the file share in the pod
	```bash
	kubectl create secret generic file-share --from-literal=azurestorageaccountname=<storage account> --from-literal=azurestorageaccountkey=<storage account key>
	```
1. Create the secret(s) allowing to fetch the images from the registries. 
	```bash
	docker login <container registry>
	User: <container registry user name>
	Password: <container registry password>
	kubectl create secret generic regcred \
	--from-file=.dockerconfigjson=<home directory>/.docker/config.json> \
	--type=kubernetes.io/dockerconfigjson
	```

### Configure the deployment
Edit the _\<clone directory\>\/janus_helm\/values.yaml_ file. The table below sumarizes the required values.

| Parameter | Description |
|:------------- | :----------------|
_env.clusterIp_ | The IP address that was allocated to the AKS cluster
_env.clusterName_ | \<host\>.\<domain\> of the AKS cluster
_env.shareName_ | The name of the share for storing the recordings
_env.secrets.tlsCertificates_ | The name of the secret that contains the TLS key and certificate (e.g. "certs")
_env.secrets.fileShare_ | The name of the secret that contains the file share parameters (e.g. "file-share")
_env.secrets.registriesCredentials_ | The name of the secret that contains the registry credentials (e.g. "regcred")
_janus.containerRegistry_ | The registry to fetch the target image
_janus.imageName_ | The name of the image to fetch
_janus.imageTag_ | The tag of the image to fetch 
_janus.sessionPort_ | The session management port number
_janus.adminPort_ | The admin port numer, optional if not set the admin port will be desactivated
_janus.tokenSecret_ | Token for authenticating the session management messages, optional if not set no token will be required
_janus.adminSecret_ | Password for accessing the admin port, optional if not present the admin port will be desactivated
_janus.recordFolder_ | Folder where the file share will be mounted in the target image and the recordings will be stored
_janus.eventUser_ | User name for accessing the event collector
_janus.eventPassword_ | Password for accessing the event collector
_janus.eventBackendUrl_ | The URL of the event collector (e.g. https://some.host/some/path)
_janus.nat.stunServer_ | Stun server name (e.g. "stun.l.google.com")
_janus.nat.stunPort_ | Stun port 19302
_janus.nat.niceDebug_ | Enable (true) or disable (false) nice debugging.
_janus.nat.fullTrickle_ | Enable (true) or disable (false) the full tricke optimization
_nginx.httpsPort_ | The HTTPS port to expose (e.g. 443)

### Launch the deployment
* After configuring and before starting the deployment it is a good practice to verify if the configuration by issuing:
	```bash
	cd <clone directory>
	helm install --debug --dry-run janus ./janus_helm
	```
* If the command does not report any errors and a valid Kubernetes manifest is displayed the deployment may be launched by issuing:
	```bash
	cd <clone directory>
	helm install janus ./janus_helm
	```
* To verify the status of the deployment issue:
	```bash
	helm status janus
	```
* To stop the deployment issue:
	```bash
	helm uninstall janus
	```
[kubectl](https://kubernetes.io/docs/reference/kubectl/cheatsheet/) utility may be used to query and manipulate the deployment. 
Once the deployment is running the Janus HTML samples may be accessed at _https://\<host\>.\<domain\>/_

## Experimentation and observations
The figure below shows the network configuraiton when running Janus Gateway in a Docker container configured with the default bridge network. The Docker host is a data center 
virtual or physical machine accessible through a 1-to-1 NAT firewall through subnet Y. The Janus client is located in a private "home" subnet X that offers a typical "home" router/firewall. 
Optionally, the home network may belong to an ISP that provides private subnet W and a NAT enabled firewall. Such ISP configuraiton is frequent with mobile opertors.
The default Docker bridge configuration provides a private subnet for the containers. The conainers may access the public network thanks to the netfilter MASQUERADE target NAT 
functionlity applied to any packets leaving the private subnet Z. The container is configured to expose the Janus gateway control (e.g. 8089 for Janus API and 7889 for Janus admin) 
and initially media ports (e.g. 10000-12000). As you will see below one of our conclusions consists in not exposing the media ports. Janus gateway server is configured to run in tricke and full ICE mode.
The solution relies on a STUN server that allows to discover the public addresses of the client and the server. In normal circumstances the depicted TURN server should not be required 
as the ICE protocol with the help of the STUN server allows to establish the end-to-end communication. 

![Network configuration](doc/network_setup.jpg)

### Issue #1 - Issue caused by Janus Gateway server running in a Docker container using the default *bridge* configuration
The figure below shows a simplified successfull sequence where the ICE suceeds to establish bidirectional media streams between the client and the gateway.
1. The offer is issued by the client.
1. Based on the offer and/or trickled candidates the gateway sends connectivity checks that cannot reach the client.
1. Eventually the gateway sends an aswer message that allows the client to start sending STUN probles.
1. Thanks to the gateway earlier connectivity checks the client STUN probles reach the server (the firewall port is open).
1. Thanks to the client connectivity checks (the firewall port is open) the gateway connectivity checks are reaching the client.

![Sucessful sequence](doc/sequence_successful.jpg)

The next figure shows the unsucessful sequence. 
1. This time the offer is sent by the gateway.
1. Based on the offer and/or trickled candidates the client sends connectivity checks that cannot reach the gateway. These probes are rejected by the MASQUERADE netfilter target because the 1-to-1 NAT
firewall is configured to forward any media traffic to the gatway. An ICMP error message is generated for each rejected probe.
1. The client generates an answer.
1. Based on the answer and/or trickled candidates the gateway generates connectivity checks that for some reason never make it to the client. 
1. The client connectivity checks never make it to the gateway neither.

![Failing sequence](doc/sequence_unsucessful.jpg)

Therefore our initial analysis has lead us to the same concusion as presented in [this](https://www.slideshare.net/AlessandroAmirante/janus-docker-friends-or-foe) slide pack 
by Alessandro Amirante from Meetecho. Now, going a bit more into details the next figure below shows an excerpt of the packet capture at the virtual machine network interface. 
1. connectivity check sent by the client before the gateway had a chance to open the port. As presented in step 2 on the previous figure above.
1. An ICMP "destination unreachable" error is generated.
1. The gateway sends a STUN request to a STUN server to retrieve its server reflexive address and port.
1. The STUN server replies indicating the reflexive port is 20422
1. The gateway issues connectivity checks from port 20422 to the client local addresses (local subnet 192.x.y.z and some VPN 10.x.y.z) which are unreachable because the client is on a private subnet.
1. The connectivity check destined to the client server reflexive (i.e. "reachable") address and port gets its source port **reassigned** to **1599** (instead of **20422**). 
This happens because the earlier connectivity check from the client destined to the gateway address and port 20422 has altered the state of the MASQUERADE netfilter target. Please note we were not
able to identify the reason for this behavior (e.g. security vunerability protection, standard specification, DOS attack protection etc.).

![Annotated packet capture](/doc/packet_capture_annotated.jpg)

Therefore the client connectivity checks are lost because of the race condition between the gateway opening firewall ports and the client sending STUN probles and because the MASQUERADE netfilter 
target does not allow a host from the private subnet to send packets to a remote host using the same quintuple (source address, destination address, source port, destination port, protocol) 
as the one recently rejected from the remote host. On the other hand the server STUN probles are most probably rejected by the client side firewall because its NAT configuraiton is port restricted. 

### Solutions
In an attempt to eliminate the root cause and to delay the STUN client probes we have configred the gateway to trickle the candidates, which was unsuficient. Therefore we have also
 added an addional 1s delay in the client (janus.js file) when processing the received trickle candidates from the gateway. While this is not an acceptable solution the problem appeares to be solved.
1. The gateway sends the offer.
1. The gateway starts trickling the candidates. But the processing of the received tricked candidates is delayed by 1s at the client.
1. The client issues an answer.
1. The gatway sends a connectivity check that does not reach the client because the firewall port is still closed because of the delay.
1. After the delay has expired the client sends a connectivity check that opens the firewall port and reaches the gatway.
1. Finally the server resends a connectivity check that this time reaches the client.

![Tricked and delayed approach](doc/sequence_trickle_delay.jpg)

The second solution consists in reconfiguring the 1-to-1 NAT firewall to disallow exposing any ports besides 80 (http), 443 (https), 8089 (janus-api) and 7889 (janus-admin). All the other ports
require the gateway to send an initial "opening" request.
1. The gateway sends the offer.
1. Based on the offer and/or tricked candidates the client sends connectivity checks to the gatway. All these probes get filtered out by the 1-to-1 NAT and hence don't cause the 
above mentioned issue any more.
1. The client sends an answer to the gatway.
1. Based on the answer and/or trickled candidates the gatweay sends connectivity checks to the client.
1. The client resends the connectivity checks that this time reach the server.

![1-to-1 NAT firewall configuration](doc/sequence_1_to1_nat.jpg)

### Issue #2 - Issue caused by the presence of the ISP firewall
In some rare cases, the ISP firewall behaves the same way as the Netfilter MASQUERADE target and in the situation a connectivity check is received from the Janus Gateway server before the 
Janus client had a chance to issue a connectivity check towards the server the ISP firewall will replace the discovered port nuber with a new one. This issue occurs when the Janus client 
sends an offer message to the Janus Gateway server along with the candidates before receiving the Janus Gatway server candidates. As a matter of fact this issue is a mirror of the 
previous issue. 

### Solutions
To solve this issue we have to either delay/prevent the Janus Gatway to issue connectivity checks or mitigate the (STUN) server reflexive candidates failure. There are no easy ways to delay
the connectivty checks but they may be disabled by changing the Janus Gateway server configuration from bridge to host network and activating the ICE Lite mode. According to RFC 8445, in 
ICE Lite mode no connectivity checks should be made. Unfortunately after reconfiguring the Janus Gateway to ICE Lite mode the connectivity checks are still emitted, this may be a bug in
the implementation of the *libnice* library or its integration within the Janus Gateway. Eventually, it was possible to supress the conectivity checks by temporarely modifying the Janus 
Gatway code which has resolved the issue. We have also tried to enable the TURN server which, as expected, solves the issue by providing additional relayed candidates. The main drawback
of this solution is the need for an addional server that relays all the traffic and which creates a bottleneck that needs to be managed. Hopefully only a minority of Janus clients will 
be using ISPs having such firewall configuration. 

## Conclusion
It is possible to use the default Docker bridged network driver but some conditions have to be met by the infrastructure specifically the firwall leading to the Janus Gateway server. 
The firewall has to be able to block the client requests without triggering a port change as it happens with the MASQUERADE netfilter target. Additnally to avoid any potential firewall
issues with some ISPs that provide private IP addresses to their customers a TURN server must be added to the deployment.



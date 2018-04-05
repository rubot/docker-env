# docker-env

## About

`docker-env` will help maintaining multiple `docker-machine` environments.

Basically this just exports `MACHINE_STORAGE_PATH` which is used by [docker-machine](https://docs.docker.com/machine/install-machine/).
If you ever had the same known problem, dealing with docker-machine/docker and certificates like described in [1799](https://github.com/docker/machine/issues/1799) or [2229](https://github.com/docker/machine/issues/2229), this is how I handle it.

In short for understanding or just doing it manual.
The quick hack, which provides VERSION pinning for `docker-machine` docker installation is not implemented in `docker-env`.
However, it reminds me: docker/machine/issues#1702

    name=<machine-name>
    ip=<machine-ip>
    ssh_user=root

    1. initially create/export
    export MACHINE_STORAGE_PATH=${MACHINE_STORAGE_PATH:-~/.docker/machine}
    docker-machine -D create --driver generic --generic-ip-address $ip --generic-ssh-user $ssh_user --engine-storage-driver overlay2 --engine-install-url 'https://get.docker.com|head -n-1|cat - <(echo -e "VERSION=18.03.0\nCHANNEL=stable\ndo_install")' $name
    eval "$(docker-machine env $name)"
    tar czf $name.tgz -C $MACHINE_STORAGE_PATH/certs .

    2. recreate/import driver none (no ssh)
    export MACHINE_STORAGE_PATH=${MACHINE_STORAGE_PATH:-~/.docker/machine}
    docker-machine -D create --driver none  --url tcp://$ip:2376 $name
    tar xvzf $name.tgz -C $MACHINE_STORAGE_PATH/certs
    eval "$(docker-machine env $name)"
    tar xvzf $name.tgz --exclude ca-key.pem -C $MACHINE_STORAGE_PATH/machines/$DOCKER_MACHINE_NAME

    3. recreate/import driver generic (ssh)
    export MACHINE_STORAGE_PATH=${MACHINE_STORAGE_PATH:-~/.docker/machine}
    mkdir -p $MACHINE_STORAGE_PATH/certs
    tar xvzf $name.tgz -C $MACHINE_STORAGE_PATH/certs
    docker-machine -D create --driver generic --generic-ip-address $ip --generic-ssh-user $ssh_user --engine-storage-driver overlay2 --engine-install-url 'https://get.docker.com|head -n-1|cat - <(echo -e "VERSION=18.03.0\nCHANNEL=stable\ndo_install")' $name
    eval "$(docker-machine env $name)"

## Install

    curl -so ~/.docker-env.bash https://raw.githubusercontent.com/rubot/docker-env/master/docker-env.bash
    echo source ~/.docker-env.bash >> ~/.bashrc
    source ~/.docker-env.bash

## Usage example

    docker-env --activate env -y     # Create a directory ~/.docker/docker_env/env
                                     # And point `MACHINE_STORAGE_PATH` to it

    docker-machine ls                # Should be empty

    docker-machine create -d virtualbox default  # Create a local CA (Certificate Authority) and client 
                                                 # certificates into:
                                                 #  ~/.docker/docker_env/env/certs
                                                 # Create a docker virtualbox machine called `default` into
                                                 #  ~/.docker/docker_env/env/machines/default
                                                 # scp the certificates to the virtualbox machine

    docker-machine ls                # Should show up the machine named default

    docker-env default               # Does the well known `eval "$(docker-machine env default)"` for us 

    docker ps                        # Should connect and return empty container set

    ip=`docker-machine ip default`   # Get the ip for later

    docker-env --export              # exports the public CA key and the user private/public 
                                     # keys into env.tgz
                                     # getting it from ~/.docker/docker_env/env/certs

    docker-env --activate noca       # Create a second environment
    
    docker-machine ls                # Should be empty
    
    docker-env --import env.tgz      # Extract the certificates to ~/.docker/docker_env/noca/certs
    
    docker-env --create-machine $ip testmachine  # Creates a `docker-machine --driver none` machine 
                                                 #  pointing to $ip
                                                 # Copy the certificates to
                                                 #  ~/.docker/docker_env/noca/machines/testmachine

    docker-machine ls                # Should show up the machine named testmachine

    docker-env testmachine           # Does the well known `eval "$(docker-machine env testmachine)"` for us 

    docker ps                        # Should connect and return empty container set

    docker-machine create -d virtualbox testmachine2  # Will fail, as we don´t have a valid CA:
                                                      #  Error creating machine: 
                                                      # Error running provisioning: error 
                                                      # generating server cert: 
                                                      #  open ~/.docker/docker_env/noca/certs/ca-key.pem: 
                                                      # no such file or directory

## Create a machine for coworking

Now you could `docker-machine create --driver generic` a remote CA-machine for coworking. 
Then you export and send the certificates to coworkers.
Coworkers then import the certificates and create a `--driver none` machine.
They either use `docker-env --import` and `docker-env --create-machine`, or you could 
just send the commands printed by `docker-env --export`

Create the generic machine:

    docker-env --activate external -y
    docker-machine create --driver generic --generic-ip-address $ip --generic-ssh-user $ssh-user $fqdn
    docker-env --export

## Import machine

> `docker-env --export` prints following infos each time you export the certs.

Ensure remote port `2376` is open and secure enough for you.
Forward `external.tgz` and point to the docs: [import-machine](https://github.com/rubot/docker-env#import-machine),
or provide one of the following four command options.

Manually export MACHINE_STORAGE_PATH [--import --create]

    machine_ip=change_to_ip
    machine_name=change_to_name
    env_name=myenv

    export MACHINE_STORAGE_PATH=~/.docker/docker_env/$env_name  # --activate
    MACHINE_CERTS=$MACHINE_STORAGE_PATH/certs
    MACHINE_PATH=$MACHINE_STORAGE_PATH/machines/$machine_name

    mkdir -p $MACHINE_CERTS
    tar xvzf external.tgz -C $MACHINE_CERTS
    docker-machine create --driver none --url tcp://$machine_ip:2376 $machine_name
    cp -a $MACHINE_CERTS/*.pem $MACHINE_PATH/

    eval "$(docker-machine env $machine_name)"

If docker-env is available [--import --create]

    machine_ip=change_to_ip
    machine_name=change_to_name

    docker-env --activate myenv -y
    docker-env --import external.tgz
    docker-env --create-machine $machine_ip $machine_name

    docker-env $machine_name

Use the default machine location [--import-create]

    machine_ip=change_to_ip
    machine_name=change_to_name

    MACHINE_STORAGE_PATH=~/.docker/machine  # Default
    MACHINE_CERTS=$MACHINE_STORAGE_PATH/certs
    MACHINE_PATH=$MACHINE_STORAGE_PATH/machines/$machine_name
    REGC=${MACHINE_CERTS//\//\\/}
    REGM=${MACHINE_PATH//\//\\/}

    docker-machine create --driver none --url tcp://$machine_ip:2376 $machine_name
    tar xvzf external.tgz -C $MACHINE_PATH
    sed -i.bak "s/${REGC}/${REGM}/" $MACHINE_PATH/config.json

    eval "$(docker-machine env $machine_name)"

If docker-env is available [--import-create]

    machine_ip=change_to_ip
    machine_name=change_to_name

    docker-env --activate default
    docker-env --import-create external.tgz $machine_ip $machine_name

    docker-env $machine_name

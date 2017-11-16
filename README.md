# docker-env

Basically this just exports `MACHINE_STORAGE_PATH` which is used by [docker-machine](https://docs.docker.com/machine/install-machine/).
If you ever had the same known problem, dealing with docker-machine/docker and certificates, this is how I handle it.

    Maintains docker-machine environments

    Usage: docker-env [option|docker-machine_name]

    Options:
        --activate [name] [--yes|-y]           export MACHINE_STORAGE_PATH=~/.docker/docker_env/name.
                                               Create when it does not exist
        --create-machine [ip] [name]           docker-machine create --driver none
        --deactivate                           unset MACHINE_STORAGE_PATH
        --docker-machine-ls                    docker-machine ls
        --export [--show] [--quiet|-q]         export cert-files to tgz. [--show] just print import infos.
                          [--ca]               do not exclude ca-key.pem
                          [--noca]             although ca-key.pem exists
        --help                                 this text
        --import [name.tgz]                    import tgz to current env
                                               This puts certs to cert folder
        --import-create [name.tgz] [ip] [name] import tgz to current env and create machine
                                               This puts certs in machine folder
        --ls|-l                                list all environments
        --off                                  --unset + --deactivate
        --open|-o                              open ~/.docker in Finder
        --remote                               set DOCKER_REMOTE=1
        --show-env                             grep current env vars
        --unset|-u                             unset DOCKER_HOST env vars

    docker-machine_name [--quiet|-q]  export DOCKER_HOST env vars for docker-machine host
                                      like: eval "$(docker-machine env name)" does

## Usage example

    wget https://raw.githubusercontent.com/rubot/docker-env/master/docker-env.bash
    source docker-env.bash


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
                                                      #Error running provisioning: error 
                                                      #generating server cert: 
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
Send `external.tgz` and point to the docs: [import-machine](https://github.com/rubot/docker-env#import-machine),
or provide one of the following four command options.

Manually export MACHINE_STORAGE_PATH [--import --create]

    machine_ip=change_to_ip
    machine_name=change_to_name
    env_name=myenv

    MACHINE_STORAGE_PATH=~/.docker/docker_env/$env_name
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

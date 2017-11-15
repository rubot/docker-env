# docker-env

Basically this just exports `MACHINE_STORAGE_PATH` which is used by docker-machine.
If you ever had the same known problem, dealing with docker-machine/docker and certificates, this is how I handle it.

    Maintains docker-machine environments

    Usage: docker-env [option|docker-machine_name]

    Options:
        --activate [name]             export MACHINE_STORAGE_PATH=/Users/rubot/.docker/docker_env/name
        --create-machine [ip] [name]  docker-machine create --driver none
        --deactivate                  unset MACHINE_STORAGE_PATH
        --docker-machine-ls           docker-machine ls
        --export                      export cert-files to tgz
        --export-ca                   export ca-private-key and cert-files to tgz
        --import [name.tgz]           import tgz to current env
        --help                        this text
        --ls|-l                       list all environments
        --off                         --unset + --deactivate
        --open|-o                     open /Users/rubot/.docker in Finder
        --quiet|-q                    No output when relevant
        --remote                      set DOCKER_REMOTE=1
        --show-env                    grep current env vars
        --unset|-u                    unset DOCKER_HOST env vars

    docker-machine_name       export DOCKER_HOST env vars for docker-machine host
                              like: eval "$(docker-machine env name)" does

## Usage example

    echo source docker-env.bash >> ~/.bashrc
    exec $SHELL

    docker-env --activate env-ca -y  # Create a directory ~/.docker/docker_env/env-ca
                                     # And point `MACHINE_STORAGE_PATH` to it

    docker-machine ls                # Should be empty

    docker-machine create -d virtualbox default  # Create a local CA (Certificate Authority) and client certificates into:
                                                 #  ~/.docker/docker_env/env-ca/certs
                                                 # Create a docker virtualbox machine called `default` into
                                                 #  ~/.docker/docker_env/env-ca/machines/default
                                                 # scp the certificates to the virtualbox machine

    docker-machine ls                # Should show up the machine named default

    docker-env default               # Does the well known `eval "$(docker-machine env default)"` for us 

    docker ps                        # Should connect and return empty container set

    ip=`docker-machine ip default`   # Get the ip for later

    docker-env --export              # exports the public CA key and the user private/public keys into env-ca.tgz
                                     # getting it from ~/.docker/docker_env/env-ca/certs

    docker-env --activate env-none   # Create a second environment
    
    docker-machine ls                # Should be empty
    
    docker-env --import env-ca.tgz   # Extract the certificates to ~/.docker/docker_env/env-none/certs
    
    docker-env --create-machine $ip testmachine  # Creates a `docker-machine --driver none` machine pointing to $ip
                                                 # Copy the certificates to
                                                 #  ~/.docker/docker_env/env-none/machines/testmachine

    docker-machine ls                # Should show up the machine named testmachine

    docker-env testmachine           # Does the well known `eval "$(docker-machine env testmachine)"` for us 

    docker ps                        # Should connect and return empty container set

    docker-machine create -d virtualbox testmachine2  # Will fail, as we don´t have a valid CA:
                                                      #  Error creating machine: Error running provisioning: error generating server cert: open ~/.docker/docker_env/env-none/certs/ca-key.pem: no such file or directory



export DOCKER_ENV_DEFAULT_DOCKER_PATH=~/.docker
export DOCKER_ENV_MACHINE_PATH=$DOCKER_ENV_DEFAULT_DOCKER_PATH/docker_env
# Disable /etc/hosts for all ssh completions
# export COMP_KNOWN_HOSTS_WITH_HOSTFILE=


##
# This could be used as a security layer on prompt.
# Check `docker-env --remote`
##
# _docker_prompt () {
#     which docker &>/dev/null || (echo "docker" && return)
#     echo ${DOCKER_HOST:-docker.sock} - ${MACHINE_STORAGE_PATH:-}  # unix:///var/run/
# }
#
# __docker_skip() {
#     # prevent running unwanted remote docker commands
#     if ((BASH_SUBSHELL>0)); then
#         return 0
#     fi
#     previous_command=$this_command
#     this_command=$BASH_COMMAND
#     ! [[ $this_command == 'docker '* ]] && return 0
#     [[ $DOCKER_REMOTE == '1' ]] && return 0
#     if ! [[ `_docker_prompt|grep docker.sock` ]]; then
#         echo "WARNING: remote docker host. Set DOCKER_REMOTE=1 to suppress this msg. Run this command? [y/N]"
#         read sure
#         if ! [[ $sure == y || $sure == Y ]]; then
#             echo "Skipping remote docker command"
#             return 1
#         fi
#     fi
# }
# trap '__docker_skip' DEBUG
# shopt -s extdebug
# export PS1='[$(_docker_prompt)]\n'$PS1
##


__docker-env__help(){
    echo
    echo "Maintains docker-machine environments"
    echo
    echo "Usage: docker-env [option|docker-machine_name]"
    echo
    echo "Options:"
    echo "    --activate [name] [--yes|-y]           export MACHINE_STORAGE_PATH=$DOCKER_ENV_MACHINE_PATH/name. Create when it does not exist"
    echo "    --create-machine [ip] [name]           docker-machine create --driver none"
    echo "    --deactivate                           unset MACHINE_STORAGE_PATH"
    echo "    --docker-machine-ls                    docker-machine ls"
    echo "    --export [--ca] [--noca] [--quiet|-q]  export cert-files [and ca-private-key] to tgz"
    echo "    --help                                 this text"
    echo "    --import [name.tgz]                    import tgz to current env"
    echo "    --ls|-l                                list all environments"
    echo "    --off                                  --unset + --deactivate"
    echo "    --open|-o                              open $DOCKER_ENV_DEFAULT_DOCKER_PATH in Finder"
    echo "    --remote                               set DOCKER_REMOTE=1"
    echo "    --show-env                             grep current env vars"
    echo "    --unset|-u                             unset DOCKER_HOST env vars"
    echo
    echo "docker-machine_name [--quiet|-q]  export DOCKER_HOST env vars for docker-machine host"
    echo "                                  like: eval \"\$(docker-machine env name)\" does"
    echo
    [[ $@ ]] && echo -e "Error: $@"
}

__docker-env__help_export(){
    echo
    echo "Ensure remote port \`2376\` is open and secure enough for you."
    echo "Send \`$1.tgz\` and provide one of the following three command options."
    echo
    echo "1. Just use the default machine location"
    echo
    echo "    machine_ip=change_to_ip"
    echo "    machine_name=change_to_name"
    echo "    MACHINE_STORAGE_PATH=~/.docker/machine  # Default"
    echo "    MACHINE_CERTS=\$MACHINE_STORAGE_PATH/certs"
    echo "    MACHINE_PATH=\$MACHINE_STORAGE_PATH/machines/\$machine_name"
    echo "    REGC=\${MACHINE_CERTS//\\//\\\\/}"
    echo "    REGM=\${MACHINE_PATH//\\//\\\\/}"
    echo
    echo "    docker-machine create --driver none --url tcp://\$machine_ip:2376 \$machine_name"
    echo "    tar xvzf $1.tgz -C \$MACHINE_PATH"
    echo "    sed -i.bak \"s/\${REGC}/\${REGM}/\" \$MACHINE_PATH/config.json"
    echo "    eval \"\$(docker-machine env \$machine_name)\""
    echo
    echo "2. To every time manually export MACHINE_STORAGE_PATH"
    echo
    echo "    machine_ip=change_to_ip"
    echo "    machine_name=change_to_name"
    echo "    env_name=myenv"
    echo "    MACHINE_STORAGE_PATH=~/.docker/docker_env/\$env_name"
    echo "    MACHINE_CERTS=\$MACHINE_STORAGE_PATH/certs"
    echo "    MACHINE_PATH=\$MACHINE_STORAGE_PATH/machines/\$machine_name"
    echo
    echo "    mkdir -p \$MACHINE_CERTS"
    echo "    tar xvzf $1.tgz -C \$MACHINE_CERTS"
    echo "    docker-machine create --driver none --url tcp://\$machine_ip:2376 \$machine_name"
    echo "    cp -a \$MACHINE_CERTS/*.pem \$MACHINE_PATH/"
    echo "    eval \"\$(docker-machine env \$machine_name)\""
    echo
    echo "3. If docker-env is available"
    echo
    echo "    machine_ip=change_to_ip"
    echo "    machine_name=change_to_name"
    echo
    echo "    docker-env --activate myenv -y"
    echo "    docker-env --import $1.tgz"
    echo "    docker-env --create-machine \$machine_ip \$machine_name"
    echo "    docker-env \$machine_name"
    echo
    echo -n "Exported: $1.tgz"
    [[ ! -f $MACHINE_STORAGE_PATH/certs/ca-key.pem ]] && echo " (noca)"
    echo
}

__docker-env__create_machine(){
    local machine_ip=$1
    local machine_name=$2

    __docker-env__validate_storage_path "Run \`docker-env --import\` first, otherwise we would create a new CA now.\nIf you intentionally want to do that, please use \`docker-machine create\`"||return 1

    docker-machine create --driver none --url tcp://$machine_ip:2376 $machine_name 1>/dev/null||return 1
    cp -a `find $MACHINE_STORAGE_PATH/certs -type f|grep -v ca-key` $MACHINE_STORAGE_PATH/machines/$machine_name/||return 1
    echo "---"
    echo "Done. You could use docker-machine now for specific commands."
    echo "---"
    echo "Run this command to configure your shell: docker-env $machine_name"
    return 0
}

__docker-env__show_vars(){
    echo
    env|egrep '^DOCKER|^MACHINE'|grep -v 'DOCKER_ENV'|sort
}

__docker-env__validate_storage_path(){

    if [[ ! $MACHINE_STORAGE_PATH ]]; then
        echo MACHINE_STORAGE_PATH is not set, but required.
        echo "Set env first: docker-env --activate"
        return 1
    fi

    if [[ $1 == create_or_fail_if_exist ]]; then
        [[ -d $MACHINE_STORAGE_PATH/certs ]] && echo Directory $MACHINE_STORAGE_PATH/certs exists. && return 1
        mkdir -p $MACHINE_STORAGE_PATH/certs
        shift
    fi

    if [[ ! -d $MACHINE_STORAGE_PATH/certs ]]; then
        echo Directory $MACHINE_STORAGE_PATH/certs does not exist.
        echo -e $@
        return 1
    fi
    return 0
}

docker-env(){
    local args=($@)
    local docker_machine_name
    local i=0
    local opt
    local optarg
    local optarg_2
    local quiet
    local yes

    [[ ! `which docker-machine` ]] && echo docker-machine is not installed && return 1
    [[ ! -d $DOCKER_ENV_MACHINE_PATH ]] && mkdir -p $DOCKER_ENV_MACHINE_PATH

    for opt in ${args[@]}; do
        [[ $opt =~ ^-q$|^--quiet$ ]] && quiet=1
    done

    for opt in ${args[@]}; do
        [[ $opt =~ ^-y$|^--yes$ ]] && yes=1
    done

    for opt in ${args[@]}; do

        i=$((i+1))
        optarg=${args[$i]}
        optarg_2=${args[$((i+1))]}

        case $opt in
            --activate)
                local create
                local name=$optarg

                if [[ ! $name || $name == -* ]]; then
                    echo "Name for environment is missing"
                    return 1
                fi

                if [[ ! -d $DOCKER_ENV_MACHINE_PATH/$name ]]; then

                    if [[ $yes == 1 ]]; then
                        mkdir -p $DOCKER_ENV_MACHINE_PATH/$name
                    else
                        echo "Not a directory: $DOCKER_ENV_MACHINE_PATH/$name"
                        echo -n "Should we create it? [y/N] "
                        read create
                        if [[ $create == y ]]; then
                            mkdir -p $DOCKER_ENV_MACHINE_PATH/$name
                        else
                            return 1
                        fi
                    fi
                fi

                eval "$(docker-machine env -u)"
                unset DOCKER_REMOTE
                export MACHINE_STORAGE_PATH=$DOCKER_ENV_MACHINE_PATH/$name
                return
                ;;
            --create-machine)
                if [[ ! $optarg || $optarg == -* ]]; then
                    echo "IP is missing"
                    return 1
                fi

                if [[ ! $optarg_2 || $optarg_2 == -* ]]; then
                    echo "Name (fqdn) is missing"
                    return 1
                fi

                __docker-env__create_machine $optarg $optarg_2
                return $?
                ;;
            --deactivate)
                unset MACHINE_STORAGE_PATH
                return
                ;;
            --docker-machine-ls)
                docker-machine ls
                return
                ;;
            --export)
                local ca
                local name
                local noca
                local excludes

                __docker-env__validate_storage_path||return 1

                for opt in ${args[@]}; do
                    [[ $opt == '--ca' ]] && ca=".ca"
                done

                for opt in ${args[@]}; do
                    [[ $opt == '--noca' ]] && noca=1
                done

                name="`basename $MACHINE_STORAGE_PATH`$ca"

                if [[ ! $noca || $ca ]]; then
                    if [[ ! -f $MACHINE_STORAGE_PATH/certs/ca-key.pem ]]; then
                        echo No authority found
                        return 1
                    fi
                fi

                if [[ -f $name.tgz ]]; then
                    echo File $name.tgz exists
                    return 1
                fi

                excludes=" --exclude .DS_Store"
                [[ ! $ca ]] && excludes+=" --exclude ca-key.pem"

                tar -cvzf $name.tgz -C $MACHINE_STORAGE_PATH/certs$excludes .
                [[ $quiet == 1 ]] || __docker-env__help_export $name
                return
                ;;
            --help)
                __docker-env__help
                return
                ;;
            --import)
                local tgz
                tgz=$optarg


                if [[ ! $tgz ]]; then
                    echo "Filename missing"
                    return 1
                fi

                if [[ ! -f $tgz ]]; then
                    echo "Not a file: $tgz"
                    return 1
                fi

                __docker-env__validate_storage_path create_or_fail_if_exist||return 1

                if tar -tzf $tgz >/dev/null; then
                    tar xvzf $tgz -C $MACHINE_STORAGE_PATH/certs
                fi
                return
                ;;
            --ls|-l)
                paste <(ls $DOCKER_ENV_MACHINE_PATH) <(\
                 for d in `ls -d -1 $DOCKER_ENV_MACHINE_PATH/**`; do
                    if [[ ! -d $d/certs ]]; then
                     echo " (none)"
                    elif [[ -f $d/certs/ca-key.pem ]]; then
                     echo " (ca)"
                    elif [[ -f $d/certs/ca.pem ]]; then
                     echo " (noca)"
                    else
                     echo " (empty)"
                    fi
                 done)|column -t
                 return
                 ;;
            --off)
                unset DOCKER_REMOTE
                unset MACHINE_STORAGE_PATH
                eval "$(docker-machine env -u)"
                return
                ;;
            --open|-o)
                open $DOCKER_ENV_DEFAULT_DOCKER_PATH
                return
                ;;
            --remote)
                export DOCKER_REMOTE=1
                return
                ;;
            --show-env)
                __docker-env__show_vars
                return
                ;;
            --unset|-u)
                unset DOCKER_REMOTE
                eval "$(docker-machine env -u)"
                return
                ;;
            *)
                docker_machine_name=$opt
                break
                ;;
        esac
    done

    if [[ ! $docker_machine_name ]]; then
        __docker-env__help docker_machine_name is missing.
        return 1
    fi

    if ! docker-machine env $docker_machine_name &>/dev/null; then
        __docker-env__help "Host seems not existing: \"$docker_machine_name\"\nCheck \`docker-machine ls\`"
        return 1
    fi

    if ! docker-machine env $docker_machine_name|grep -q Usage; then

        [[ $quiet == 1 ]] || echo Executing: eval \"\$\(docker-machine env $docker_machine_name\)\"

        eval "$(docker-machine env $docker_machine_name)"

    else
        __docker-env__help
        return 1
    fi

    [[ $quiet == 1 ]] || __docker-env__show_vars $@
}

_docker-env(){
    local cas=`ls $DOCKER_ENV_MACHINE_PATH`
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local dmachines="`docker-machine ls -t 0 -q` --docker-machine-ls --help"
    local options="--docker-machine-ls --ls --open --unset --activate --export --help --import --create-machine --deactivate --remote --show-env --off"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [ $COMP_CWORD == 1 ]; then

        # either autocomplete machine_names, or options
        if [[ $cur == -* ]]; then
            COMPREPLY=($(compgen -W "$options" -- ${cur}));
        else
            COMPREPLY=($(compgen -W "$dmachines" -- ${cur}));
        fi

    elif [ $COMP_CWORD -eq 2 ]; then
        case "$prev" in
          --activate)
            COMPREPLY=($(compgen -W "$cas" -- ${cur}));
            ;;
          --import)
            COMPREPLY=($(compgen -W "$(ls *.tgz 2>/dev/null)" -- ${cur}));
            ;;
        esac
    fi
    return 0
}

complete -F _docker-env docker-env

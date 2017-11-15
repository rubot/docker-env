

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

#     [[ $this_command == docker-* ]] && return 0
#     ! [[ $this_command == docker* ]] && return 0
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


__docker-env__show_vars(){

        env|egrep '^DOCKER|^MACHINE'|grep -v 'DOCKER_ENV'|sort
}

__docker-env__help(){
        echo
        echo "Maintains docker-machine environments"
        echo
        echo "Usage: docker-env [option|docker-machine_name]"
        echo
        echo "Options:"
        echo "    --activate [name] [--yes|-y]  export MACHINE_STORAGE_PATH=$DOCKER_ENV_MACHINE_PATH/name. Create when it does not exist"
        echo "    --create-machine [ip] [name]  docker-machine create --driver none"
        echo "    --deactivate                  unset MACHINE_STORAGE_PATH"
        echo "    --docker-machine-ls           docker-machine ls"
        echo "    --export                      export cert-files to tgz"
        echo "    --export-ca                   export ca-private-key and cert-files to tgz"
        echo "    --import [name.tgz]           import tgz to current env"
        echo "    --help                        this text"
        echo "    --ls|-l                       list all environments"
        echo "    --off                         --unset + --deactivate"
        echo "    --open|-o                     open $DOCKER_ENV_DEFAULT_DOCKER_PATH in Finder"
        echo "    --quiet|-q                    No output when relevant"
        echo "    --remote                      set DOCKER_REMOTE=1"
        echo "    --show-env                    grep current env vars"
        echo "    --unset|-u                    unset DOCKER_HOST env vars"
        echo
        echo "docker-machine_name       export DOCKER_HOST env vars for docker-machine host"
        echo "                          like: eval \"\$(docker-machine env name)\" does"
        echo
}

__docker-env__help_export(){

    echo
    echo "Ensure remote port \`2376\` is open and secure enough for you."
    echo "Send \`$1.tgz\` and provide those commands: "
    echo
    echo "    [[ \$machine_name ]] || read -p 'Enter machine_name: ' machine_name"
    echo "    [[ \$machine_ip ]] || read -p 'Enter machine_ip: ' machine_ip"
    echo
    echo "    MACHINE_STORAGE_PATH=~/.docker/docker_env/$1"
    echo "    mkdir -p \$MACHINE_STORAGE_PATH/certs"
    echo "    tar xvzf $1.tgz -C \$MACHINE_STORAGE_PATH/certs"
    echo "    docker-machine create --driver none --url tcp://\$machine_ip:2376 \$machine_name"
    echo "    cp -a \$MACHINE_STORAGE_PATH/certs/*.pem \$MACHINE_STORAGE_PATH/machines/\$machine_name/"
    echo "    eval \"\$(docker-machine env \$machine_name)\""

}

docker-env(){
    local param
    local quiet
    local HOST
    local params=($@)

    [[ ! `which docker-machine` ]] && echo docker-machine is not installed && return 1
    [[ ! -d $DOCKER_ENV_MACHINE_PATH ]] && mkdir -p $DOCKER_ENV_MACHINE_PATH

    for param in ${params[@]}; do
        [[ $param == '-q' || $param == '--quiet' ]] && quiet=1
    done

    for param in ${params[@]}; do
        case $param in
            -l|--ls)
                local env_list env_name env_dir
                env_list=`ls $DOCKER_ENV_MACHINE_PATH`
                if [[ $env_list ]]; then
                    for env_name in $env_list; do
                        env_dir=$DOCKER_ENV_MACHINE_PATH/$env_name
                        echo -n $env_name
                        if [[ -d $env_dir/certs ]]; then
                            if [[ -f $env_dir/certs/ca-key.pem ]]; then
                                echo " (ca)"
                            elif [[ -f $env_dir/certs/ca.pem ]]; then
                                echo " (crt)"
                            else
                                echo " (none)"
                            fi
                        else
                            echo " (none)"
                        fi
                    done
                else
                    echo It seems, there are no environments defined, yet
                fi

                return
                ;;
            -o|--open)
                open $DOCKER_ENV_DEFAULT_DOCKER_PATH
                return
                ;;
            --docker-machine-ls)
                docker-machine ls
                return
                ;;
            -u|--unset)
                unset DOCKER_REMOTE
                eval "$(docker-machine env -u)"
                return
                ;;
            --off)
                unset DOCKER_REMOTE
                unset MACHINE_STORAGE_PATH
                eval "$(docker-machine env -u)"
                return
                ;;
            --create-machine)
                local ip machine_name

                [[ ${#params[@]} != 3 ]] && echo "Usage: docker-env --create-machine ip machine_name" && return 1

                ip=${params[@]:1:1}
                machine_name=${params[@]:2:2}

                [[ ${params[${#params[@]}-3]} != "--create-machine" ]] && echo "Usage: docker-env --create-machine ip machine_name" && return 1
                [[ ! $MACHINE_STORAGE_PATH ]] && echo "Set MACHINE_STORAGE_PATH first: docker-env --activate $machine" && return 1

                if [[ ! -d $MACHINE_STORAGE_PATH/certs ]]; then
                    echo "Directory $MACHINE_STORAGE_PATH/certs not yet exists
Run \`docker-env --import\` first, otherwise we would create a new CA now.
If you intentionally want to do that, please use \`docker-machine create\`"
                    return 1
                fi

                docker-machine create --driver none --url tcp://$ip:2376 $machine_name||return 1
                cp -a `find $MACHINE_STORAGE_PATH/certs -type f|grep -v ca-key` $MACHINE_STORAGE_PATH/machines/$machine_name/
                echo ----
                echo
                echo Run this command to configure your shell: docker-env $machine_name
                return
                ;;
            --activate)
                local env_name

                env_name=${params[@]:1:1}

                [[ $env_name == -* ]] && echo "env name missing" && return 1

                if [[ ! -d $DOCKER_ENV_MACHINE_PATH/$env_name ]]; then
                    case ${params[@]:2:2} in
                        --yes|-y)
                            mkdir -p $DOCKER_ENV_MACHINE_PATH/$env_name
                            ;;
                        *)
                            if [[ ${params[@]:2:2} ]]; then
                                __docker-env__help
                                echo
                                echo Error: $@
                                return 1
                            fi

                            echo "Not a directory: $DOCKER_ENV_MACHINE_PATH/$env_name"
                            echo -n "Should we create it? [y/N] "
                            read create
                            if [[ $create == y ]]; then
                                mkdir -p $DOCKER_ENV_MACHINE_PATH/$env_name
                            else
                                return 1
                            fi
                            ;;
                    esac
                fi

                eval "$(docker-machine env -u)"
                unset DOCKER_REMOTE
                export MACHINE_STORAGE_PATH=$DOCKER_ENV_MACHINE_PATH/$env_name
                return
                ;;
            --export)
                local env_name
                if [[ ! $MACHINE_STORAGE_PATH ]]; then
                    echo MACHINE_STORAGE_PATH is not set, but required
                    echo "Set env first: docker-env --activate name"
                    return 1
                fi
                env_name=`basename $MACHINE_STORAGE_PATH`
                [[ ! -d $MACHINE_STORAGE_PATH/certs ]] && echo Directory $MACHINE_STORAGE_PATH/certs does not exists, yet && return 1
                [[ ! -f $MACHINE_STORAGE_PATH/certs/ca-key.pem ]] && echo No authority found && return 1
                [[ -f $env_name.tgz ]] && echo File $env_name.tgz exists && return 1
                tar -cvzf $env_name.tgz -C $MACHINE_STORAGE_PATH/certs --exclude .DS_Store --exclude ca-key.pem .
                [[ $quiet == 1 ]] || __docker-env__help_export $env_name
                return
                ;;
            --export-ca)
                local env_name
                if [[ ! $MACHINE_STORAGE_PATH ]]; then
                    echo MACHINE_STORAGE_PATH is not set, but required
                    echo "Set env first: docker-env --activate name"
                    return 1
                fi
                env_name=`basename $MACHINE_STORAGE_PATH`
                [[ ! -d $MACHINE_STORAGE_PATH/certs ]] && echo Directory $MACHINE_STORAGE_PATH/certs does not exists, yet && return 1
                [[ ! -f $MACHINE_STORAGE_PATH/certs/ca-key.pem ]] && echo No authority found && return 1
                [[ -f $env_name.ca.tgz ]] && echo File $env_name.ca.tgz exists && return 1
                tar -cvzf $env_name.ca.tgz -C $MACHINE_STORAGE_PATH/certs --exclude .DS_Store .
                return
                ;;
            --import)
                local ca_tar
                ca_tar=${params[@]:1:1}
                [[ $ca_tar == "--import" ]] && echo tgz path missing && return 1
                if [[ ! $MACHINE_STORAGE_PATH ]]; then
                    echo MACHINE_STORAGE_PATH is not set, but required
                    echo "Set env first: docker-env --activate name"
                    return 1
                fi
                [[ -d $MACHINE_STORAGE_PATH/certs ]] && echo Directory $MACHINE_STORAGE_PATH/certs exists && return 1

                if tar -tzf $ca_tar >/dev/null; then
                    mkdir -p $MACHINE_STORAGE_PATH/certs
                    tar xvzf $ca_tar -C $MACHINE_STORAGE_PATH/certs
                fi
                return
                ;;
            --deactivate)
                unset MACHINE_STORAGE_PATH
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
            --help)
                __docker-env__help
                return
                ;;
            *)
                HOST=$param
                break
                ;;
        esac
    done

    if [[ ! $HOST ]]; then
        __docker-env__help
        return 1
    fi
    if ! docker-machine env $HOST &>/dev/null; then
        echo Host does not exist: \"$HOST\"
        return 1
    fi

    if ! docker-machine env $HOST|grep -q Usage; then

        [[ $quiet == 1 ]] || echo Executing: eval \"\$\(docker-machine env $HOST\)\"

        eval "$(docker-machine env $HOST)"

    else
        __docker-env__help
        echo
        echo Error: Wrong option, or wrong docker-machine_name: $@
        return 1
    fi
    echo
    [[ $quiet == 1 ]] || __docker-env__show_vars $@
}

_docker-env(){
    local cur prev configfile;
    local -a config;
    local options="--docker-machine-ls --ls --open --unset --activate --export --export-ca --help --import --create-machine --deactivate --remote --show-env --off"
    local cas=`ls $DOCKER_ENV_MACHINE_PATH`
    local dmachines="`docker-machine ls -t 0 -q` --docker-machine-ls --help"

    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # either autocomplete machine_names, or options
    if [ $COMP_CWORD == 1 ]; then

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

# Docker settings for linux-arm for DCU

export IMAGE=${IMAGE:-'linux-arm'}
export CONTAINER=${CONTAINER:-'linux-arm'}
export NETWORK=${NETWORK:-'linux-arm'}
export DOCKER_USER=${DOCKER_USER:-'himanshu'}
export BASE_IMAGE=${BASE_IMAGE:-'osrf/ubuntu_armhf:focal'}

export DOCKER_SHELL=${DOCKER_SHELL:-'zsh'}
export DOCKER_SAVE=${DOCKER_SAVE:-true}

function Get-Opts {
    local opt output i remaining=false
    declare -A long_opts

    local opts=(${(f)1})
    shift

    for i in {1..${#opts}}; do
        opts[$i]=$(echo $opts[$i] | sed 's/^ *//;s/ *$//')
        long_opts[${opts[$i]%|*}]=${opts[$i]#*|}
    done

    # for key val in ${(kv)long_opts}; do
    #     echo "$key:\t\t$val" >&2
    # done

    while [[ $# -gt 0 && $1 != "--" ]]; do
        case $1 in
            --remaining)
                remaining=true
                ;;
            *)
                ;;
        esac
        shift
    done
    shift

    while (( $# )); do
        opt=$1
        shift

        if [[ $opt != "-"* ]]; then
            continue
        fi

        if [[ $opt == "--" ]]; then
            [[ $remaining == true ]] && output="$output remaining=\"$@\""
            break
        fi

        if [[ " ${(k)long_opts} " =~ " $opt " ]]; then
            opt=$long_opts[$opt]
        fi

        if [[ ! " ${(v)long_opts} " =~ " $opt " ]]; then
            echo "Invalid option: $opt" >&2
            return 1
        fi

        if [[ -z $1 ]] || [[ $1 == "-"* ]]; then
            output="$output ${${opt#-}#-}=true"
        else
            output="$output ${opt#-}=$1"
            shift
        fi
    done

    echo $output
}

# Initialize-Docker-Variables -image 'ubuntu:14.04-dev' -container 'trusty' -docker_user 'root' -docker_shell '' -network 'test' -base_image 'ubuntu:14.04' -docker_save true
function Initialize-Docker-Variables {
    export IMAGE= CONTAINER= NETWORK= DOCKER_USER= BASE_IMAGE= DOCKER_SHELL= DOCKER_SAVE=

    (( $# )) && local params=$(Get-Opts '
        -i|-image
        -c|-container
        -n|-network
        -u|-docker_user
        -b|-base_image
        -s|-docker_shell
        -v|-docker_save' -- $@) && [[ -n $params ]] && eval local $params || return 1

    [[ -z $image ]] && echo -n 'Enter image name to create or use [linux-arm(default)]: ' && read image
    [[ -z $container ]] && echo -n 'Enter container name [linux-arm(default)]: ' && read container
    [[ -z $network ]] && echo -n 'Enter network name [linux-arm(default)]: ' && read network
    [[ -z $docker_user ]] && echo -n 'Enter docker username [himanshu(default)]: ' && read docker_user
    [[ -z $base_image ]] && echo -n 'Enter base image name to (if) create above image from [osrf/ubuntu_armhf:focal(default)]: ' && read base_image
    [[ -z $docker_shell ]] && echo -n 'Enter shell to be used in container [zsh(default)]: ' && read docker_shell
    [[ -z $docker_save ]] && echo -n 'Save container image? [true(default)/false]: ' && read docker_save

    export IMAGE=${image:-'linux-arm'}
    export CONTAINER=${container:-'linux-arm'}
    export NETWORK=${network:-'linux-arm'}
    export DOCKER_USER=${docker_user:-'himanshu'}
    export BASE_IMAGE=${base_image:-'osrf/ubuntu_armhf:focal'}
    export DOCKER_SHELL=${docker_shell:-'zsh'}
    export DOCKER_SAVE=${docker_save:-true}
    echo "IMAGE=$IMAGE, CONTAINER=$CONTAINER, NETWORK=$NETWORK, DOCKER_USER=$DOCKER_USER, BASE_IMAGE=$BASE_IMAGE, DOCKER_SHELL=$DOCKER_SHELL, DOCKER_SAVE=$DOCKER_SAVE"
}

function Get-Docker-Binaries {
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -sc) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo usermod -aG docker $DOCKER_USER
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo systemctl status docker
    sudo docker run hello-world
}

function Initialize-Docker-Image {
    local install=false
    local image=$IMAGE
    local base_image=$BASE_IMAGE
    local container=$CONTAINER
    local docker_user=$DOCKER_USER

    (( $# )) && local params=$(Get-Opts '
        -i|-image
        -c|-container
        -b|-base_image
        -u|-docker_user
        -install' -- $@) && [[ -n $params ]] && eval local $params || return 1

    if [[ $image != 'linux-arm' && $install == false ]]; then
        docker tag $base_image $image
        echo "Tagged $base_image as $image"
        return
    fi

    [[ $docker_user == 'root' ]] && local docker_user_home='/root' || local docker_user_home="/home/$docker_user"

    # basic setup
    [[ "$(docker ps -a --format '" {{.Names}} "')" =~ " $container " ]] && docker stop $container
    docker pull $base_image
    docker run --rm -d -it --name $container $base_image sh

    [[ $docker_user == 'root' ]] || docker exec --user=root -it $container useradd -m -G 'adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev' $docker_user
    docker exec --user=root -it $container apt update
    docker exec --user=root -it $container apt install -y git zsh nano vim build-essential gcc g++ gdb libssl-dev

    docker exec --user=$docker_user -it $container git clone https://github.com/htanwar922/.zsh.git $docker_user_home/.zsh
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-autosuggestions.git $docker_user_home/.zsh/zsh-autosuggestions
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $docker_user_home/.zsh/zsh-syntax-highlighting
    docker exec --user=root -it $container apt-get install -y zsh-*
    docker exec --user=root -it $container apt install -y zsh-autosuggestions zsh-syntax-highlighting
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zshrc /root/.zshrc
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zprofile /root/.zprofile
    docker exec --user=root -it $container chsh -s /bin/zsh
    docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zshrc $docker_user_home/.zshrc
    docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zprofile $docker_user_home/.zshprofile
    docker exec --user=root -it $container chsh -s /bin/zsh $docker_user

    [[ $docker_user == 'root' ]] || docker exec --user=root -it $container zsh -c "echo '$docker_user ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers"

    docker commit $container $image
    docker stop $container
    echo 'Setup complete'
}

function Start-Docker-Container {
    local container=$CONTAINER
    local image=$IMAGE
    local network=$NETWORK
    local docker_user=$DOCKER_USER

    (( $# )) && local params=$(Get-Opts '
        -i|-image
        -c|-container
        -n|-network
        -u|-docker_user' --remaining -- $@) && [[ -n $params ]] && eval local $params || return 1

    [[ $docker_user == 'root' ]] && local docker_user_home='/root' || local docker_user_home="/home/$docker_user"

    docker network inspect $network >/dev/null || docker network create $network

    if [[ "$(docker ps -a --format '" {{.Names}} "')" =~ " $container " ]]; then
        read -q '?Container already exists. Do you want to remove it? [y/N]: ' && echo || return
        docker stop $container; sleep 1
        docker rm $container 2>/dev/null; sleep 1
    fi

    eval docker run --rm -d -it --privileged --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
        --network $network "$remaining" \
        -v "$HOME/.ssh:$docker_user_home/.ssh" \
        -v "$HOME/concentrator:$docker_user_home/concentrator" \
        -v "$HOME/Downloads:$docker_user_home/Downloads" \
        --name $container --user=$docker_user $image
}

function Invoke-Docker-Container {
    local cmd
    local container=$CONTAINER
    local docker_user=$DOCKER_USER

    (( $# )) && local params=$(Get-Opts '
        -c|-container
        -u|-docker_user
        -cmd' --remaining -- $@) && [[ -n $params ]] && eval local $params || return 1
    echo $params

    [[ -z $cmd ]] && cmd="$DOCKER_SHELL -ilsc 'cd; $DOCKER_SHELL -ils'"
    ${SHELL:-''} -c "docker exec --user=$docker_user -it $container $cmd"
    Save-Docker-Container -container $container
}

function Save-Docker-Container {
    local container=$CONTAINER
    local image

    (( $# )) && local params=$(Get-Opts '
        -c|-container
        -i|-image' -- $@) && [[ -n $params ]] && eval local $params || return 1

    [[ -z $image ]] && image=$(docker inspect --format='{{.Config.Image}}' $container)
    echo "Saving container $container as image $image"
    [[ $DOCKER_SAVE == true ]] && docker commit $container $image
}

function Clear-Docker-Images {
    docker images --format '{{.Repository}}:{{.Tag}}:{{.ID}}' | \
        awk -F: '/<none>/ {print $3}' | xargs -r docker rmi --force
}

function Remove-Docker-Container {
    local container=$CONTAINER
    local force=false

    (( $# )) && local params=$(Get-Opts '
        -c|-container
        -f|-force' -- $@) && [[ -n $params ]] && eval local $params || return 1

    local networks=$(docker container inspect $container --format='{{range $key, $value := .NetworkSettings.Networks}} {{$key}} {{end}}')

    docker stop $container; sleep 1
    if [[ "$(docker ps -a --format '" {{.Names}} "')" =~ " $container " ]]; then
        docker rm $container $([[ $force == true ]] && echo '--force' ) || \
            echo Failed to remove container $container && \
            return
    fi

    if [[ $force != true ]]; then
        return
    fi

    local network
    for network in ${(z)networks}; do
        local containers=$(docker network inspect $network --format='{{range $key, $value := .Containers}} {{$value.Name}} {{end}}')
        if [[ -z $containers && ! 'bridge | host | none' =~ $network ]]; then
            docker network rm $network
        fi
    done

    Clear-Docker-Images
}

function Stop-Docker-Container {
    local container=$CONTAINER

    (( $# )) && local params=$(Get-Opts '
        -c|-container' -- $@) && [[ -n $params ]] && eval local $params || return 1

    Save-Docker-Container -container $container
    Remove-Docker-Container -container $container
}

function _Set-Docker-AutoComplete-Suggestions {
    _docker
    case $state in
        image)
            __docker_complete_images
            ;;
        container)
            __docker_complete_containers
            ;;
        network)
            __docker_complete_networks
            ;;
        docker_user)
            _describe -t user-names 'docker username' "(root $DOCKER_USER)"
            ;;
        base_image)
            __docker_complete_images
            ;;
        docker_shell)
            _describe -t shell-names 'Shell' '(zsh bash sh ash)'
            ;;
        docker_save|force)
            _describe -t save-options 'Save Options' '(true false)'
            ;;
    esac

}

function _Initialize-Docker-Variables-AutoComplete {
    _arguments \
        '(-image)-image[Image name to create or use]: :->image' \
        '(-container)-container[Container name]: :->container' \
        '(-network)-network[Network name]: :->network' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user' \
        '(-base_image)-base_image[Base image name to create above image from]: :->base_image' \
        '(-docker_shell)-docker_shell[Shell to be used in container]: :->docker_shell' \
        '(-docker_save)-docker_save[Save container image?]: :->docker_save'

    _Set-Docker-AutoComplete-Suggestions
}

function _Initialize-Docker-Image-AutoComplete {
    _arguments \
        '(-image)-image[Image name to create or use]: :->image' \
        '(-container)-container[Container name]: :->container' \
        '(-base_image)-base_image[Base image name to create above image from]: :->base_image' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user' \
        '(-install)-install[Install docker]: :->install'

    _Set-Docker-AutoComplete-Suggestions
}

function _Start-Docker-Container-AutoComplete {
    _arguments \
        '(-image)-image[Image name to create or use]: :->image' \
        '(-container)-container[Container name]: :->container' \
        '(-network)-network[Network name]: :->network' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user'

    _Set-Docker-AutoComplete-Suggestions
}

function _Invoke-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user' \
        '(-cmd)-cmd[Command to run]: :->cmd'

    _Set-Docker-AutoComplete-Suggestions
}

function _Save-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container' \
        '(-image)-image[Image name to save as]: :->image'

    _Set-Docker-AutoComplete-Suggestions
}

function _Remove-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container' \
        '(-force)-force[Force remove container]: :->force'

    _Set-Docker-AutoComplete-Suggestions
}

function _Stop-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container'

    _Set-Docker-AutoComplete-Suggestions
}

compdef _Initialize-Docker-Variables-AutoComplete Initialize-Docker-Variables
compdef _Initialize-Docker-Image-AutoComplete Initialize-Docker-Image
compdef _Start-Docker-Container-AutoComplete Start-Docker-Container
compdef _Invoke-Docker-Container-AutoComplete Invoke-Docker-Container
compdef _Save-Docker-Container-AutoComplete Save-Docker-Container
compdef _Remove-Docker-Container-AutoComplete Remove-Docker-Container
compdef _Stop-Docker-Container-AutoComplete Stop-Docker-Container

alias docker-setup-image='Initialize-Docker-Image'
alias docker-start-container='Start-Docker-Container'
alias docker-run-container='Invoke-Docker-Container'
alias docker-stop-container='Stop-Docker-Container'
alias docker-cleanup-container='Remove-Docker-Container'
alias docker-save-container='Save-Docker-Container'
alias docker-clear-images='Clear-Docker-Images'


# _docker () {
#     if [[ $service != docker ]]
#     then
#             _call_function - _$service
#             return
#     fi
#     echo $curcontext
#     local curcontext="$curcontext" state line help="-h --help"
#     integer ret=1
#     typeset -A opt_args
#     _arguments $(__docker_arguments) -C \
#         "(: -)"{-h,--help}"[Print usage]" \
#         "($help)--config[Location of client config files]:path:_directories" \
#         "($help -c --context)"{-c=,--context=}"[Execute the command in a docker context]:context:__docker_complete_contexts" \
#         "($help -D --debug)"{-D,--debug}"[Enable debug mode]" \
#         "($help -H --host)"{-H=,--host=}"[tcp://host:port to bind/connect to]:host: " \
#         "($help -l --log-level)"{-l=,--log-level=}"[Logging level]:level:(debug info warn error fatal)" \
#         "($help)--tls[Use TLS]" \
#         "($help)--tlscacert=[Trust certs signed only by this CA]:PEM file:_files -g "*.(pem|crt)"" \
#         "($help)--tlscert=[Path to TLS certificate file]:PEM file:_files -g "*.(pem|crt)"" \
#         "($help)--tlskey=[Path to TLS key file]:Key file:_files -g "*.(pem|key)"" \
#         "($help)--tlsverify[Use TLS and verify the remote]" \
#         "($help)--userland-proxy[Use userland proxy for loopback traffic]" \
#         "($help -v --version)"{-v,--version}"[Print version information and quit]" \
#         "($help -): :->command" "($help -)*:: :->option-or-argument" && ret=0
#     local host=${opt_args[-H]}${opt_args[--host]}
#     local config=${opt_args[--config]}
#     local context=${opt_args[-c]}${opt_args[--context]}
#     local docker_options="${host:+--host $host} ${config:+--config $config} ${context:+--context $context} "
#     echo
#     echo $curcontext
#     echo "${curcontext%:*:*}:docker-$words[1]:"
#     echo $state "$words[@]"
#     echo
#             state=option-or-argument
#     case $state in
#             (command) __docker_commands && ret=0; echo ok  ;;
#             (option-or-argument) curcontext=${curcontext%:*:*}:docker-$words[1]:
#                         echo
#                         echo $curcontext
#                         echo "${curcontext%:*:*}:docker-$words[1]:"
#                         echo $state $words[1]
#                         echo
#                         __docker_subcommand && ret=0  ;;
#     esac
#     return ret
# }
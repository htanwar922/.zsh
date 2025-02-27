# Docker settings for linux-arm for DCU

export IMAGE=${IMAGE:-'linux'}
export CONTAINER=${CONTAINER:-'linux'}
export NETWORK=${NETWORK:-'bridge'}
export DOCKER_USER=${DOCKER_USER:-'himanshu'}
export BASE_IMAGE=${BASE_IMAGE:-'debian'}

export DOCKER_SHELL=${DOCKER_SHELL:-'zsh'}
export DOCKER_SAVE=${DOCKER_SAVE:-true}

export true=true
export false=false

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
            [[ $remaining == true ]] && output="$output remaining='$@'"
            break
        fi

        if [[ " ${(k)long_opts} " =~ " $opt " ]]; then
            opt=$long_opts[$opt]
        fi

        if [[ ! " ${(v)long_opts} " =~ " $opt " ]]; then
            echo "Invalid option: $opt" >&2
            return 1
        fi

        # replace - with _ in $opt, for example no-mounts -> no_mounts
        opt=${${opt#-}#-}
        opt=$(echo $opt | sed 's/-/_/g')

        if [[ -z $1 ]] || [[ $1 == "-"* ]]; then
            output="$output $opt=true"
        else
            output="$output $opt='$1'"
            shift
        fi
    done

    echo $output
}

# Initialize-Docker-Variables -image 'ubuntu:14.04-dev' -container 'trusty' -docker_user 'root' -docker_shell '' -network 'test' -base_image 'ubuntu:14.04' -docker_save true
function Initialize-Docker-Variables {
    export IMAGE= CONTAINER= NETWORK= DOCKER_USER= BASE_IMAGE= DOCKER_SHELL= DOCKER_SAVE=

    if (( $# )); then
        local params=$(Get-Opts '
            -i|-image
            -c|-container
            -n|-network
            -u|-docker_user
            -b|-base_image
            -s|-docker_shell
            -v|-docker_save' -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi

    [[ -z $image ]] && echo -n 'Enter image name to create or use [dcu-emulator:dev(default)]: ' && read image
    [[ -z $container ]] && echo -n 'Enter container name [dcu(default)]: ' && read container
    [[ -z $network ]] && echo -n 'Enter network name [bridge(default)]: ' && read network
    [[ -z $docker_user ]] && echo -n 'Enter docker username [root(default)]: ' && read docker_user
    [[ -z $base_image ]] && echo -n 'Enter base image name to (if) create above image from [osrf/ubuntu_armhf:trusty(default)]: ' && read base_image
    [[ -z $docker_shell ]] && echo -n 'Enter shell to be used in container [zsh(default)]: ' && read docker_shell
    [[ -z $docker_save ]] && echo -n 'Save container image? [true/false(default)]: ' && read docker_save

    export IMAGE=${image:-'linux-arm'}
    export CONTAINER=${container:-'linux-arm'}
    export NETWORK=${network:-'linux-arm'}
    export DOCKER_USER=${docker_user:-'himanshu'}
    export BASE_IMAGE=${base_image:-'osrf/ubuntu_armhf:focal'}
    export DOCKER_SHELL=${docker_shell:-'zsh'}
    export DOCKER_SAVE=${docker_save:-false}
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

    if (( $# )); then
        local params=$(Get-Opts '
            -i|-image
            -c|-container
            -b|-base_image
            -u|-docker_user
            -install' -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi

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

    [[ $docker_user == 'root' ]] || \
        docker exec --user=root -it $container useradd -mG 'adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev' $docker_user
    docker exec --user=root -it $container apt update
    docker exec --user=root -it $container apt install -y git zsh nano vim build-essential gcc g++ gdb libssl-dev
    docker exec --user=root -it $container apt install -y iputils-ping net-tools iproute2

    docker exec --user=root -it $container apt-get install -y zsh-*
    docker exec --user=root -it $container apt install -y zsh-autosuggestions zsh-syntax-highlighting
    docker exec --user=$docker_user -it $container git clone https://github.com/htanwar922/.zsh.git $docker_user_home/.zsh
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-autosuggestions.git $docker_user_home/.zsh/zsh-autosuggestions
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $docker_user_home/.zsh/zsh-syntax-highlighting

    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zshrc /root/.zshrc
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zprofile /root/.zprofile
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zshenv /root/.zshenv
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zlogin /root/.zlogin
    docker exec --user=root -it $container ln -s $docker_user_home/.zsh/zlogout /root/.zlogout
    docker exec --user=root -it $container chsh -s /bin/zsh

    if [[ $docker_user != 'root' ]]; then
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zshrc $docker_user_home/.zshrc
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zprofile $docker_user_home/.zprofile
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zshenv $docker_user_home/.zshenv
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zlogin $docker_user_home/.zlogin
        docker exec --user=$docker_user -it $container ln -s $docker_user_home/.zsh/zlogout $docker_user_home/.zlogout
        docker exec --user=root -it $container chsh -s /bin/zsh $docker_user

        docker exec --user=root -it $container zsh -c "echo '$docker_user ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers"
    fi

    docker commit $container $image
    docker stop $container
    echo 'Setup complete'
}

function Start-Docker-Container {
    local container=$CONTAINER
    local image=$IMAGE
    local network=$NETWORK
    local docker_user=$DOCKER_USER
    local no_mounts=false
    local no_cmd=false

    if (( $# )); then
        local params=$(Get-Opts '
            -i|-image
            -c|-container
            -n|-network
            -u|-docker_user
            --no-mounts
            --no-cmd
            --trace' --remaining -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi

    [[ $docker_user == 'root' ]] && local docker_user_home='/root' || local docker_user_home="/home/$docker_user"

    docker network inspect $network >/dev/null || \
        docker network create $network

    if [[ "$(docker ps -a --format '" {{.Names}} "')" =~ " $container " ]]; then
        read -q '?Container already exists. Do you want to remove it? [y/N]: ' && echo || return
        docker stop $container
        sleep 1
        docker rm $container 2>/dev/null
        sleep 1
    fi

    local params=''
    params="$params --rm"
    params="$params -d"
    params="$params -it"
    params="$params --privileged"
    params="$params --cap-add=SYS_PTRACE"
    params="$params --cap-add=NET_ADMIN"
    params="$params --security-opt seccomp=unconfined"
    params="$params --security-opt apparmor=unconfined"
    params="$params -e TZ=Asia/Kolkata"

    if [[ $no_mounts != true ]]; then
        params="$params -e DISPLAY=$DISPLAY"
        params="$params -v /tmp/.X11-unix:/tmp/.X11-unix"
        params="$params -v $HOME/.ssh:$docker_user_home/.ssh"
        params="$params -v $HOME/concentrator:$docker_user_home/concentrator"
        params="$params -v $HOME/Downloads:$docker_user_home/Downloads"
    fi

    params="$params --network $network"
    params="$params --user=$docker_user"
    params="$params $remaining"

    if [[ $trace == true ]]; then
        echo docker run $params --name $container $image $( [[ $no_cmd == true ]] || echo $DOCKER_SHELL )
    fi

    eval docker run $params --name $container $image $( [[ $no_cmd == true ]] || echo $DOCKER_SHELL )
}

function Invoke-Docker-Container {
    local cmd
    local container=$CONTAINER
    local docker_user=$DOCKER_USER

    if (( $# )); then
        local params=$(Get-Opts '
            -c|-container
            -u|-docker_user
            -cmd' --remaining -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi
    echo $params

    [[ -z $cmd && -n $remaining ]] && cmd="$remaining"
    [[ -z $cmd ]] && cmd="$DOCKER_SHELL -ilsc 'cd; $DOCKER_SHELL -ils'"
    ${SHELL:-'sh'} -c "docker exec --user=$docker_user -it $container $cmd"
    [[ $DOCKER_SAVE == true ]] &&
        Save-Docker-Container -container $container
}

function Save-Docker-Container {
    local container=$CONTAINER
    local image

    if (( $# )); then
        local params=$(Get-Opts '
            -c|-container
            -i|-image' -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi

    [[ -z $image ]] && \
        image=$(docker inspect --format='{{.Config.Image}}' $container)

    echo "Saving container $container as image $image"
    docker commit $container $image
}

function Clear-Docker-Images {
    docker images --format '{{.Repository}}:{{.Tag}}:{{.ID}}' | \
        awk -F: '/<none>/ {print $3}' | xargs -r docker rmi --force
}

function Remove-Docker-Container {
    local container=$CONTAINER
    local force=false

    if (( $# )); then
        local params=$(Get-Opts '
            -c|-container
            -f|-force' -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi

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

    if (( $# )); then
        local params=$(Get-Opts '
            -c|-container' -- $@) && [[ -n $params ]] && eval local $params || return 1
    fi

    [[ $DOCKER_SAVE == true ]] && \
        Save-Docker-Container -container $container

    Remove-Docker-Container -container $container
}

function Set-Docker-AutoComplete-Suggestions {
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

    Set-Docker-AutoComplete-Suggestions
}

function _Initialize-Docker-Image-AutoComplete {
    _arguments \
        '(-image)-image[Image name to create or use]: :->image' \
        '(-container)-container[Container name]: :->container' \
        '(-base_image)-base_image[Base image name to create above image from]: :->base_image' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user' \
        '(-install)-install[Install docker]: :->install'

    Set-Docker-AutoComplete-Suggestions
}

function _Start-Docker-Container-AutoComplete {
    _arguments \
        '(-image)-image[Image name to create or use]: :->image' \
        '(-container)-container[Container name]: :->container' \
        '(-network)-network[Network name]: :->network' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user' \
        '(-no-mounts)--no-mounts[Do not mount volumes]' \
        '(-no-cmd)--no-cmd[Do not run command]' \

    Set-Docker-AutoComplete-Suggestions
}

function _Invoke-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container' \
        '(-docker_user)-docker_user[Docker username]: :->docker_user' \
        '(-cmd)-cmd[Command to run]: :->cmd'

    Set-Docker-AutoComplete-Suggestions
}

function _Save-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container' \
        '(-image)-image[Image name to save as]: :->image'

    Set-Docker-AutoComplete-Suggestions
}

function _Remove-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container' \
        '(-force)-force[Force remove container]: :->force'

    Set-Docker-AutoComplete-Suggestions
}

function _Stop-Docker-Container-AutoComplete {
    _arguments \
        '(-container)-container[Container name]: :->container'

    Set-Docker-AutoComplete-Suggestions
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

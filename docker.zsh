# Docker settings for linux-arm for DCU

export IMAGE=${IMAGE:-'linux-arm'}
export CONTAINER=${CONTAINER:-'linux-arm'}
export NETWORK=${NETWORK:-'linux-arm'}
export DOCKER_USER=${DOCKER_USER:-'himanshu'}
export BASE_IMAGE=${BASE_IMAGE:-'osrf/ubuntu_armhf:focal'}

export DOCKER_SHELL=${DOCKER_SHELL:-'zsh'}
export DOCKER_SAVE=${DOCKER_SAVE:-true}

# Initialize-Docker-Variables -image 'ubuntu:14.04-dev' -container 'trusty' -user 'root' -docker_shell 'bash' -network 'test' -base_image 'ubuntu:14.04' -docker_save true
function Initialize-Docker-Variables {
    export IMAGE= CONTAINER= NETWORK= DOCKER_USER= BASE_IMAGE= DOCKER_SHELL= DOCKER_SAVE=

    while true; do
        case "$1" in
            -i|-image) IMAGE=$2;;
            -c|-container) CONTAINER=$2;;
            -n|-network) NETWORK=$2;;
            -u|-user) DOCKER_USER=$2;;
            -b|-base_image) BASE_IMAGE=$2;;
            -s|-docker_shell) DOCKER_SHELL=$2;;
            -v|-docker_save) DOCKER_SAVE=$2;;
            --) shift; break;;
            "") break;;
        esac
        shift
        [[ $1 == -* ]] || shift
    done

    [[ -z $IMAGE ]] && echo -n 'Enter image name to create or use [linux-arm(default)]: ' && read IMAGE
    [[ -z $CONTAINER ]] && echo -n 'Enter container name [linux-arm(default)]: ' && read CONTAINER
    [[ -z $NETWORK ]] && echo -n 'Enter network name [linux-arm(default)]: ' && read NETWORK
    [[ -z $DOCKER_USER ]] && echo -n 'Enter docker username [himanshu(default)]: ' && read DOCKER_USER
    [[ -z $BASE_IMAGE ]] && echo -n 'Enter base image name to (if) create above image from [osrf/ubuntu_armhf:focal(default)]: ' && read BASE_IMAGE
    [[ -z $DOCKER_SHELL ]] && echo -n 'Enter shell to be used in container [zsh(default)]: ' && read DOCKER_SHELL
    [[ -z $DOCKER_SAVE ]] && echo -n 'Save container image? [true(default)/false]: ' && read DOCKER_SAVE
    export IMAGE=${IMAGE:-'linux-arm'}
    export CONTAINER=${CONTAINER:-'linux-arm'}
    export NETWORK=${NETWORK:-'linux-arm'}
    export DOCKER_USER=${DOCKER_USER:-'himanshu'}
    export BASE_IMAGE=${BASE_IMAGE:-'osrf/ubuntu_armhf:focal'}
    export DOCKER_SHELL=${DOCKER_SHELL:-'zsh'}
    export DOCKER_SAVE=${DOCKER_SAVE:-true}
    echo "IMAGE=$IMAGE, CONTAINER=$CONTAINER, NETWORK=$NETWORK, DOCKER_USER=$DOCKER_USER, BASE_IMAGE=$BASE_IMAGE, DOCKER_SHELL=$DOCKER_SHELL, DOCKER_SAVE=$DOCKER_SAVE"
}

function Set-Docker-Env {
    local kvp=() vars=() env_list

    for var in "$@"; do
        vars+=($var)
        kvp+=($var=$(eval echo \$$var))
    done

    for entry in "${kvp[@]}"; do
        local key=${entry%%=*}
        local value=${entry#*=}
        export $key=$value
        WSLENV="${WSLENV:+$WSLENV:}$key"
    done
    export WSLENV
}

function Get-Docker-Binaries {
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo usermod -aG docker $USER
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo systemctl status docker
    sudo docker run hello-world
}

function Initialize-Docker-Image {
    local docker_user_home
    [[ $DOCKER_USER == 'root' ]] && docker_user_home='/root' || docker_user_home="/home/$DOCKER_USER"

    while true; do
        case "$1" in
            -i|-install) install=true;;
            --) shift; break;;
            "") break;;
        esac
        shift
        [[ $1 == -* ]] || shift
    done

    if [[ $IMAGE != 'linux-arm' ]]; then
        docker tag $BASE_IMAGE $IMAGE
        echo "Tagged $BASE_IMAGE as $IMAGE"
        [[ -z $install ]] && return
    fi

    docker ps -a | grep $CONTAINER && docker stop $CONTAINER
    docker pull $BASE_IMAGE
    docker run --rm -d -it --name $CONTAINER $BASE_IMAGE bash

    docker exec --user=root $CONTAINER useradd -m -G 'adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev' $DOCKER_USER
    docker exec --user=root $CONTAINER apt update
    docker exec --user=root $CONTAINER apt install -y git zsh nano vim build-essential gcc g++ gdb libssl-dev
    docker exec --user=$DOCKER_USER $CONTAINER git clone https://github.com/htanwar922/.zsh.git $docker_user_home/.zsh

    docker exec --user=root $CONTAINER apt-get install -y zsh-autosuggestions zsh-syntax-highlighting
    docker exec --user=root $CONTAINER ln -s $docker_user_home/.zsh/zshrc /root/.zshrc
    docker exec --user=root $CONTAINER ln -s $docker_user_home/.zsh/zprofile /root/.zprofile
    docker exec --user=root $CONTAINER chsh -s /bin/zsh
    docker exec --user=$DOCKER_USER $CONTAINER ln -s $docker_user_home/.zsh/zshrc $docker_user_home/.zshrc
    docker exec --user=$DOCKER_USER $CONTAINER ln -s $docker_user_home/.zsh/zprofile $docker_user_home/.zshprofile
    docker exec --user=root $CONTAINER chsh -s /bin/zsh $DOCKER_USER
    docker exec --user=root $CONTAINER zsh -c "echo '$DOCKER_USER ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

    docker commit $CONTAINER $IMAGE
    docker stop $CONTAINER
    echo 'Setup complete'
}

function Start-Docker-Container {
    local docker_user_home
    [[ $DOCKER_USER == 'root' ]] && docker_user_home='/root' || docker_user_home="/home/$DOCKER_USER"

    docker network create $NETWORK
    docker ps -a | grep $CONTAINER && docker stop $CONTAINER
    sleep 1
    docker run --rm -d -it --privileged --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
        --network $NETWORK \
        -v "$HOME/.ssh:$docker_user_home/.ssh" \
        -v "$HOME/concentrator:$docker_user_home/concentrator" \
        -v "$HOME/Downloads:$docker_user_home/Downloads" \
        --name $CONTAINER --user=$DOCKER_USER $IMAGE
}

function Invoke-Docker-Container {
    local cmd=$1
    [[ -z $cmd ]] && cmd="$DOCKER_SHELL -ilsc 'cd; $DOCKER_SHELL -ils'"
    ${SHELL:-'bash'} -c "docker exec --user=$DOCKER_USER -it $CONTAINER $cmd"
    Save-Docker-Container
}

function Save-Docker-Container {
    [[ $DOCKER_SAVE == true ]] && docker commit $CONTAINER $IMAGE
}

function Remove-Docker-Container {
    docker stop $CONTAINER
    docker network rm $NETWORK
    docker images | awk '/<none>/ {print $3}' | xargs -r docker rmi --force
}

function Stop-Docker-Container {
    Save-Docker-Container
    Remove-Docker-Container
}

alias docker-env='Set-Docker-Env'
alias docker-setup-image='Initialize-Docker-Image'
alias docker-start-container='Start-Docker-Container'
alias docker-run-container='Invoke-Docker-Container'
alias docker-stop-container='Stop-Docker-Container'
alias docker-cleanup-container='Remove-Docker-Container'
alias docker-save-container='Save-Docker-Container'


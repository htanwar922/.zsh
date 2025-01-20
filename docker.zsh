# Docker settings for linux-arm for DCU

export IMAGE=${IMAGE:-'linux-arm'}
export CONTAINER=${CONTAINER:-'linux-arm'}
export NETWORK=${NETWORK:-'linux-arm'}
export DOCKER_USER=${DOCKER_USER:-'himanshu'}
export BASE_IMAGE=${BASE_IMAGE:-'osrf/ubuntu_armhf:focal'}

export DOCKER_SHELL=${DOCKER_SHELL:-'zsh'}
export DOCKER_SAVE=${DOCKER_SAVE:-true}

# Initialize-Docker-Variables -image 'ubuntu:14.04-dev' -container 'trusty' -user 'root' -docker_shell '' -network 'test' -base_image 'ubuntu:14.04' -docker_save true
function Initialize-Docker-Variables {
    export IMAGE= CONTAINER= NETWORK= DOCKER_USER= BASE_IMAGE= DOCKER_SHELL= DOCKER_SAVE=

    while (( $# )); do
        case "$1" in
            -i|-image) IMAGE=$2;;
            -c|-container) CONTAINER=$2;;
            -n|-network) NETWORK=$2;;
            -u|-user) DOCKER_USER=$2;;
            -b|-base_image) BASE_IMAGE=$2;;
            -s|-docker_shell) DOCKER_SHELL=$2;;
            -v|-docker_save) DOCKER_SAVE=$2;;
            --) shift; break;;
            '') break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
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

function Get-Docker-Binaries {
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -sc) stable"
    sudo apt update
    sudo apt install -y docker-ce
    sudo usermod -aG docker $USER
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

    while (( $# )); do
        case "$1" in
            -i|-image) image=$2;;
            -c|-container) container=$2;;
            -b|-base_image) base_image=$2;;
            -u|-user) docker_user=$2;;
            -install) install=true;;
            --) shift; break;;
            '') break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
    done

    if [[ $image != 'linux-arm' && $install == false ]]; then
        docker tag $base_image $image
        echo "Tagged $base_image as $image"
        return
    fi

    [[ $docker_user == 'root' ]] && local docker_user_home='/root' || local docker_user_home="/home/$docker_user"

    # basic setup
    docker ps -a | grep $container && docker stop $container
    docker pull $base_image
    docker run --rm -d -it --name $container $base_image sh

    [[ $docker_user == 'root' ]] || docker exec --user=root -it $container useradd -m -G 'adm,dialout,cdrom,floppy,sudo,audio,dip,video,plugdev' $docker_user
    docker exec --user=root -it $container apt update
    docker exec --user=root -it $container apt install -y git zsh nano vim build-essential gcc g++ gdb libssl-dev

    docker exec --user=$docker_user -it $container git clone https://github.com/htanwar922/.zsh.git $docker_user_home/.zsh
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-autosuggestions.git $USER_HOME/.zsh/zsh-autosuggestions
    # docker exec --user=$docker_user -it $container git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $USER_HOME/.zsh/zsh-syntax-highlighting
    docker exec --user=root -it $container apt install -y zsh-*
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

    while (( $# )); do
        case "$1" in
            -i|-image) image=$2;;
            -c|-container) container=$2;;
            -n|-network) network=$2;;
            -u|-user) docker_user=$2;;
            --) shift; break;;
            '') break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
    done

    [[ $docker_user == 'root' ]] && local docker_user_home='/root' || local docker_user_home="/home/$docker_user"

    docker network inspect $network >/dev/null || docker network create $network

    docker ps -a | grep $container && read -q '?Container already exists. Do you want to remove it? [y/N]: ' && echo || return
    docker stop $container; sleep 1
    docker rm $container 2>/dev/null; sleep 1

    eval docker run --rm -d -it --privileged --cap-add=SYS_PTRACE \
        --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
        --network $network "$@" \
        -v "$HOME/.ssh:$docker_user_home/.ssh" \
        -v "$HOME/concentrator:$docker_user_home/concentrator" \
        -v "$HOME/Downloads:$docker_user_home/Downloads" \
        --name $container --user=$docker_user $image
}

function Invoke-Docker-Container {
    local cmd
    local container=$CONTAINER
    local docker_user=$DOCKER_USER

    while (( $# )); do
        case "$1" in
            -c|-container) container=$2;;
            -u|-user) docker_user=$2;;
            -cmd) cmd=$2; shift;;
            --) shift; break;;
            '') break;;
             *) break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
    done
    cmd="$cmd $@"

    [[ -z $cmd ]] && cmd="$DOCKER_SHELL -ilsc 'cd; $DOCKER_SHELL -ils'"
    ${SHELL:-''} -c "docker exec --user=$docker_user -it $container $cmd"
    Save-Docker-Container -container $container -image $image
}

function Save-Docker-Container {
    local container=$CONTAINER
    local image

    while (( $# )); do
        case "$1" in
            -c|-container) container=$2;;
            -i|-image) image=$2;;
            --) shift; break;;
            '') break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
    done

    [[ -z $image ]] && image=$(docker inspect --format='{{.Config.Image}}' $container)
    [[ $DOCKER_SAVE == true ]] && docker commit $container $image
}

function Clear-Docker-Images {
    docker images --format '{{.Repository}}:{{.Tag}}:{{.ID}}' | \
        awk -F: '/<none>/ {print $3}' | xargs -r docker rmi --force
}

function Remove-Docker-Container {
    local container=$CONTAINER
    local force=false

    while (( $# )); do
        case "$1" in
            -c|-container) container=$2;;
            -f|-force) force=true;;
            --) shift; break;;
            '') break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
    done

    local networks=$(docker container inspect $container --format='{{range $key, $value := .NetworkSettings.Networks}} {{$key}} {{end}}')

    docker stop $container
    [[ $force == true ]] && docker rm -f $container || docker rm $container

    sleep 1
    docker container inspect $container && echo "Failed to remove container $container" && return

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

    while (( $# )); do
        case "$1" in
            -c|-container) container=$2;;
            --) shift; break;;
            '') break;;
        esac
        shift
        [[ $1 == -* ]] || [[ -z $1 ]] && break || shift
    done

    Save-Docker-Container -container $container
    Remove-Docker-Container -container $container
}

function Set-Docker-AutoComplete-Suggestions {
    case $state in
        image)
            local images=($(docker images --format '{{.Repository}}:{{.Tag}}'))
            _describe -t docker-images 'Image' images
            ;;
        container)
            local containers=($(docker ps -a --format '{{.Names}}'))
            _describe -t docker-containers 'Container' containers
            ;;
        network)
            local networks=($(docker network ls --format '{{.Name}}'))
            _describe -t docker-networks 'Network' networks
            ;;
        user)
            _describe -t user-names 'User' "(root $USER)"
            ;;
        base_image)
            local images=($(docker images --format '{{.Repository}}:{{.Tag}}'))
            _describe -t docker-images 'Base Image' images
            ;;
        docker_shell)
            _describe -t shell-names 'Shell' '(zsh bash sh ash)'
            ;;
        docker_save)
            _describe -t save-options 'Save Options' '(true false)'
            ;;
    esac

}

function Set-Docker-AutoComplete {
    # # Define the available options
    # local -a options
    # options=(
    #     '-image: Image name to create or use'
    #     '-container: Container name'
    #     '-network: Network name'
    #     '-user: Docker username'
    #     '-base_image: Base image name to create above image from'
    #     '-docker_shell: Shell to be used in container'
    #     '-docker_save: Save container image? [true(default)/false]'
    # )
    # # Set up the arguments completion structure
    # _arguments \
    #     '1: :->option' \
    #     '2: :->value'
    # # Completions based on the current state
    # local word=${word:-${words[$CURRENT-1]}}
    # echo \' $state -- $words -- $CURRENT -- $word \'
    # case $state in
    #     option)
    #         # Option completion: Provide available options like -image, -container, etc.
    #         _describe 'options' options
    #         ;;
    #     value)
    #         # Value completion for the first argument
    #         if [[ "${word}" == *"-image"* ]]; then
    #             # If -image is selected, complete image names from Docker images list
    #             _describe -t docker-images 'Docker Image Names' images
    #         elif [[ "${word}" == *"-container"* ]]; then
    #             # If -container is selected, complete container names (you can define them or pull from Docker)
    #             _describe -t docker-images 'container1 container2 container3'
    #         fi
    #         ;;
    # esac

    # Argument matching for options and values
    _arguments \
        '(-image)-image[Image name to create or use]: :->image' \
        '(-container)-container[Container name]: :->container' \
        '(-network)-network[Network name]: :->network' \
        '(-user)-user[Docker username]: :->user' \
        '(-base_image)-base_image[Base image name to create above image from]: :->base_image' \
        '(-docker_shell)-docker_shell[Shell to be used in container]: :->docker_shell' \
        '(-docker_save)-docker_save[Save container image?]: :->docker_save'

    Set-Docker-AutoComplete-Suggestions
}

# Example test function that just prints out all arguments
function test {
    echo $@
}

# Bind the custom function Set-Docker-Image-AutoComplete to `test`
compdef Set-Docker-AutoComplete test

alias docker-setup-image='Initialize-Docker-Image'
alias docker-start-container='Start-Docker-Container'
alias docker-run-container='Invoke-Docker-Container'
alias docker-stop-container='Stop-Docker-Container'
alias docker-cleanup-container='Remove-Docker-Container'
alias docker-save-container='Save-Docker-Container'


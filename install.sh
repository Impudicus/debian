#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

runInstall() {
    case "${apt_release}" in
        unstable)
            cat "${config_dir}/apt/unstable.list" > "/etc/apt/sources.list"
            cat "${config_dir}/apt/bookworm.list" > "/etc/apt/sources.list.d/bookworm.list"
            ;;
        stable)
            cat "${config_dir}/apt/bookworm.list" > "/etc/apt/sources.list"
            ;;
    esac

    # apt update
    apt update
    apt upgrade --yes
    apt full-upgrade --yes

    # install requirements
    apt install --yes \
        bash-completion \
        curl \
        git \
        gpg \
        rsync \
        wget \
        xz-utils \
        wireguard

    # install firmware
    apt install --yes \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-realtek \
        linux-headers-amd64

    # install drivers
    case "${install_driver}" in
        amd)
            apt install --yes \
                firmware-amd-graphics \
                libgl1-mesa-dri \
                libglx-mesa0 \
                mesa-vulkan-drivers \
                xserver-xorg-video-amdgpu
            ;;
        vmware-tools)
            apt install --yes \
                open-vm-tools-desktop \
                open-vm-tools
            ;;
    esac

    # install gnome
    apt install --yes \
        gnome-session \
        gnome-shell \
        gnome-calculator \
        gnome-disk-utility \
        gnome-shell-extensions \
        gnome-control-center \
        gnome-system-monitor \
        gnome-terminal \
        gnome-tweaks \
        nautilus \
            nautilus-admin \
            nautilus-extension-gnome-terminal \
        network-manager-gnome \
        remmina \
        wpasupplicant

    # install tools
    apt install --yes \
        brasero \
        eog \
        evince \
        thunderbird \
        vlc

    wget "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" --output-document "/tmp/chrome.deb"
    apt install -f "/tmp/chrome.deb"
    rm --force "/tmp/chrome.deb"

    # install security-tools
    apt install --yes \
        clamav \
        clamtk

    # install apps
    if [[ "${install_apps}" ]]; then
        local package_name="balena-etcher"
        local package_installed=$(dpkg-query --show --showformat='${db:Status-Status}' "${package_name}" 2>/dev/null)
        if [[ ! "${package_installed}" ]]; then
            wget "https://github.com/balena-io/etcher/releases/download/v1.18.11/balena-etcher_1.18.11_amd64.deb" --output-document "/tmp/balena-etcher.deb"
            apt install --force "/tmp/balena-etcher.deb"
            rm --force "/tmp/balena-etcher.deb"
        fi

        local package_name="discord"
        local package_installed=$(dpkg-query --show --showformat='${db:Status-Status}' "${package_name}" 2>/dev/null)
        if [[ ! "${package_installed}" ]]; then
            wget "https://discord.com/api/download?platform=linux&format=deb" --output-document "/tmp/discord.deb"
            apt install --force "/tmp/discord.deb"
            rm --force "/tmp/discord.deb"
        fi

        local package_name="spotify-client"
        local package_installed=$(dpkg-query --show --showformat='${db:Status-Status}' "${package_name}" 2>/dev/null)
        if [[ ! "${package_installed}" ]]; then
            curl --silent --show-error "https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg" | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/spotify.gpg"
            cat "${config_dir}/apt/spotify.list" > "/etc/apt/sources.list.d/spotify.list"
            apt update
            apt install --yes \
                spotify-client
        fi

        local package_name="steam"
        local package_installed=$(dpkg-query --show --showformat='${db:Status-Status}' "${package_name}" 2>/dev/null)
        if [[ ! "${package_installed}" ]]; then
            wget "https://repo.steampowered.com/steam/archive/precise/steam_latest.deb" --output-document "/tmp/steam.deb"
            apt install --force "/tmp/steam.deb"
            rm --force "/tmp/steam.deb"
        fi

        local package_name="code"
        local package_installed=$(dpkg-query --show --showformat='${db:Status-Status}' "${package_name}" 2>/dev/null)
        if [[ ! "${package_installed}" ]]; then
            curl --silent --show-error "https://packages.microsoft.com/keys/microsoft.asc" | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/vscode.gpg"
            cat "${config_dir}/apt/vscode.list" > "/etc/apt/sources.list.d/vscode.list"
            apt update
            apt install --yes \
                code
        fi
    fi
}

runConfig() {
    local default_user=$(cat "/etc/passwd" | grep "1000" | cut --delimiter ':' --fields 1)

    # add grub theme
    if [[ "${install_grub_theme}" ]]; then
        local grub_dir="/boot/grub/themes/${install_grub_theme}"
        mkdir --parents "${grub_dir}"

        wget "https://github.com/AdisonCavani/distro-grub-themes/releases/download/v3.2/${install_grub_theme}.tar" --output-document "/tmp/${install_grub_theme}.tar"
        tar --extract --verbose --file "/tmp/${install_grub_theme}.tar" --directory "${grub_dir}"
        rm --force "/tmp/${install_grub_theme}.tar"

        cat "${config_dir}/grub/default.cfg" > "/etc/default/grub"
        echo "GRUB_THEME='/boot/grub/themes/${install_grub_theme}/theme.txt'" >> "/etc/default/grub"

        update-grub > /dev/null
    fi

    # add gtk theme
    if [[ "${install_gtk_theme}" ]]; then
        # fonts
        wget "https://www.fontsquirrel.com/fonts/download/noto-sans" --output-document "/tmp/noto-sans.zip"
        unzip "/tmp/noto-sans.zip" -d "/usr/share/fonts/truetype"
        rm --force "/tmp/noto-sans.zip"

        # icon theme
        git clone "https://github.com/vinceliuice/Colloid-icon-theme" "/tmp/colloid-icon-theme"
        (
            cd "/tmp/colloid-icon-theme"
            bash "/tmp/colloid-icon-theme/install.sh" --dest "/usr/share/icons" --scheme "nord"
        )
        rm --recursive --force "/tmp/colloid-icon-theme"

        # gtk theme
        apt install --yes \
            gnome-themes-extra \
            gtk2-engines-murrine

        git clone "https://github.com/vinceliuice/Colloid-gtk-theme" "/tmp/colloid-gtk-theme"
        (
            cd "/tmp/colloid-gtk-theme"
            bash "/tmp/colloid-gtk-theme/install.sh" --dest "/usr/share/themes" --tweaks normal --libadwaita
        )
        rm --recursive --force "/tmp/colloid-gtk-theme"

        # wallpaper
        wget "https://raw.githubusercontent.com/Impudicus/wallpaper/main/linux/3840x2160.Unix.jpg" --directory-prefix "/usr/share/wallpapers"
    fi

    # config network
    cat "${config_dir}/network/interfaces" > "/etc/network/interfaces"
    systemctl disable networking
    systemctl stop networking

    cat "${config_dir}/network/NetworkManager.conf" > "/etc/NetworkManager/NetworkManager.conf"
    systemctl enable NetworkManager
    systemctl start NetworkManager

    # config sudo
    echo "${default_user} ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/default-user-no-password"

    # user config    
    cat "${config_dir}/.bash_aliases" > "/home/${default_user}/.bash_aliases"
    cat "${config_dir}/.bashrc" > "/home/${default_user}/.bashrc"
    cat "${config_dir}/.profile" > "/home/${default_user}/.profile"
    if [[ "${install_gtk_theme}" ]]; then
        echo "export GTK_THEME='Colloid-${install_gtk_theme}'" >> "/home/${default_user}/.profile"
    fi

    # user config - root
    cat "${config_dir}/.bash_aliases" > "/root/.bash_aliases"
    cat "${config_dir}/.bashrc" > "/root/.bashrc"
}

runCleanup() {
    apt autoremove --yes > /dev/null
    apt clean > /dev/null
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            printf "${script_name}: \e[41m${log_text}\e[0m\n" >&2
            ;;
        okay)
            printf "${script_name}: \e[42m${log_text}\e[0m\n" >&1
            ;;
        info)
            printf "${script_name}: \e[44m${log_text}\e[0m\n" >&1
            ;;
        *)
            printf "${script_name}: ${log_text}\n" >&1
            ;;
    esac
}

printHelp() {
    printf "Usage: ${script_name} [OPTIONS]\n"
    printf "Options:\n"
    printf "  -a, --apps                                Install additional apps, like balena etcher, steam and vs-code.\n"
    printf "  -d, --drivers     amd|vmware-tools        Install additional drivers.\n"
    printf "  -g, --grub        debian|hp|lenovo        Add selected grub brand theme.\n"
    printf "  -h, --help                                Show this help message.\n"
    printf "  -r, --release     bookworm|stable         Use stable repositories [default value].\n"
    printf "                    trixie|unstable         Use backport repositories.\n"
    printf "  -t, --theme       light|dark              Add selected gtk scheme.\n"
    printf "\n"
}

main() {
    # pre-checks
    if [[ "${EUID}" -ne 0 ]]; then
        printLog "error" "Script has to be run with root user privileges."
        exit 1
    fi

    config_dir="${script_path}/config"
    if [[ ! -d "${config_dir}" ]]; then
        printLog "error" "Unable to find config folder in the specified directory."
        exit 1
    fi

    # variables
    apt_release=''
    install_apps=''
    install_driver=''
    install_grub_theme=''
    install_gtk_theme=''

    # parameters
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -a | --apps)
                install_apps='true'
                shift 1
                ;;
            -d | --drivers)
                if [[ ! "${2}" ]]; then
                    printLog "error" "Missing driver name, use --help for further information."
                    exit 1
                fi
                case "${2}" in
                    amd | vmware-tools)
                        install_driver="${2}"
                        ;;
                    *)
                        printLog "error" "Invalid driver name '${2}'."
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -g | --grub)
                if [[ ! "${2}" ]]; then
                    printLog "error" "Missing grub theme, use --help for further information."
                    exit 1
                fi
                case "${2}" in
                    debian | hp | lenovo)
                        install_grub_theme="${2}"
                        ;;
                    *)
                        printLog "error" "Invalid grub theme '${2}'."
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -r | --release)
                if [[ ! "${2}" ]]; then
                    printLog "error" "Missing release name, use --help for further information."
                    exit 1
                fi
                case "${2}" in
                    bookworm | stable)
                        apt_release="stable"
                        ;;
                    trixie | unstable)
                        apt_release="unstable"
                        ;;
                    *)
                        printLog "error" "Invalid release name '${2}'."
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -t | --theme)
                if [[ ! "${2}" ]]; then
                    printLog "error" "Missing gtk theme, use --help for further information."
                    exit 1
                fi
                case "${2}" in
                    dark)
                        install_gtk_theme="Dark"
                        ;;
                    light)
                        install_gtk_theme="Light"
                        ;;
                    *)
                        printLog "error" "Invalid gtk theme '${2}'."
                        exit 1
                        ;;
                esac
                shift 2
                ;;
            -h | --help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown option '${1}', use --help for further information."
                exit 1
                ;;
        esac
    done

    # run
    runInstall
    runConfig
    runCleanup

    printLog "okay" "Script executed successfully."
}

main "$@"

#!/usr/bin/env bash
# shellcheck disable=SC2154
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| Prasanth Rangan          |-/ /--|#
#|/ /---+--------------------------+/ /---|#

cat <<"EOF"

-------------------------------------------------
        .
       / \         _       _  _      ___  ___
      /^  \      _| |_    | || |_  _|   \| __|
     /  _  \    |_   _|   | __ | || | |) | _|
    /  | | ~\     |_|     |_||_|\_, |___/|___|
   /.-'   '-.\                  |__/

-------------------------------------------------

EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
scrDir="$(dirname "$(realpath "$0")")"
# shellcheck disable=SC1091
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

#------------------#
# evaluate options #
#------------------#
flg_Install=0
flg_Restore=0
flg_Service=0
flg_DryRun=0
flg_Shell=0
flg_Nvidia=1

while getopts idrstnh: RunStep; do
    case $RunStep in
    i) flg_Install=1 ;;
    d)
        flg_Install=1
        export use_default="--noconfirm"
        ;;
    r) flg_Restore=1 ;;
    s) flg_Service=1 ;;
    n)
        # shellcheck disable=SC2034
        export flg_Nvidia=0
        print_log -r "[nvidia] " -b "Ignored :: " "skipping Nvidia actions"
        ;;
    h)
        # shellcheck disable=SC2034
        export flg_Shell=0
        print_log -r "[shell] " -b "Reevaluate :: " "shell options"
        ;;
    t) flg_DryRun=1 ;;
    *)
        cat <<EOF
Usage: $0 [options]
            i : [i]nstall hyprland without configs
            d : install hyprland [d]efaults without configs --noconfirm
            r : [r]estore config files
            s : enable system [s]ervices
            n : ignore/[n]o [n]vidia actions
            h : reevaluate S[h]ell
            t : [t]est run without executing (-irst to dry run all)
EOF
        exit 1
        ;;
    esac
done

# Only export that are used outside this script
export flg_DryRun flg_Nvidia flg_Shell

if [ "${flg_DryRun}" -eq 1 ]; then
    print_log -n "[test-run] " -b "enabled :: " "Testing without executing"
elif [ $OPTIND -eq 1 ]; then
    flg_Install=1
    flg_Restore=1
    flg_Service=1
fi

#--------------------#
# pre-install script #
#--------------------#
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"
                _         _       _ _
 ___ ___ ___   |_|___ ___| |_ ___| | |
| . |  _| -_|  | |   |_ -|  _| .'| | |
|  _|_| |___|  |_|_|_|___|_| |__,|_|_|
|_|

EOF

    "${scrDir}/install_pre.sh"
fi

#------------#
# installing #
#------------#
if [ ${flg_Install} -eq 1 ]; then
    cat <<"EOF"

 _         _       _ _ _
|_|___ ___| |_ ___| | |_|___ ___
| |   |_ -|  _| .'| | | |   | . |
|_|_|_|___|_| |__,|_|_|_|_|_|_  |
                            |___|

EOF

    #----------------------#
    # prepare package list #
    #----------------------#
    shift $((OPTIND - 1))
    cust_pkg=$1
    cp "${scrDir}/custom_hypr.lst" "${scrDir}/install_pkg.lst"
    trap 'rm "${scrDir}/install_pkg.lst"' EXIT

    if [ -f "${cust_pkg}" ] && [ -n "${cust_pkg}" ]; then
        cat "${cust_pkg}" >>"${scrDir}/install_pkg.lst"
    fi

    #--------------------------------#
    # add nvidia drivers to the list #
    #--------------------------------#
    if nvidia_detect; then
        if [ ${flg_Nvidia} -eq 1 ]; then
            cat /usr/lib/modules/*/pkgbase | while read -r krnl; do
                echo "${krnl}-headers" >>"${scrDir}/install_pkg.lst"
            done
            nvidia_detect --drivers >>"${scrDir}/install_pkg.lst"
        else
            print_log -warn "Nvidia" " :: " "Nvidia GPU detected but ignored..."
        fi
    fi
    nvidia_detect --verbose

    #----------------#
    # get user prefs #
    #----------------#
    if ! chk_list "aurhlpr" "${aurList[@]}"; then
        print_log -c "AUR Helpers :: " + 30 "\n[1] " "yay" + 60 "\n[2] " "yay-bin" + 90 "\n[3] " "paru" + 120 "\n[4] " "paru-bin"
        prompt_timer 120 "Enter option number [default: yay] "

        case "${promptIn}" in
        1) export getAur="yay" ;;
        2) export getAur="yay-bin" ;;
        3) export getAur="paru" ;;
        4) export getAur="paru-bin" ;;
        *)
            print_log -warn "AUR" " :: " "Invalid option selected"
            exit 1
            ;;
        esac
    fi

    if ! chk_list "myShell" "${shlList[@]}"; then
        print_log -c "Shell :: " + 30 "\n[1] " "zsh" + 60 "\n[2] " "fish"
        prompt_timer 120 "Enter option number"

        case "${promptIn}" in
        1) export myShell="zsh" ;;
        2) export myShell="fish" ;;
        *)
            print_log -warn "Shell" " :: " "Invalid option selected"
            exit 1
            ;;
        esac
        echo "${myShell}" >>"${scrDir}/install_pkg.lst"
    fi

    #--------------------------------#
    # install packages from the list #
    #--------------------------------#
    [ ${flg_DryRun} -ne 1 ] || "${scrDir}/install_pkg.sh" "${scrDir}/install_pkg.lst"
fi

#---------------------------#
# restore my custom configs #
#---------------------------#
if [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"

             _           _
 ___ ___ ___| |_ ___ ___|_|___ ___
|  _| -_|_ -|  _| . |  _| |   | . |
|_| |___|___|_| |___|_| |_|_|_|_  |
                              |___|

EOF

    # if [ "${flg_DryRun}" -ne 1 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    #     hyprctl keyword misc:disable_autoreload 1 -q
    #     trap 'hyprctl reload -q && echo "[install] reload :: Hyprland"' EXIT
    # fi

    "${scrDir}/restore_fnt.sh"
    "${scrDir}/restore_cfg.sh"
    print_log -g "[THEME] " -warn "imports" "from List"
    while IFS='"' read -r _ themeName _ themeRepo; do
        themeNameQ+=("${themeName//\"/}")
        themeRepoQ+=("${themeRepo//\"/}")
        themePath="${confDir}/hyde/themes/${themeName}"
        [ -d "${themePath}" ] || mkdir -p "${themePath}"
        [ -f "${themePath}/.sort" ] || echo "${#themeNameQ[@]}" >"${themePath}/.sort"
        print_log -g "[THEME] " -stat "added" "${themeName}"
    done <"${scrDir}/themepatcher.lst"
    set +e
    [ "${flg_DryRun}" -eq 1 ] || parallel --bar --link "\"${scrDir}/themepatcher.sh\"" "{1}" "{2}" "{3}" "{4}" ::: "${themeNameQ[@]}" ::: "${themeRepoQ[@]}" ::: "--skipcaching" ::: "false"
    set -e
    print_log -g "[generate] " "cache ::" "Wallpapers..."
    [ "${flg_DryRun}" -eq 1 ] || "$HOME/.local/lib/hyde/swwwallcache.sh" -t ""
    if [ "${flg_DryRun}" -ne 1 ] && [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        print_log -g "[THEME] " -n " reload ::" "Current theme"
        "$HOME/.local/lib/hyde/themeswitch.sh" &>/dev/null
    fi
fi

#---------------------#
# post-install script #
#---------------------#
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat <<"EOF"

             _      _         _       _ _
 ___ ___ ___| |_   |_|___ ___| |_ ___| | |
| . | . |_ -|  _|  | |   |_ -|  _| .'| | |
|  _|___|___|_|    |_|_|_|___|_| |__,|_|_|
|_|

EOF

    "${scrDir}/install_pst.sh"
fi

#------------------------#
# enable system services #
#------------------------#
if [ ${flg_Service} -eq 1 ]; then
    cat <<"EOF"

                 _
 ___ ___ ___ _ _|_|___ ___ ___
|_ -| -_|  _| | | |  _| -_|_ -|
|___|___|_|  \_/|_|___|___|___|

EOF

    while read -r servChk; do

        if [[ $(systemctl list-units --all -t service --full --no-legend "${servChk}.service" | sed 's/^\s*//g' | cut -f1 -d' ') == "${servChk}.service" ]]; then
            print_log -y "[skip] " -b "active " "Service ${servChk}"
        else
            print_log -y "start" "Service ${servChk}"
            if $flg_DryRun -ne 1; then
                sudo systemctl enable "${servChk}.service"
                sudo systemctl start "${servChk}.service"
            fi
        fi

    done <"${scrDir}/system_ctl.lst"
fi

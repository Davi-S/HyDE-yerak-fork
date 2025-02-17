#!/usr/bin/env bash
# shellcheck disable=SC1091

#// hyde envs

export confDir="${XDG_CONFIG_HOME:-$HOME/.config}"
export hydeConfDir="${confDir}/hyde"
export cacheDir="$HOME/.cache/hyde"
export thmbDir="${cacheDir}/thumbs"
export dcolDir="${cacheDir}/dcols"
export iconsDir="${XDG_DATA_HOME}/icons"
export themesDir="${XDG_DATA_HOME}/themes"
export fontsDir="${XDG_DATA_HOME}/fonts"
export hashMech="sha1sum"

get_hashmap() {
    unset wallHash
    unset wallList
    unset skipStrays
    unset verboseMap

    validSources=()
    for wallSource in "$@"; do
        [ -z "${wallSource}" ] && continue
        case "${wallSource}" in
        --skipstrays) skipStrays=1 ;;
        --verbose) verboseMap=1 ;;
        *) validSources+=("${wallSource}") ;;
        esac
    done

    if [ ${#validSources[@]} -eq 0 ]; then
        echo "ERROR: No valid image sources provided"
        exit 1
    fi

    # 200ms reduction
    # hashMap=$(find "${validSources[@]}" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | xargs -0 "${hashMech}" | sort -k2)

    # if [ -z "${hashMap}" ]; then
    #     echo "WARNING: No images found in the provided sources:"
    #     for source in "${validSources[@]}"; do
    #         num_files=$(find "${source}" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) | wc -l)
    #         echo " x ${source} - ${num_files} files"
    #     done
    #     exit 1
    # fi

    while read -r hash image; do
        wallHash+=("${hash}")
        wallList+=("${image}")
    done <<<"$(find "${validSources[@]}" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -print0 | xargs -0 "${hashMech}" | sort -k2)"

    if [ -z "${#wallList[@]}" ] || [[ "${#wallList[@]}" -eq 0 ]]; then
        if [[ "${skipStrays}" -eq 1 ]]; then
            return 1
        else
            echo "ERROR: No image found in any source"
            exit 1
        fi
    fi

    if [[ "${verboseMap}" -eq 1 ]]; then
        echo "// Hash Map //"
        for indx in "${!wallHash[@]}"; do
            echo ":: \${wallHash[${indx}]}=\"${wallHash[indx]}\" :: \${wallList[${indx}]}=\"${wallList[indx]}\""
        done
    fi
}

# shellcheck disable=SC2120
get_themes() {
    unset thmSortS
    unset thmListS
    unset thmWallS
    unset thmSort
    unset thmList
    unset thmWall

    while read -r thmDir; do
        local realWallPath
        realWallPath="$(readlink "${thmDir}/wall.set")"
        if [ ! -e "${realWallPath}" ]; then
            get_hashmap "${thmDir}" --skipstrays || continue
            echo "fixing link :: ${thmDir}/wall.set"
            ln -fs "${wallList[0]}" "${thmDir}/wall.set"
        fi
        [ -f "${thmDir}/.sort" ] && thmSortS+=("$(head -1 "${thmDir}/.sort")") || thmSortS+=("0")
        thmWallS+=("${realWallPath}")
        thmListS+=("${thmDir##*/}") # Use this instead of basename
    done < <(find "${hydeConfDir}/themes" -mindepth 1 -maxdepth 1 -type d)

    while IFS='|' read -r sort theme wall; do
        thmSort+=("${sort}")
        thmList+=("${theme}")
        thmWall+=("${wall}")
    done < <(paste -d '|' <(printf "%s\n" "${thmSortS[@]}") <(printf "%s\n" "${thmListS[@]}") <(printf "%s\n" "${thmWallS[@]}") | sort -n -k 1 -k 2)
    #!  done < <(parallel --link echo "{1}\|{2}\|{3}" ::: "${thmSortS[@]}" ::: "${thmListS[@]}" ::: "${thmWallS[@]}" | sort -n -k 1 -k 2) # This is overkill and slow
    if [ "${1}" == "--verbose" ]; then
        echo "// Theme Control //"
        for indx in "${!thmList[@]}"; do
            echo -e ":: \${thmSort[${indx}]}=\"${thmSort[indx]}\" :: \${thmList[${indx}]}=\"${thmList[indx]}\" :: \${thmWall[${indx}]}=\"${thmWall[indx]}\""
        done
    fi
}

[ -f "${hydeConfDir}/hyderc" ] && source "${hydeConfDir}/hyderc"
[ -f "${HYDE_RUNTIME_DIR}/environment" ] && source "${HYDE_RUNTIME_DIR}/environment"

case "${enableWallDcol}" in
0 | 1 | 2 | 3) ;;
*) enableWallDcol=0 ;;
esac

if [ -z "${hydeTheme}" ] || [ ! -d "${hydeConfDir}/themes/${hydeTheme}" ]; then
    get_themes
    hydeTheme="${thmList[0]}"
fi

hydeThemeDir="${hydeConfDir}/themes/${hydeTheme}"
walbashDirs=(
    "${hydeConfDir}/wallbash"
    "${XDG_DATA_HOME}/hyde/wallbash"
    "/usr/local/share/hyde/wallbash"
    "/usr/share/hyde/wallbash"
)

export hydeTheme
export hydeThemeDir
export walbashDirs
export enableWallDcol

#// hypr vars

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    hypr_border="$(hyprctl -j getoption decoration:rounding | jq '.int')"
    hypr_width="$(hyprctl -j getoption general:border_size | jq '.int')"

    export hypr_border=${hypr_border:-0}
    export hypr_width=${hypr_width:-0}
fi

#// extra fns

pkg_installed() {
    local pkgIn=$1
    if pacman -Qi "${pkgIn}" &>/dev/null; then
        return 0
    elif pacman -Qi "flatpak" &>/dev/null && flatpak info "${pkgIn}" &>/dev/null; then
        return 0
    elif command -v "${pkgIn}" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

get_aurhlpr() {
    if pkg_installed yay; then
        aurhlpr="yay"
    elif pkg_installed paru; then
        # shellcheck disable=SC2034
        aurhlpr="paru"
    fi
}

set_conf() {
    local varName="${1}"
    local varData="${2}"
    touch "${hydeConfDir}/hyderc"

    if [ "$(grep -c "^${varName}=" "${hydeConfDir}/hyderc")" -eq 1 ]; then
        sed -i "/^${varName}=/c${varName}=\"${varData}\"" "${hydeConfDir}/hyderc"
    else
        echo "${varName}=\"${varData}\"" >>"${hydeConfDir}/hyderc"
    fi
}

set_hash() {
    local hashImage="${1}"
    "${hashMech}" "${hashImage}" | awk '{print $1}'
}

print_log() {
    # [ -t 1 ] && return 0 # Skip if not in the terminalp
    while (("$#")); do
        # [ "${colored}" == "true" ]
        case "$1" in
        -r | +r)
            echo -ne "\e[31m$2\e[0m"
            shift 2
            ;; # Red
        -g | +g)
            echo -ne "\e[32m$2\e[0m"
            shift 2
            ;; # Green
        -y | +y)
            echo -ne "\e[33m$2\e[0m"
            shift 2
            ;; # Yellow
        -b | +b)
            echo -ne "\e[34m$2\e[0m"
            shift 2
            ;; # Blue
        -m | +m)
            echo -ne "\e[35m$2\e[0m"
            shift 2
            ;; # Magenta
        -c | +c)
            echo -ne "\e[36m$2\e[0m"
            shift 2
            ;; # Cyan
        -wt | +w)
            echo -ne "\e[37m$2\e[0m"
            shift 2
            ;; # White
        -n | +n)
            echo -ne "\e[96m$2\e[0m"
            shift 2
            ;; # Neon
        -stat)
            echo -ne "\e[4;30;46m $2 \e[0m :: "
            shift 2
            ;; # status
        -crit)
            echo -ne "\e[30;41m $2 \e[0m :: "
            shift 2
            ;; # critical
        -warn)
            echo -ne "WARNING :: \e[30;43m $2 \e[0m :: "
            shift 2
            ;; # warning
        +)
            echo -ne "\e[38;5;$2m$3\e[0m"
            shift 3
            ;; # Set color manually
        -sec)
            echo -ne "\e[32m[$2] \e[0m"
            shift 2
            ;; # section use for logs
        -err)
            echo -ne "ERROR :: \e[4;31m$2 \e[0m"
            shift 2
            ;; #error
        *)
            echo -ne "$1"
            shift
            ;;
        esac
    done
    echo ""
}

# Yes this is so slow but it's the only way to ensure that parsing behaves correctly
get_hyprConf() {
    local hyVar="${1}"
    local file="${2:-"${hydeThemeDir}/hypr.theme"}"
    local gsVal
    gsVal="$(grep "^[[:space:]]*\$${hyVar}\s*=" "${file}" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "${gsVal}" ] && [[ "${gsVal}" != \$* ]] && echo "${gsVal}" && return 0
    declare -A gsMap=(
        [GTK_THEME]="gtk-theme"
        [ICON_THEME]="icon-theme"
        [COLOR_SCHEME]="color-scheme"
        [CURSOR_THEME]="cursor-theme"
        [CURSOR_SIZE]="cursor-size"
        [FONT]="font-name"
        [DOCUMENT_FONT]="document-font-name"
        [MONOSPACE_FONT]="monospace-font-name"
        [FONT_SIZE]="font-size"
        [DOCUMENT_FONT_SIZE]="document-font-size"
        [MONOSPACE_FONT_SIZE]="monospace-font-size"
        # [CODE_THEME]="Wallbash"
        # [SDDM_THEME]=""
    )

    # Try parse gsettings
    if [[ -n "${gsMap[$hyVar]}" ]]; then
        gsVal="$(awk -F"[\"']" '/^[[:space:]]*exec[[:space:]]*=[[:space:]]*gsettings[[:space:]]*set[[:space:]]*org.gnome.desktop.interface[[:space:]]*'"${gsMap[$hyVar]}"'[[:space:]]*/ {last=$2} END {print last}' "${file}")"
    fi

    if [ -z "${gsVal}" ] || [[ "${gsVal}" == \$* ]]; then
        case "${hyVar}" in
        "CODE_THEME") echo "Wallbash" ;;
        "SDDM_THEME") echo "" ;;
        *)
            grep "^[[:space:]]*\$default.${hyVar}\s*=" \
                "$XDG_DATA_HOME/hyde/hyprland.conf" \
                "/usr/local/share/hyde/hyprland.conf" \
                "/usr/share/hyde/hyprland.conf" 2>/dev/null |
                cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | head -n 1
            ;;
        esac
    else
        echo "${gsVal}"::
    fi

}

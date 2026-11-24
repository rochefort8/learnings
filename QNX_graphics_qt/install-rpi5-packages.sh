#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: install-rpi5-packages.sh [--offline] NEW_SDP_DIRECTORY

Read the SDP baseline from the first line of qnx800-rpi5-install.list.
Install the remaining package IDs and optional versions as add-ons.
Set QSC_OPTIONS_FILE to a private myQNX options file to skip the login prompt.
Set QSC_CLI to override the Software Center launcher.
Offline mode uses the existing Software Center cache.
USAGE
}

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    usage
    exit 0
fi

offline=false
if [[ ${1:-} == --offline ]]; then
    offline=true
    shift
fi

if [[ $# -ne 1 || -z $1 ]]; then
    usage >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
package_list="$script_dir/qnx800-rpi5-install.list"
qsc=${QSC_CLI:-"$HOME/qnx/qnxsoftwarecenter/qnxsoftwarecenter_clt"}
destination=$(realpath -m -- "$1")
if [[ -e $destination || -L $destination ]]; then
    printf 'Choose a new installation directory. Already exists: %s\n' "$destination" >&2
    exit 2
fi
if [[ ! -x $qsc || ! -s $package_list ]]; then
    printf 'Check the Software Center launcher and package list:\n%s\n%s\n' "$qsc" "$package_list" >&2
    exit 2
fi

mapfile -t packages < "$package_list"
for package in "${packages[@]}"; do
    if [[ ! $package =~ ^[[:alnum:]_][[:alnum:]_.-]*(/[[:alnum:]_.-]+)?$ ]]; then
        printf 'Invalid package entry in %s: %s\n' "$package_list" "$package" >&2
        exit 2
    fi
done

temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
exported="$temp_dir/installed.plist"

if "$offline"; then
    auth=(-offline)
else
    options_file=${QSC_OPTIONS_FILE:-}
    if [[ -z $options_file ]]; then
        options_file="$temp_dir/myqnx.options"
        IFS= read -r -p 'myQNX username: ' username </dev/tty
        IFS= read -r -s -p 'myQNX password: ' password </dev/tty
        printf '\n' >&2
        (umask 077; printf '%s\n' -myqnx.user "$username" -myqnx.password "$password" > "$options_file")
        unset username password
    fi
    options_file=$(realpath -e -- "$options_file")
    auth=("@$options_file")
    "$qsc" "${auth[@]}" -mirror
fi

"$qsc" "${auth[@]}" -destination "$destination" -setPolicy=conservative -installBaseline "${packages[0]}"
if (( ${#packages[@]} > 1 )); then
    addons=$(IFS=,; printf '%s' "${packages[*]:1}")
    "$qsc" "${auth[@]}" -destination "$destination" -installPackage "$addons"
fi

"$qsc" -offline -destination "$destination" -exportPatchSetText "$exported"
cut -d / -f 1 "$exported" > "$temp_dir/ids"
cut -d / -f 1,2 "$exported" > "$temp_dir/versions"
for package in "${packages[@]}"; do
    installed="$temp_dir/ids"
    if [[ $package == */* ]]; then
        installed="$temp_dir/versions"
    fi
    if ! grep -Fqx -- "$package" "$installed"; then
        printf 'Requested package missing from %s: %s\n' "$destination" "$package" >&2
        exit 1
    fi
done
printf 'Verified requested packages at %s\n' "$destination"

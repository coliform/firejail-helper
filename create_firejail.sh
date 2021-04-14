#!/bin/bash

function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}
start=${1:-"start"}
jumpto $start
start:

if [ "$EUID" -ne 0 ]; then
	printf "This script must be run as root:\n"
	printf "sudo ./$(basename -- ${0##*/})\n"
	exit
fi

if [[ ! -x "$(command -v firejail)" ]]; then
	printf "Firejail doesn't seem to be installed.\n"
	printf "Would you like to install it? [Y/n]: "
	read answer
	if [[ ! -z "$answer" && "$answer" == "Y" ]]; then
		apt install firejail firejail-profile
	else
		printf "Please re-run once you have the following packages installed:\n"
		printf "firejail, firejail-profiles\n"
		exit
	fi
fi


label_name:
printf "Program name (no whitespaces): "
read name
if [[ -z "$name" || "${name}" =~ [^a-zA-Z0-9\-] ]]; then
	printf "Invalid name. Only letters, numbers and hyphens are allowed\n"
	jumpto label_name
fi
name="$(echo -e "${name}" | tr -d '[:space:]')"

label_path:
printf "Full path to executable: "
read path_to_executable
if [[ -z "$path_to_executable" || ! -f "$path_to_executable" ]]; then
	printf "Invalid path specified\n"
	jumpto label_path
fi
path_to_executable_base=$(basename -- $path_to_executable)
path_to_container=$(dirname $path_to_executable)
container_name=$(basename -- $path_to_container)
new_container_path= /opt/$name/$container_name

label_move_containing:
printf "Type YES to move containing directory: "
read copy_container


sudo mkdir -p /opt/$name/home
sudo chown -R $USER /opt/$name
touch /etc/firejail/"$name".profile
if [[ ! -z "$copy_container" && "$copy_container" == "YES" ]]; then
	mv -r $path_to_container $new_container_path
else
	mkdir $new_container_path
	mv $path_to_executable $new_container_path
fi

touch /usr/bin/$name
echo "#!/usr/bin/bash" >> /usr/bin/$name
echo "firejail --profile=/etc/firejail/${name}.profile --private=/opt/${name}/home ${new_container_path}/${path_to_executable_base}" >> /usr/bin/$name
chmod +x /usr/bin/$name


printf "Done. You can run your program by running the following command:\n"
printf "$name\n"

#! /bin/bash
LAST_LOG="n/a"
DRYRUN=false
PACKAGES=(
	"i3"
	"spotify-client"
	"gimp"
	"mongodb-org"
	"cifs-utils"
	"steam"
	"mysql-server"
	"fish"
	"scrot"
	"automake"
	"libtool"
	"build-essential"
	"gdb"
	"python-software-properties"
	"software-properties-common"
	"python3-dev"
	"python3-pip"
	"sublime-text-installer"
	"man"
	"git"
	"nodejs"
	"npm"
	"golang")

APT_REPOS=(
	"ppa:webupd8team/sublime-text-3"
	"ppa:duh/golang")
GIT_REPOS=()
DIRS=(
	"~/projects"
	"~/go")
TASKS=(
	CreateDirs
	PrepSpotify
	AddAptRepos
	InstallPackages
	ConfigureGit
	ConfigureFish
	ConfigureI3
	UpdateApt
	)

declare -A ARGS

Abort() {
	exit 1
}

log() {
	time=`date +%H:%M:%S`
	LOG="[$time] $1"
	echo $LOG
	LAST_LOG=$LOG
}

FailOnError() {
	if ! $DRYRUN ; then
		if [ $1 ]; then
			log "Failed after $LAST_LOG"
			Abort
		fi;
	fi
}

AddAptRepos() {
	for repo in "${APT_REPOS[@]}"; do
		log "Installing "$repo
		if ! $DRYRUN ; then
			sudo add-apt-repository install -y $package
		fi
		FailOnError $?
	done

	log "Updating Apt"
	if ! $DRYRUN ; then
		sudo apt-get update
	fi
	FailOnError $?
}

CreateDirs() {
	log "mkdir -p ${DIRS[*]}"
	if ! $DRYRUN ; then
		mkdir -p "${DIRS[*]}"
	fi
}

InstallPackages() {
	for package in "${PACKAGES[@]}"; do
		log "Installing "$package
		if ! $DRYRUN ; then
			sudo add-apt-repository install -y $package
		fi
		FailOnError $?
	done
}

InstallNpmPackages() {
	for package in "${NPM_G_PACKAGES[@]}"; do
		log "Installing NPM package "$package
		if ! $DRYRUN ; then
			sudo npm install -g $package
		fi
		FailOnError $?
	done
}

PrepSpotify() {
	log "Preparing for Spotify install"
	if ! $DRYRUN ; then
		sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886
		FailOnError $?

		echo deb http://repository.spotify.com stable non-free | sudo tee /etc/apt/sources.list.d/spotify.list
		FailOnError $?
	fi
}

ConfigureGit() {
	if [ ${#ARGS[git_name]} -gt 0 ]; then
		log "Setting user name to ${ARGS[git_name]}"
		if ! $DRYRUN ; then
			git config --global user.name $name
			FailOnError $?
		fi
	else
		log "No git name provided"
	fi

	if [ ${#ARGS[git_email]} -gt 0 ]; then
		log "Setting email to ${ARGS[git_email]}"
		if ! $DRYRUN ; then
			git config --global user.email $email
			FailOnError $?
		fi
	else
		log "No git email provided"
	fi

	if [ ${#ARGS[git_push_method]} -gt 0 ]; then
		log "Setting push method to ${ARGS[git_push_method]}"
		if ! $DRYRUN ; then
			git config --global push.default $push_method
			FailOnError $?
		fi
	else
		log "No git push method provided, using 'simple' instead"
		if ! $DRYRUN ; then
			git config --global push.default simple
			FailOnError $?
		fi
	fi
}

ConfigureFish() {
	log "Changing shell"
	if ! $DRYRUN ; then
		sudo chsh -s /usr/bin/fish
		FailOnError $?
	fi

	log "Installing oh my fish"
	if ! $DRYRUN ; then
		curl -L http://get.oh-my.fish | fish
		FailOnError $?
	fi

	log "Installing thefuck"
	if ! $DRYRUN ; then
		sudo -H pip3 install thefuck
		FailOnError $?

		fish -c "omf install thefuck"
		FailOnError $?
	fi

	THEME="agnoster"

	if [ ${#ARGS[omf_theme]} -gt 0 ]; then
		THEME="${ARGS[omf_theme]}"
	fi

	log "Setting omf theme to $THEME"
	if ! $DRYRUN ; then
		fish -c "omf install $THEME"
		FailOnError $?
	fi
}

UpdateApt() {
	if [ ${#ARGS[upgrade]} -gt 0 ]; then
		log "Upgrading apt packages"
		if ! $DRYRUN ; then
			sudo apt-get -y upgrade
			FailOnError $?
		fi
	fi
}

ConfigureI3() {
	log "Moving i3status.conf to /etc"
	if ! $DRYRUN ; then
		sudo mv ~/.config/i3/i3status.conf /etc
		FailOnError $?
	fi
}

HelpLine() {
	printf "%20s | %20s | %s\n" "$1" "$2" "$3"
}

HelpText() {
	printf "%s --arg <value>\n" $0
	echo "------------------------------------------------------------"
	HelpLine "flag" "example" "description"
	echo "------------------------------------------------------------"
	HelpLine "--git-name" "Jon Snow" "Set git name"
	HelpLine "--git-email" "example@test.com" "Set git-email"
	HelpLine "--git-push-method" "simple" "Set Git push method"
	HelpLine "--omf-theme" "agnoster" "Set omf theme"
	HelpLine "--upgrade" "" "Upgrade apt packages after install"
	HelpLine "--dryrun" "" "Don't actually do anything"
	exit $1
}

Main() {
	while [ "$#" -gt 0 ]; do
		case "$1" in
			--git-name)
				ARGS[git_name]="$2";
				shift; shift;;
			--git-email)
				ARGS[git_email]="$2";
				shift; shift;;
			--git-push-method)
				ARGS[git_push_method]="$2";
				shift; shift;;
			--omf-theme)
				ARGS[omf_theme]="$2";
				shift; shift;;
			--upgrade)
				ARGS[apt_upgrade]=true
				shift;;
			--dryrun)
				DRYRUN=true
				shift;;
			-h|--help)
				HelpText 0
				shift;;
			*)
				log "Unknown argument: $1"
				HelpText 1
				shift;;
		esac
	done

	if ! $DRYRUN ; then
		if [[ $EUID -ne 0 ]]; then
			log "This script must be run as root"
			FailOnError 1
		fi
	fi

	for task in "${TASKS[@]}"; do
		log "===== Starting "$task" ====="
		$task
	done
}

Main $@

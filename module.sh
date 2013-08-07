#!/usr/bin/env bash
#
# Script to manage the lifecycle of this configuration module.
# Run it without arguments for further information.

MODULE=git

function install() {
    local file=.gitconfig
    link $CURRENTDIR/$file $HOME/$file  
}

############################################################## begin-template

CURRENTDIR=$(dirname $(readlink -e $0))
BACKUPLOG=$CURRENTDIR/.backup.log
OPT_INSTALL_SHORT='-i'
OPT_INSTALL_LONG='--install-configuration'
OPT_RESTORE_SHORT='-r'
OPT_RESTORE_LONG='--restore-backups'

function info() {
    echo -e "[info] $@"
}

function warn() {
    echo -e "\e[1;33m[warn]\e[0m $@"
}

function fail() {
    echo -e "\e[1;31m[fail]\e[0m $@ Aborting."
    exit 1
}

function headline() {
    echo -e ">>>>>> \e[1;37m$@\e[0m"
}

function requires() {
   command -v $1 &> /dev/null || {
     fail "The command ‘$1’ is required."
   }
}

function link() {
    requires date
    local target=$1
    local linkname=$2

    if [ -e $linkname ] && ! [ -L $linkname ]; then
        local timestamp=$(date +"%Y-%m-%dT%T")
        local backup_location="$linkname.backup-$timestamp"
        warn "Object at $linkname is not a symbolic link. Creating backup..."
        if [ -e $backup_location ]; then
            fail "Could not create backup."
        fi
        warn "mv -n  $(mv -vn $linkname $backup_location)"
        echo $backup_location >> $BACKUPLOG
    fi

    info "ln -sf $(ln -vsfT $target $linkname)"
}

function restoreEntry() {
   requires sed
   local backup_location=$1
   local original_location=$(echo $backup_location | sed 's/\.backup.*$//')

   info "Recorded backup location is $backup_location"
   if [ -e $backup_location ] && ! [ -L $backup_location ]; then
        if [ -L $original_location ]; then
            rm $original_location
        fi
        if [ -e $original_location ]; then
            fail "Could not move backup to $original_location"
        else
            info "mv -n $(mv -nv $backup_location $original_location)"
            local pattern=$(echo $backup_location | sed -r 's/(.*)(backup.*$)/\2/')
            sed -i "/$pattern/d" $BACKUPLOG
        fi
   else
       fail "Backup location does not exist."
   fi
}

function defaultRestoreProcedure() {
    if ! [ -e $BACKUPLOG ]; then
        touch $BACKUPLOG
    fi
    local logContainedLines=false
    while read -r e; do
       restoreEntry $e
       logContainedLines=true
    done < $BACKUPLOG
    if ! $logContainedLines; then
       info "Log file is empty. There are no backups to restore."
    fi
}

function initSubmodules() {
    info "Initialize submodules"
    cd $CURRENTDIR
    requires git
    git submodule update --init
}

function modifySubmodulesPushUrl() {
info "Modify push-url of all submodules from github.com (Use SSH instead of HTTPS)"
    cd $CURRENTDIR
    requires git
    requires sed
    git submodule foreach '
        pattern="^.*https:\/\/(github.com)\/(.*\.git).*"
        orgURL=$(git remote -v show | grep origin | grep push)
        newURL=$(echo $orgURL | sed -r "/$pattern/{s/$pattern/git@\1:\2/;q0}; /$pattern/!{q1}")
        if [ "$?" -eq 0 ]; then
            command="git remote set-url --push origin $newURL"
            echo "$command"
            $($command)
        else
            echo "Nothing to do"
        fi
    '
}

function setupSubmodules() {
    initSubmodules
    modifySubmodulesPushUrl
}

function printHelp() {
    local indentParameter='  '
    local indent='      '
    echo -e "\nControls the lifecycle of this module\n"
    echo -e "SYNOPSIS: $(basename $0) [OPTION]\n"
    echo -e "$indentParameter $OPT_INSTALL_SHORT, $OPT_INSTALL_LONG\n"
    echo -e "$indent Installs the configuration settings contained in this module"
    echo -e "$indent by creating symbolic links in the required locations. This"
    echo -e "$indent operation won't overwrite any existing configuration files." 
    echo -e "$indent It will automatically create backups if there are any con-"
    echo -e "$indent flicting regular files or folders."
    echo ""
    echo -e "$indentParameter $OPT_RESTORE_SHORT, $OPT_RESTORE_LONG\n"
    echo -e "$indent Restores backups which where made during a previous install"
    echo -e "$indent operation."
    echo ""
}

if [ -n "$MODULE" ]; then
    HEADLINE_PREFIX="$(echo $MODULE | tr [:lower:] [:upper:]) -"
else
    fail "Module name not defined."
fi

if [ "$1" = $OPT_RESTORE_SHORT ] || [ "$1" = $OPT_RESTORE_LONG ]; then
    headline "$HEADLINE_PREFIX Restore backups"
    if declare -F restore &> /dev/null; then
        restore
    else
        defaultRestoreProcedure
    fi
elif [ "$1" = $OPT_INSTALL_SHORT ] || [ "$1" = $OPT_INSTALL_LONG ]; then
    headline "$HEADLINE_PREFIX Install configuration"
    if declare -F install &> /dev/null; then
        install
    else
        fail "Install function not defined."
    fi
else
    printHelp
fi

exit 0

############################################################## end-template

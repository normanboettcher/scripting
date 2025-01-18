#!/bin/bash
#
#The following script is designed to automate the process of a GitHub push operation,
#including highly customizable steps to ensure quality checks before pushing your code to remote repository.

ENABLE_PMD="false"
ENABLE_PUSH="false"
VERSION="1.0.1"

function is_git_on_path() {
    command -v git >/dev/null 2>&1
}

function is_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

function is_mvn_on_path() {
    command -v mvn >/dev/null 2>&1
}

function pmd_plugin_found() {
    mvn help:effective-pom | grep maven-pmd-plugin >/dev/null 2>&1
}

function print_help() {
    cat << EOF
Verwendung: $(basename "$0") [Optionen]

Beschreibung:
    Dieses Skript führt [Kurze Beschreibung der Funktion des Skripts] aus.

Optionen:
    -h, --help              Prints help for usage of parameters and script 
    -v, --version           Prints version number of the script.
    -e, --enable            Responsible for pushing to remote repository. 
                            True, if flag is provided to script
    -p, --pmd               If you pass the flag to the script, 
                            you enable the pmd check for your Java/Maven project 

Examples:
    $(basename "$0") --enable 
    $(basename "$0") --enable --pmd
    $(basename "$0") -ep

EOF
}

function check_flags() {
    #Parse options, the script supports short and long flags
    local OPTS=$(getopt -o "ehpv" -l "enable,help,pmd, version" -- "$@")
    if [ $? != 0 ]; then
        echo "Failed to parse options."
        exit 1
    fi

    eval set -- "$OPTS" #Set positional parameter

    while true; do
        case "$1" in
        -e | --enable)
            ENABLE_PUSH="true"
            shift
            ;;
        -p | --pmd)
            ENABLE_PMD="true"
            shift
            ;;
        -h | --help)
            print_help
            exit 0
            ;;
        -v | --version)
            echo "You are using github_push.sh with version: $VERSION"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown Option: $1"
            exit 1
            ;;
        esac
    done

}

#Check, if current directory is git repository and if git command is found on path
##If not successfull exit 1
if ! is_git_on_path; then
    echo "It looks like your git installation is not available on your PATH"
    echo "Please configure git first"
    exit 1
fi

if ! is_git_repo; then
    echo "Your current folder $(pwd) is not part of a valid git repository"
    echo "Please clone or create a git repository first"
    exit 1
fi

#Check flags
##--enabled, -e (is your commit supposed to be pushed to remote repository)
##--pmd, -p (Would you like to inspect your code quality with maven pmd plugin)
##--help, -h (Print help for possible flags)
check_flags "$@"

#Check, if mvn command is on path
##If not successfull exit 1
if [ ! is_mvn_on_path ]; then
    echo "Cannot find mvn commmand on path"
    echo "Please consider to provide a valid maven installation on your path"
    exit 1
fi

#Check if pmd plugin exists
##If not successfull exit 1
if [ $ENABLE_PMD = "true" ]; then
    if [ ! pmd_plugin_found ]; then
        echo "You want to check your pmd before your push, but could not found pmd plugin"
        exit 1
    fi
    PMD_SUCCESS=$(mvn pmd:check)
    if [[ ! $PMD_SUCCESS -eq 0 ]]; then
        echo "PMD-Check failed. Please fix your findings before pushing to remote repository."
        exit 1
    fi
fi

#Print current git status
echo "Please check your current status you want to push:"
git status

#Perform git add .
git add .
#Extract current Branch Name
#If Branch Name is part of Jira-Issue
##Then save branch name in variable
CURRENT_BRANCH=$(git branch --show-current)

JIRA=$(grep -oE '[A-Z]+-[0-9]+' <<<"$CURRENT_BRANCH")
#Ask for Commit Message
echo "Please provide your commit message (if jira-issue found, the corresponding issue will be used as prefix):"
read commit_message
#Perform git commit -m with given message (and maybe Jira-Issue)
git commit -m "$commit_message"

#Check flags
#If Push enabled (--enable=false, default)
if [ $ENABLE_PUSH = "true" ]; then
    git push origin $CURRENT_BRANCH
    if [[ $? -eq 0 ]]; then
        echo "Pushed $CURRENT_BRANCH successfully"
        exit 0
    else
        echo "Push to origin/$CURRENT_BRANCH failed"
        exit 1
    fi
fi

#Print Success-Message
exit 0

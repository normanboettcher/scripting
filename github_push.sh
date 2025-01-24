#!/bin/bash
#
#The following script is designed to automate the process of a GitHub push operation,
#including highly customizable steps to ensure quality checks before pushing your code to remote repository.

set -euo pipefail
trap 'handle_error "$CURRENT_STEP"' ERR

ENABLE_PMD="false"
ENABLE_PUSH="false"
VERSION="1.1.0"
CURRENT_STEP=""

function handle_error() {
    echo "[ERROR] $(basename "$0"): An error occured in Step: $1"
    exit 1 
}

function is_git_on_path() {
    CURRENT_STEP="Check if Git is on your PATH"
    if ! command -v git >/dev/null 2>&1; then
        echo "Git is not available on your PATH"
        exit 1
    fi
}

function is_git_repo() {
    CURRENT_STEP="Check if current directory is a valid git repository"
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Current directory $(pwd) is not a valid git repository"
        exit 1
    fi
}

function is_mvn_on_path() {
    CURRENT_STEP="Check if Maven is found on PATH"
    if ! command -v mvn >/dev/null 2>&1; then
        echo "Maven is not found on your PATH"
        exit 1
    fi
}

function pmd_plugin_found() {
    CURRENT_STEP="Check if Maven PMD-Plugin is available"
    if ! mvn help:effective-pom | grep maven-pmd-plugin >/dev/null 2>&1; then
        echo "You want to make a PMD-Check using Maven. But no PMD-Plugin was found."
        exit 1
    fi
}

function print_help() {
    cat << EOF
Usage: $(basename "$0") 

Description:
    This script provides basic operations to perform your git add, commit and push activities.
    Additional steps such as mvn pmd checks are also available.
    You can customize the script with whatever you would like to add.

Options:
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
    CURRENT_STEP="Check given flags"
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

is_git_on_path

is_git_repo

#Check flags
##--enabled, -e (is your commit supposed to be pushed to remote repository)
##--pmd, -p (Would you like to inspect your code quality with maven pmd plugin)
##--help, -h (Print help for possible flags)
check_flags "$@"

#Check, if mvn command is on path
##If not successfull exit 1
is_mvn_on_path
#Check if pmd plugin exists
##If not successfull exit 1
if [ "$ENABLE_PMD" = "true" ]; then
    #If not found, programm will exit 
    pmd_plugin_found
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOG_FILE="pmd_log_$TIMESTAMP.txt"
    mvn pmd:check > "$LOG_FILE" 2>&1
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] PMD-Check failed. Please fix your findings before pushing to remote repository."
        echo "Look at $LOG_FILE for more details."
        exit 1
    fi
fi

#Print current git status
echo "Please check your current status you want to push:"
git status

#Perform git add .
CURRENT_STEP="git add ."
git add .
#Extract current Branch Name
#If Branch Name is part of Jira-Issue
##Then save branch name in variable
CURRENT_STEP="Extract current branch name"
CURRENT_BRANCH=$(git branch --show-current)

if [[ -z "$CURRENT_BRANCH" ]]; then
    echo "Failed to determine the current branch. Please check your git repository."
    exit 1
fi

#Ask for Commit Message
CURRENT_STEP="Provide commit message"
echo "Please provide your commit message (if jira-issue found, the corresponding issue will be used as prefix):"
read commit_message
while [[ -z "$commit_message" ]]; do
    echo "Commit message cannot be empty. Pleasy try again:"
    read commit_message
done

if [[ "$commit_message" =~ '[^a-zA-Z0-9[:space:]_\-.,;:?!()]' ]]; then
    echo "Your commit message must have a valid format."
    echo "Please use letters, numbers and only the following marks: [.,;:?!-_]"
    exit 1
fi

commit_message=$(printf "%q" "$commit_message")
CURRENT_STEP="Check if current branch name has corresponding Jira"
JIRA=$(grep -oE '[A-Z]+-[0-9]+' <<<"$CURRENT_BRANCH" || echo "")
#Perform git commit -m with given message (and maybe Jira-Issue)
if [[ -n "$JIRA" ]]; then
    commit_message="$JIRA $commit_message"
fi

CURRENT_STEP="Perform git commit"
git commit -m "$commit_message"
echo "Your commit was successfull"
#Check flags
#If Push enabled (--enable=false, default)
if [ "$ENABLE_PUSH" = "true" ]; then
    CURRENT_STEP="Perform git push to origin"
    git push origin "$CURRENT_BRANCH"
    if [[ $? -eq 0 ]]; then
        echo "Pushed $CURRENT_BRANCH successfully"
        exit 0
    else
        echo "[ERROR] $(basename "$0"): Push failed. Check for conflicts or authentication issues."
        exit 1
    fi
fi

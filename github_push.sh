#!/bin/bash

#Check, if current directory is git repository and if git command is found on path
##If not successfull exit 1

#Check flags
##--enabled, -e (is your commit supposed to be pushed to remote repository)
##--pmd, -p (Would you like to inspect your code quality with maven pmd plugin)
##--help, -h (Print help for possible flags)

#Check, if mvn command is on path
##If not successfull exit 1

#Check if pmd plugin exists
##If not successfull exit 1

#Make PMD Check
##If not successfull exit 1

#Print current git status

#Perform git add .  

#Extract current Branch Name
#If Branch Name is part of Jira-Issue
##Then save branch name in variable

#Ask for Commit Message

#Perform git commit -m with given message (and maybe Jira-Issue)

#Check flags

#If Push enabled (--enable=true, default)
##Perform git push

#Print Success-Message
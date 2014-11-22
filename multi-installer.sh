#!/bin/bash

#  multi-installer.sh
#  
#
#  Weaved, Inc. Copyright 2014. All rights reserved.
#

##### Settings #####
VERSION=v1.2.0
AUTHOR="Mike Young"
MODIFIED="November 16, 2014"
DAEMON=weavedConnectd
WEAVED_DIR=/etc/weaved
BIN_DIR=/usr/bin
NOTIFIER=notify.sh
INIT_DIR=/etc/init.d
PID_DIR=/var/run
filename=$(basename $0)
loginURL=https://api.weaved.com/api/user/login
unregdevicelistURL=https://api.weaved.com/api/device/list/unregistered
preregdeviceURL=https://api.weaved.com/v6/api/device/create
regdeviceURL=https://api.weaved.com/api/device/register
regdeviceURL2=http://api.weaved.com/v6/api/device/register
##### End Settings #####

displayVersion()
{
    printf "You are running installer script Version: $VERSION \n"
    printf "last modified on $MODIFIED. \n\n"
}

##### Platform detection #####
platformDetection()
{
    machineType=$(uname -m)
    osName=$(uname -s)
    if [ "$machineType" = "armv6l" ]; then
        PLATFORM=pi
        SYSLOG=/var/log/syslog
        elif [ "$machineType" = "armv7l" ]; then
            PLATFORM=beagle
            SYSLOG=/var/log/syslog
        elif [ "$machineType" = "x86_64" ] && [ "$osName" = "Linux" ]; then
            PLATFORM=linux
            if [ ! -f "/var/log/syslog" ]; then
                SYSLOG=/var/log/messages
            else
                SYSLOG=/var/log/syslog
            fi
        elif [ "$machineType" = "x86_64" ] && [ "$osName" = "Darwin" ]; then
            PLATFORM=macosx
            SYSLOG=/var/log/system.log
    else
        printf "Sorry, you are running this installer on an unsupported platform. But if you go to \n"
        printf "http://forum.weaved.com we'll be happy to help you get your platform up and running. \n\n"
        printf "Thanks!!! \n"
        exit
    fi

    printf "Detected platform type: $PLATFORM \n"
    printf "Using $SYSLOG for your log file \n"
}
##### End Syslog type #####

##### Protocol selection #####
protocolSelection()
{
    if [ "$PLATFORM" = "pi" ]; then
        printf "*********** Protocol Selection Menu ***********\n"
        printf "*                                             *\n"
        printf "*    1) WebIOPi on default 8000               *\n"
        printf "*    2) WebSSH on default port 3066           *\n"
        printf "*    3) HTTP on default port 80               *\n"
        printf "*    4) SSH on default port 22                *\n"
        printf "*    5) Custom setting                        *\n"
        printf "*                                             *\n"
        printf "***********************************************\n\n"
        printf "Please input your selection from 1-5: \n"
        read input
    fi

}
##### End Protocol selection #####


##### Check for Bash #####
bashCheck()
{
    if [ "$BASH_VERSION" = '' ]; then
        clear
        printf "You executed this script with dash vs bash! \n\n"
        printf "Unfortunately, not all shells are the same. \n\n"
        printf "Please execute \"chmod +x $filename\" and then \n"
        printf "execute \"./$filename\".  \n\n"
        printf "Thank you! \n"
        exit
    else
        #clear
        echo "Now launching the Weaved connectd daemon installer..."
    fi
    #clear
}
##### End Bash Check #####

######### Ask Function #########
ask()
{
    while true; do
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
            fi
    # Ask the question
    read -p "$1 [$prompt] " REPLY
    # Default?
    if [ -z "$REPLY" ]; then
        REPLY=$default
    fi
    # Check if the reply is valid
    case "$REPLY" in
    Y*|y*) return 0 ;;
    N*|n*) return 1 ;;
    esac
    done
}
######### End Ask Function #########

#########  Non Numeric Values #########
numericCheck()
{
    test -z "$input" -o -n "`echo $input | tr -d '[0-9]'`" && echo NaN
}
#########  End Non Numeric Values #########

#########  Check prior installs #########
checkForPriorInstalls()
{
    if [ -e "/usr/bin/$DAEMON" ]; then
        clear
        printf "It looks as if there's a previous version of WeaveConnectd service installed. \n\n"
        if ask "Would you like to uninstall the prior installation before proceeding? "; then
            printf "\nUninstalling prior installation of Weaved's Connectd service... \n"
            if [ -e $INIT_DIR/$WEAVED_PORT ]; then
                sudo $INIT_DIR/$WEAVED_PORT stop
                sudo killall weavedConnectd
            fi

            if [ -d $WEAVED_DIR ]; then
                sudo rm -rf $WEAVED_DIR
                printf "$WEAVED_DIR now deleted \n"
            fi

            if [ -e $BIN_DIR/$DAEMON ]; then
                sudo rm -r $BIN_DIR/$DAEMON
                printf "$BIN_DIR/$DAEMON now deleted \n"
            fi

            if [ -e $BIN_DIR/$NOTIFIER ]; then
                sudo rm -r $BIN_DIR/$NOTIFIER
                printf "$BIN_DIR/$NOTIFIER now deleted \n"
            fi

            if [ -e $INIT_DIR/$WEAVED_PORT ]; then
                sudo rm $INIT_DIR/$WEAVED_PORT
                printf "$INIT_DIR/$WEAVED_PORT now deleted \n"
            fi

            if [ -e $INIT_DIR/$WEAVED_PORT ]; then
                sudo rm $PID_DIR/$WEAVED_PORT.pid
                printf "$PID_DIR/$WEAVED_PORT.pid now deleted \n"
            fi

            start="2 3 4 5"
            for i in $start; do
              sudo rm -f /etc/rc$i.d/S20$WEAVED_PORT
            done
            stop="0 1 6"
            for i in $stop; do
                if [ -e /etc/rc$i.d/K01$WEAVED_PORT ]; then
                    sudo rm -f /etc/rc$i.d/K01$WEAVED_PORT
                fi
            done
            if [ -e $BIN_DIR/send_notification.sh ]; then
                sudo rm $BIN_DIR/send_notification.sh
                printf "$BIN_DIR/send_notification.sh now deleted \n\n"
                printf "Prior installation now removed. Now proceeding with new installation... \n"
            fi
        else
            printf "\nYou've chosen not to remove your old installation files.  \n"
            printf "The following files will be either created or overwritten: \n\n"
            printf "$BIN_DIR/$DAEMON \n"
            printf "$WEAVED_DIR/services/$WEAVED_PORT.conf \n"
            printf "$INIT_DIR/$WEAVED_PORT \n"
            printf "$BIN_DIR/$NOTIFIER \n"
            printf "$PID_DIR/$WEAVED_PORT.pid \n\n"
        fi
    fi
}
#########  End Check prior installs #########

######### Begin Portal Login #########
userLogin () #Portal login function
{
    printf "Please enter your Weaved Portal Username (email address): \n"
    read username
    printf "\nNow, please enter your password: \n"
    read  -s password
    resp=$(curl -s -S -X GET -H "content-type:application/json" -H "apikey:WeavedDeveloperToolsWy98ayxR" "$loginURL/$username/$password")
    token=$(echo "$resp" | awk -F ":" '{print $3}' | awk -F "," '{print $1}' | sed -e 's/^"//'  -e 's/"$//')
    loginFailed=$(echo "$resp" | grep "login failed" | sed 's/"//g')
    login404=$(echo "$resp" | grep 404 | sed 's/"//g')
}
######### End Portal Login #########

######### Test Login #########
testLogin()
{
    while [[ "$loginFailed" != "" || "$login404" != "" ]]; do
        clear
        printf "You have entered either an incorrect username or password. Please try again. \n\n"
        userLogin
    done
}
######### End Test Login #########

######### Install Enablement #########
installEnablement()
{
    if [ ! -d "WEAVED_DIR" ]; then
       sudo mkdir -p $WEAVED_DIR/services
    fi

    cat ./enablements/$PROTOCOL.$PLATFORM ./$WEAVED_PORT.conf
}
######### End Install Enablement #########

######### Install Notifier #########
installNotifier()
{
    sudo chmod +x ./scripts/$NOTIFIER
    if [ ! -f $BIN_DIR/$NOTIFIER ]; then
        sudo cp ./scripts/$NOTIFIER $BIN_DIR
        printf "Copied $NOTIFIER to $BIN_DIR \n"
    fi
}
######### End Install Notifier #########

######### Install Send Notification #########
installSendNotification()
{
    sudo chmod +x ./scripts/send_notification.sh
    if [ ! -f $BIN_DIR/send_notification.sh ]; then
        sudo cp ./scripts/send_notification.sh $BIN_DIR
        printf "Copied send_notification.sh to $BIN_DIR \n"
    fi
}
######### End Install Send Notification #########

######### Service Install #########
installWeavedConnectd()
{
    if [ ! -f $BIN_DIR/$DAEMON ]; then
        sudo chmod +x ./bin/$DAEMON.$PLATFORM
        sudo cp ./bin/$DAEMON.$PLATFORM $BIN_DIR/$DAEMON
        printf "Copied $DAEMON to $BIN_DIR \n"
    fi
}
######### End Service Install #########

######### Install Start/Stop Sripts #########
installStartStop()
{
    sudo cp ./scripts/init.sh $INIT_DIR/$WEAVED_PORT
    sudo chmod +x $INIT_DIR/$WEAVED_PORT
    # Add startup levels
    sudo update-rc.d $WEAVED_PORT defaults
    # Startup the connectd daemon
    printf "\n\n"
    printf "*** Installation of weavedConnectd daemon has completed \n"
    printf "*** and we are now starting the service. Please be sure to \n"
    printf "*** register your device. \n\n"
    printf "Now starting the weavedConnectd daemon..."
    printf "\n\n"
#    sudo $INIT_DIR/$WEAVED_PORT start
    printf "\n\n"
}
######### End Start/Stop Sripts #########

######### Check Running Service #########
checkDaemon()
{
    sleep 10
    checkMessages=$(sudo tail $SYSLOG | grep "Server Connection changed to state 5" | wc -l)
    if [ "$checkMessages" = "1" ]; then
        clear
        printf "Congratulations! \n\n"
        printf "You've successfully installed Weaved services for $WEAVED_PORT. \n"
    else
        clear
        printf "Something is wrong and weavedConnectd doesn't appear to be running. \n"
        printf "We're going to exit now... \n"
        exit
    fi
}
######### End Check Running Service #########

######### Fetch UID #########
fetchUID()
{
    # Run weavedConnectd for 10 seconds to fetch UID
    printf "\n\n**** We will briefly run the Weaved service for 10 seconds to obtain a UID **** \n\n"
    ( cmdpid=$DAEMON; (sleep 10; killall $cmdpid) & $BIN_DIR/$DAEMON -f ./$WEAVED_PORT.conf )
}
######### End Fetch UID #########

######### Check for UID #########
checkUID()
{
    checkforUID=$(tail $WEAVED_PORT.conf | grep UID | wc -l)
    if [ "$checkforUID" = 2 ]; then
        sudo cp ./$WEAVED_PORT.conf /$WEAVED_DIR/services/
        uid=$(tail $WEAVED_DIR/services/$WEAVED_PORT.conf | grep UID | awk -F "UID" '{print $2}' | xargs echo -n)
        printf "\n\nYour device UID has been successfully provisioned as: $uid. \n\n"
    else
        retryFetchUID
    fi
}
######### Check for UID #########

######### Retry Fetch UID ##########
retryFetchUID()
{
    for run in {1..5}
    do
        fetchUID
        checkforUID=$(tail $WEAVED_PORT.conf | grep UID | wc -l)
        if [ "$checkforUID" = 2 ]; then
            sudo cp ./$WEAVED_PORT.conf /$WEAVED_DIR/services/
            uid=$(tail $WEAVED_DIR/services/$WEAVED_PORT.conf | grep UID | awk -F "UID" '{print $2}' | xargs echo -n)
            printf "\n\nYour device UID has been successfully provisioned as: $uid. \n\n"
            break
        fi
    done
    checkforUID=$(tail $WEAVED_PORT.conf | grep UID | wc -l)
    if [ "$checkforUID" != 2 ]; then
        printf "We have unsuccessfully retried to obtain a UID. Please contact Weaved Support at http://forum.weaved.com for more support.\n\n"
    fi
}
######### Retry Fetch UID ##########

######### Pre-register Device #########
preregisterUID()
{
    preregUID=$(curl -s $preregdeviceURL -X 'POST' -d "{\"deviceaddress\":\"$uid\"}" -H “Content-Type:application/json” -H "apikey:WeavedDeveloperToolsWy98ayxR" -H "token:$token")
    test1=$(echo $preregUID | grep "true" | wc -l)
    test2=$(echo $preregUID | grep -E "missing api token|api token missing" | wc -l)
    test3=$(echo $preregUID | grep "false" | wc -l)
    if [ "$test1" = 1 ]; then
        printf "Pre-registration of UID: $uid successful. \n\n"
    elif [ "$test2" = 1 ]; then
        printf "You are missing a valid session token and must be logged back in. \n"
        userLogin
        preregisterUID
    elif [ "$test3" = 1 ]; then
        printf "Sorry, but for some reason, the pre-registration of UID: $uid is failing. Please contact Weaved Support at http://forum.weaved.com.\n\n"
        exit
    fi
}
######### End Pre-register Device #########

######### Pre-register Device #########
getSecret()
{
    secretCall=$(curl -s $regdeviceURL2 -X 'POST' -d "{\"deviceaddress\":\"$uid\", \"devicealias\":\"$alias\", \"skipsecret\":\"true\"}" -H “Content-Type:application/json” -H "apikey:WeavedDeveloperToolsWy98ayxR" -H "token:$token")
    test1=$(echo $secretCall | grep "true" | wc -l)
    test2=$(echo $secretCall | grep -E "missing api token|api token missing" | wc -l)
    test3=$(echo $secretCall | grep "false" | wc -l)
    if [ "$test1" = 1 ]; then
        secret=$(echo $secretCall | awk -F "," '{print $2}' | awk -F "\"" '{print $4}')
        echo "# password - erase this line to unregister the device" >> ./$WEAVED_PORT.conf
        echo $secret >> ./$WEAVED_PORT.conf
        sudo cp ./$WEAVED_PORT.conf $WEAVED_DIR/services/$WEAVED_PORT.conf
        regMsg
    elif [ "$test2" = 1 ]; then
        printf "You are missing a valid session token and must be logged back in. \n"
        userLogin
        getSecret
    elif [ "$test3" = 1 ]; then
        printf "Sorry, but we are having trouble provisioning your alias, so we will use $uid as your device name, instead. \n\n"
        exit
    fi
}
######### End Pre-register Device #########
regMsg()
{
    clear
    printf "********************************************************************************* \n"
    printf "CONGRATULATIONS! You are now registered with Weaved. \n"
    printf "Your registration information is as follows: \n\n"
    printf "Device alias: \n"
    printf "$alias \n\n"
#    printf "Device UID: \n"
#    printf "$uid \n\n"
#    printf "Device secret: \n"
#    printf "$secret \n\n"
#    printf "License File Location: \n"
#    printf "$WEAVED_DIR/services/$WEAVED_PORT.conf \n\n"
    printf "If you delete the License File, you will have to re-run the installation process. \n"
    printf "********************************************************************************* \n\n"
}

######### Register Device #########
registerDevice()
{
    clear
    printf "We will now register your device with the Weaved backend services. \n"
    printf "Please provide an alias for your device: \n"
    read alias
    if [ "$alias" != "" ]; then
        printf "Your device will be called $alias. You can rename it later in the Weaved Portal. \n\n"
    else
        alias=$uid
        printf "We will use $uid as your device alias. \n\n"
    fi
}
######### End Register Device #########

######### Install Test Registration #########
testRegistration()
{
    while [ "$regFail" = "1" ]; do
        clear
        printf "********************************************************************************* \n"
        printf "Registration attempt has failed. Looks like you may be using a previously \n"
        printf "assigned Alias. \n\n"
        printf "We will now try again. Please wait till prompted... \n"
        printf "********************************************************************************* \n\n"
        registerDevice
    done
    if [ "$regTrue" = "1" ] && [ "$regCheck" = "2" ]; then
        clear
        printf "********************************************************************************* \n"
        printf "GREAT NEWS!!! \n\n"
        printf "Your device is now fully registered. Please install the Weaved Connect App for \n"
        printf "iOS to complete your Weaved experience. \n"
        printf "********************************************************************************* \n\n"
    else
        clear
        printf "********************************************************************************* \n"
        printf "The registration portal returned a successful response, but a password has not been \n"
        printf "assigned to your $WEAVED_PORT.conf file. Please visit http://forum.weaved.com or \n"
        printf "send an email to forum@weaved.com. We will respond to you as quickly as possible to \n"
        printf "help get you up and running. \n\n"
        printf "Sorry for this inconvenience!\n"
        printf "********************************************************************************* \n\n"
    fi
}
######### End Install Test Registration #########

######### Main Program #########
main()
{
    clear
    displayVersion
    bashCheck
    platformDetection
    protocolSelection
    checkForPriorInstalls
    userLogin
    testLogin
    installEnablement
    installNotifier
    installSendNotification
    installWeavedConnectd
    installStartStop
    fetchUID
    checkUID
#    checkDaemon
#    registerDevice
#    testRegistration
    exit
}
######### End Main Program #########
main
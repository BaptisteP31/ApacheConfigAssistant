#!/bin/bash

VH_config_deploy() {

    if [[ "$(ls -l | grep ".*\.conf$" | wc -l)" == "0" ]]
    then
        whiptail --title "ERROR" --msgbox "ERROR: no config file found in the current directory." 8 78
        return 0
    fi

    if [ "$EUID" != 0 ] #ask for super user
    then
        sudo $0
        exit 0
    fi

    CONFIG_NAME=$(ls -l | grep ".*\.conf$" | head -n1 | awk '{print $9}') #Set the name to an existing config in the directory
    CONFIG_NAME=${CONFIG_NAME%.conf}

    CONFIG_NAME=$(whiptail --inputbox "What name shall your config have (do not put extention)" 8 39 $CONFIG_NAME --title "Give a name to your config" 3>&1 1>&2 2>&3)
    
    CONFIG_NAME=$CONFIG_NAME.conf

    if [[ -e /etc/apache2/sites-available/$CONFIG_NAME ]] #If config exist at /etc/apache2/sites-available/
    then
        if ! (whiptail --title "Config Conflict" --yesno "There is already a config named $CONFIG_NAME, replace it ?" 8 78)
        then
            return 0 #exits if user dont whant to reset config
        fi
    fi

    if ! [[ -e $CONFIG_NAME ]]
    then
       whiptail --title "ERROR" --msgbox "ERROR: The name you provided don't correspond to a config file" 8 78 
       return 0
    fi

    whiptail --title "Info" --msgbox "It is now time for you to check if the config is ok, once in check mode, press q to quit." 8 78
    less $CONFIG_NAME
    
    if (whiptail --title "Validation" --yesno "Do you confirm you want to use the config ?" 8 78)
    then
        mv $CONFIG_NAME /etc/apache2/sites-available/
        a2ensite $CONFIG_NAME
        service apache2 reload
    fi

    return 0
}

VirtualHost_Create_Config() {
    CONFIG_NAME=$(whiptail --inputbox "What name shall your config have (do not put extention)" 8 39 serverconfig --title "Give a name to your config" 3>&1 1>&2 2>&3)
    CONFIG_NAME=$CONFIG_NAME.conf

    echo "<VirtualHost *:$PORT>" >$CONFIG_NAME

    echo "        ServerName $SERVER_NAME" >>$CONFIG_NAME
    echo "        ServerAlias $SERVER_NAME" >>$CONFIG_NAME
    echo "        ServerAdmin $SERVER_ADMIN" >>$CONFIG_NAME
    echo "        ErrorLog $ERROR_LOG" >>$CONFIG_NAME
    echo "        TransferLog $TRANSFER_LOG" >>$CONFIG_NAME
    echo "        DocumentRoot $DOCUMENT_ROOT" >>$CONFIG_NAME
    echo "        DirectoryIndex $DIRECTORY_INDEX" >>$CONFIG_NAME

    echo "        <Directory "$DOCUMENT_ROOT">" >>$CONFIG_NAME
    echo "                Options Indexes FollowSymLinks" >>$CONFIG_NAME
    echo "                AllowOverride All" >>$CONFIG_NAME
    echo "                Require all granted" >>$CONFIG_NAME
    echo "        </Directory>" >>$CONFIG_NAME
    echo "        RewriteEngine $REWRITE_ENGINE" >>$CONFIG_NAME
    echo "        RewriteCond %{SERVER_NAME} =$SERVER_NAME" >>$CONFIG_NAME
    echo "        RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]" >>$CONFIG_NAME

    echo "</VirtualHost>" >>$CONFIG_NAME
}

VirtualHost_Default() {
    PORT=80
    SERVER_NAME="name.server.com"
    SERVER_ALIAS="name.server.com"
    SERVER_ADMIN="admin@server.com"
    ERROR_LOG="/var/log/apache2/name.server.com-error_log"
    TRANSFER_LOG="/var/log/apache2/name.server.com-access_log"
    DOCUMENT_ROOT="/var/www/html/"
    DIRECTORY_INDEX="index.html"
    REWRITE_ENGINE="on"
}

VirtualHost_config() {
    VH_SELECTED=$(whiptail --title "Parameters to fill" --checklist "Select the parameters that you want to, (unless ou know what you're doing, it is advised to keep the preselected)" 20 85 10 \
    Port "port used for the site" ON \
    ServerName "name used to access site (usually a subdomain)" ON \
    ServerAlias "alias used to access the site" OFF \
    ServerAdmin "used to identify who is the admin" ON \
    ErrorLog "where to get the logs" ON \
    TransferLog "Where to send the logs" ON \
    DocumentRoot "where is your site" ON \
    DirectoryIndex "the path of the index relative to the DocumentRoot" ON \
    RewriteEngine "no desc" OFF 3>&1 1>&2 2>&3)

    VirtualHost_Default

    VH_SELECTED=$(echo "$VH_SELECTED" | sed 's/"//g')

    for i in $VH_SELECTED
    do
        #Port configuration (defaults to 80)
        if [ "$i" == "Port" ]
        then
            PORT=$(whiptail --inputbox "Server usually uses port 80" 8 39 80 --title "What port will your server use ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$PORT" == "" ]]
            then
                PORT=80
            fi

        #ServerName (mandatory)
        elif [ "$i" == "ServerName" ]
        then
            SERVER_NAME=$(whiptail --inputbox "Ususally subdomain.domain.topdomain" 8 60 subdomain.domain.topdomain --title "What name shall your site use ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$SERVER_NAME" == "" ]]
            then
                whiptail --title "Error" --msgbox "PEBKAC ERROR: You are required to enter a valid server name.\nExiting..." 8 78
                exit 1
            fi

        #ServerAlias (defaults to ServerName)
        elif [ "$i" == "ServerAlias" ]
        then
            SERVER_ALIAS=$(whiptail --inputbox "Ususally othersubdomain.domain.topdomain" 8 60 othersubdomain.domain.topdomain --title "What alias shall your site use ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$SERVER_ALIAS" == "" ]]
            then
                SERVER_ALIAS=$SERVER_NAME
            fi

        elif [ "$i" == "ServerAdmin" ]
        then
            SERVER_ADMIN=$(whiptail --inputbox "Ususally admin@domain.com" 8 60 admin@domain.com --title "Who is the admin of your site ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$SERVER_ADMIN" == "" ]]
            then
                SERVER_ADMIN=admin@$SERVER_NAME
            fi

        #ErrorLog (defaults to /var/log/apache2/$SERVER_NAME)
        elif [ "$i" == "ErrorLog" ]
        then
            ERROR_LOG=$(whiptail --inputbox "Ususally /var/log/apache2/$SERVER_NAME-error_log" 8 60 /var/log/apache2/$SERVER_NAME-error_log --title "What path should the error logs go to ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$ERROR_LOG" == "" ]]
            then
                ERROR_LOG="/var/log/apache2/$SERVER_NAME-error-log"
            fi

        #TransferLog (defaults to /var/log/apache2/$SERVER_NAME)
        elif [ "$i" == "TransferLog" ]
        then
            TRANSFER_LOG=$(whiptail --inputbox "Ususally /var/log/apache2/$SERVER_NAME-access_log" 8 60 /var/log/apache2/$SERVER_NAME-access_log --title "What path shall the logs go to ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$TRANSFER_LOG" == "" ]]
            then
                TRANSFER_LOG=$ERROR_LOG
            fi

        #DocumentRoot (defaults to /var/www/html)
        elif [ "$i" == "DocumentRoot" ]
        then
            DOCUMENT_ROOT=$(whiptail --inputbox "Ususally /var/www/html/$SERVER_NAME" 8 60 /var/www/html --title "Where is your site located ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$DOCUMENT_ROOT" == "" ]]
            then
                DOCUMENT_ROOT="/var/www/html"
            fi

        #DirectoryIndex (defauts to index.html)
        elif [ "$i" == "DirectoryIndex" ]
        then
            DIRECTORY_INDEX=$(whiptail --inputbox "Ususally index.html of index.php" 8 60 index.html --title "What is the name of your index ?" 3>&1 1>&2 2>&3)
            if [[ "$?" != 0 || "$DIRECTORY_INDEX" == "" ]]
            then
                DIRECTORY_INDEX="index.html"
            fi

        #RewriteEngine (defauts to index.html)
        elif [ "$i" == "RewriteEngine" ]
        then
            if (whiptail --title "Rewrite Engine" --yesno "Do you want to activate the Rewrite Engine ?" 8 78)
            then
                REWRITE_ENGINE="on"
            else
                REWRITE_ENGINE="off"
            fi
        fi
    done

    #Config creator
    VirtualHost_Create_Config
}

if ! hash "apache2" &> /dev/null
then
    whiptail --title "Error" --msgbox "ERROR: Yout must install apache2 to continue.\nExiting..." 8 78
    exit 1
fi

#Menu


MENU_SELECTED=$(whiptail --title "Apache2 configuration assitant" --menu "Choose an option" 25 100 16 \
"VirtualHost_config" "Guides you trough the creation of a virtual host configuration file." \
"VH_config_deploy" "Guides you trough the deployement of a virtual host configuration file." \
"Quit" "Exits the program." 3>&1 1>&2 2>&3)
if [ "$MENU_SELECTED" == "Quit" ]
then
    exit 0
fi

$MENU_SELECTED #Executes the fonction corresponding to the menu

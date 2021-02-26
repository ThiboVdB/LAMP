#!/usr/bin/bash
#Stop script on error
set -e

script="lamp.sh"
#Declare the number of mandatory args
margs=2

# Common functions - BEGIN
function example {
    echo -e "example: $script -u VAL -p VAL"
}

function usage {
    echo -e "usage: $script -u <sql-username> -p <sql-password>\n"
}

function help {
    usage
    echo -e "MANDATORY:"
    echo -e "  -u, --username  VAL  Username for the MySQL user.\n"
    echo -e "  -p, --password  VAL  Password for the MySQL user.\n"
    example
}

# Ensures that the number of passed args are at least equals
# to the declared number of mandatory args.
# It also handles the special case of the -h or --help arg.
function margs_precheck {
    if [ $2 ] && [ $1 -lt $margs ]; then
        if [ $2 == "--help" ] || [ $2 == "-h" ]; then
            help
            exit
        else
            usage
            example
            exit 1 # error
        fi
    fi
}

# Ensures that all the mandatory args are not empty
function margs_check {
    if [ $# -lt $margs ]; then
        usage
        example
        exit 1 # error
    fi
}
# Common functions - END

# Custom functions - BEGIN
function process_arguments {
    while [ -n "$1" ]
    do
        case $1 in
            -h|--help) echo "some usage details"; exit 1;;
            -x) do_something; shift; break;;
            -y) do_something_else; shift; break;;
            *) echo "some usage details"; exit 1;;
        esac
        echo $1; shift
    done
}

function install_firewalld {
    echo -e "${YELLOW}Check if firewalld is installed${NC}"
    if [ $(dpkg-query -W -f='${Status}' firewalld 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        echo "firewalld is not installed... installing now"
        apt install firewalld -y
    else
        echo "firewalld is already installed"
    fi
    
    
}

function update_packages {
    echo -e "${YELLOW}Updating all packages${NC}"
    
    apt update -y
    apt upgrade -y
}

function install_apache {
    echo -e "${YELLOW}Check if apache2 is installed${NC}"
    
    if [ $(dpkg-query -W -f='${Status}' apache2 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        echo "apache2 is not installed... installing now"
        apt install apache2 -y
    else
        echo "apache2 is already installed"
    fi
    
    
}

function configure_firewall_http_https {
    echo -e "${YELLOW}Configuring firewall ports for HTTP and HTTPS${NC}"
    firewall-cmd --add-port=80/tcp --permanent
    firewall-cmd --add-port=443/tcp --permanent
    echo -e "Reload firewall"
    firewall-cmd --reload
}

function install_mysql {
    echo -e "${YELLOW}Check if mysql is installed${NC}"
    
    if [ $(dpkg-query -W -f='${Status}' mysql-server 2>/dev/null | grep -c "ok installed") -eq 0 ];
    then
        echo "mysql-server is not installed... installing now"
        apt install mysql-server -y
    else
        echo "mysql-server is already installed"
    fi
    
}

function install_php {
    echo -e "${YELLOW}Check if php and all dependencies are installed${NC}"
    
    
    php_packages=("php" "libapache2-mod-php" "php-mysql")
    
    for pkg in ${php_packages[@]};do
        if [ $(dpkg-query -W -f='${Status}' $pkg 2>/dev/null | grep -c "ok installed") -eq 0 ];
        then
            echo "$pkg is not installed... installing now"
            apt install $pkg -y
        else
            echo "$pkg is already installed"
        fi
    done
}

# function install_phpmyadmin {
#     apt install phpmyadmin php-mbstring php-zip php-gd php-json php-curl -y
# }

function restart_enable_services {
    
    
    services=("apache2" "mysql")
    
    for serv in ${services[@]};do
        echo -e "${YELLOW}Check if $serv is enabled${NC}"
        if [ $(systemctl is-enabled $serv 2>/dev/null | grep -c "enabled") -eq 0 ];
        
        then
            echo "$serv is not enabled... enabling now"
            systemctl enable $serv
        else
            echo "$serv is already enabled"
        fi
        echo -e "Restarting $serv"
        systemctl restart $serv
        
    done
    
}

function configure_mysql {
    echo -e "${YELLOW}Configuring mysql with provided credentials${NC}"
    mysql -u root --execute="USE mysql; UPDATE user SET plugin='mysql_native_password' WHERE User='root'; FLUSH PRIVILEGES;"
    mysql -u root --execute="CREATE USER IF NOT EXISTS '$username'@'localhost' IDENTIFIED WITH mysql_native_password BY '$password'; "
    mysql -u root --execute="GRANT ALL PRIVILEGES ON *.* to '$username'@'localhost';"
}

function configure_firewall_mysql {
    echo -e "${YELLOW}Configuring firewall port for mysql${NC}"
    echo -e "Reload firewall"
    firewall-cmd --add-port=3306/tcp --permanent
    firewall-cmd --reload
}
# Custom functions - END

# Main
margs_precheck $# $1

username=
password=
# Args while-loop
while [ "$1" != "" ];
do
    case $1 in
        -u  | --username )  shift
            username=$1
        ;;
        -p  | --password )  shift
            password=$1
        ;;
        -h   | --help )        help
            exit
        ;;
        *)
            echo "$script: illegal option $1"
            usage
            example
            exit 1 # error
        ;;
    esac
    shift
done

# Pass here your mandatory args for check
margs_check $username $password

# Your stuff goes here
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting script${NC}"
update_packages
install_firewalld
install_apache
configure_firewall_http_https
install_mysql
install_php
configure_mysql $username $password
configure_firewall_mysql
restart_enable_services
echo -e "${YELLOW}Script finished${NC}"

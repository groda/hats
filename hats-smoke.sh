#!/bin/bash
  
usage() {
    cat <<EOM
    Usage:
    $(basename $0) [-i] <mycloud> <myproject>
    where <mycloud> is the name of your cloud provider
    and <myproject> is the name of your project

    The two parameters are just names and are used to keep multiple projects organized 
    and to be able to locate the ansible inventory file. The names can be chosen
    arbirtarily but it's convenient if they reflect the names of your clouds/projects.  
    Example directory structure for CLOUD01 (with PROJX, PROJY) and CLOUD02 (PROJZ):
    ├── common
    │   └── ansible
    │       └── playbooks
    ├── CLOUD01 
    │   └── ansible
    │       ├── PROJX
    │       └── PROJY
    └── CLOUD02
        └── ansible
            └── PROJZ
    The inventory file for project PROJY should be located in CLOUD01/ansible/PROJY    

    Option -n: no interactivity. Use this option if you want to run the script unattended.
    
    By default the script allows you to set some paramters interactively
    or decide which tests to run and which to skip.
EOM
    exit 0
}

interactive=1
while getopts n OPTION 
do
  case $OPTION in
  n)
     interactive=0
     ;;
  \?)
     exit
     ;;
  esac
done

shift $(($OPTIND - 1))
[ $# -lt 2 ] && { usage; }

check_status() { [ $? -eq 0 ] && echo ✅ || echo 🛑; }

CLOUD=$1
PROJ=$2

if [ ! -d "$CLOUD/ansible/$PROJ" ]; then
  mkdir -p "$CLOUD/ansible/$PROJ"
  echo "Directory created: $CLOUD/ansible/$PROJ"
else
  echo "Directory already exists: $CLOUD/ansible/$PROJ"
fi

if  [ -z "$(grep ^hadoopclientnode $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini)" ]; then
  echo "Create ansible inventory file"
  ansible_user=myuser # default username
  ansible_host=myhost # default host
  cat <<EOF >$CLOUD/ansible/$PROJ/ansible_inventory_hats.ini
[clientnode]
hadoopclientnode ansible_host=${ansible_host}

[clientnode:vars]
ansible_user=${ansible_user}
EOF
else
  ansible_user=$(grep ansible_user $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini|cut -d= -f2)
  ansible_host=$(grep ansible_host $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini|cut -d= -f2)
fi

echo "The Ansible username is the user who runs the test jobs on the cluster"
#echo "Currently, it is: $ansible_user"
if [ $interactive == 1 ];then
  read -p "Enter your ansible username (enter to keep default)  [$ansible_user]: " ansible_user_new
  if [ "$ansible_user_new" != "" ];then
    echo $ansible_user_new
    sed "s/ansible_user.*/ansible_user=${ansible_user_new}/" $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini > \
         tmpfile && mv tmpfile $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini
  fi
fi

echo "The Ansible host is the host where to access the Hadoop cluster"
#echo "Currently, it is: $ansible_host"
if [ $interactive == 1 ];then
  read -p "Enter your ansible hostname (enter to keep default)  [$ansible_host]: " ansible_host_new
  if [ "$ansible_host_new" != "" ];then
    sed "s/ansible_host.*/ansible_host=${ansible_host_new}/" $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini > \
         tmpfile && mv tmpfile $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini
  fi
fi

echo "~❀~ Ping hosts in the project's inventory ~❀~"
ansible-playbook -T 10 -i $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini common/ansible/playbooks/ping_hosts.yml
check_status

# Populate the associative array of tests and their descriptions
tests=(
 "common/ansible/playbooks/test_hdfs.yml|Test HDFS"
 "common/ansible/playbooks/test_mapreduce.yml|Test MapReduce"
 "common/ansible/playbooks/test_examples.yml|Test examples"
 "common/ansible/playbooks/test_config.yml|Test config"
)

# Iterate over the commands
for t in "${tests[@]}"; do
    playbook="${t%|*}"
    desc="${t#*|}"
    echo "Description: $desc"
    if [ $interactive == 1 ];then
      read -p "Do you want to execute this test (type any key except n or N to proceed) [Y|n]: " response
    fi
    # Default to 'yes' if no input is given
    response=${response:-Y}
    echo "~❀~ $desc ~❀~"
    if [[ $response == "n" || $response == "N" ]]; then
        echo "Skipping: $playbook"
        echo "⏩"
    else
        echo "Executing: $playbook"
        ansible-playbook -T 20 -i $CLOUD/ansible/$PROJ/ansible_inventory_hats.ini $playbook
        check_status
    fi
done

#!/bin/sh

function parse_inventory_and_get_ip_by_given_vmid {
local SECTION_NUM=0
local VARS_SECTION_NUM=0
local SECTION=""
local VALID_SECTION_TYPE=false
local VALID_VMID_SECTION=false
local LINE_NUM=0
local VMID=-1
local INVENTORY_FILE=""
local IP=""

while [[ $# > 0 ]]; do
  key="$1"
  case $key in
    -f)
      INVENTORY_FILE=$2
      shift
    ;;

    -v)
      VMID=$2
      shift
    ;;

    -h|--help|-?)
      echo "$0 [options]"
      echo " -v <vmid> Vmid marker"
      echo " -f <file> Inventory file to parse"
      exit 0
    ;;


    *)
      # unknown option
      echo "Error: unknown option $1"
      exit 1
    ;;

  esac
  shift # past argument or value
done

while read -r line || [ -n "$line" ]; do
	LINE_NUM=$((LINE_NUM+1))
	# Skip comments and empty lines
	if [ -z "$line" ] || [[ "$line" =~ ^#.* ]]; then
        	continue
       	fi

	# Do we have a section marker?
	if [[ "${line}" =~ ^\[[a-zA-Z0-9_:-]{1,}\]$ ]]; then
		VALID_SECTION_TYPE=false
		VALID_VMID_SECTION=false
		IP=""
		# Is this a 'vars' section?
		if [[ "${line}" =~ ^\[[a-zA-Z0-9_:-]{1,}\:vars\]$ ]]; then
			#echo "VALID_VARS_SECTION"
			VALID_SECTION_TYPE=true
			VARS_SECTION_NUM=$((VARS_SECTION_NUM+1))
              	fi
		# Set SECTION var to name of section (strip [ and ] from section marker)
		SECTION="${line#[}"
		SECTION="${SECTION%]}"
		SECTION_NUM=$((SECTION_NUM+1))
               	continue
	fi
        if [[ $VALID_SECTION_TYPE ]]; then
		# split line at "=" sign
	      	IFS="="
		read -r VAR VAL <<< "${line}"

                # delete spaces around the equal sign (using extglob)
                VAR="$(echo -e "${VAR}" | tr -d '[:space:]')"
		VAL="$(echo -e "${VAL}" | tr -d '[:space:]')"
                VAR=$(echo $VAR)
                if [ "$VAR" = "vmid" ] || [ "$VAR" = "host_static_ip" ]; then
#echo "super"
			if [[ "$VAL" =~ ^\".*\"$  ]]; then
                                # remove existing double quotes
                                VAL="${VAL%\"}"
                                VAL="${VAL#\"}"
			elif [[ "$VAL" =~ ^\'.*\'$ ]]; then
                                # remove existing single quotes
                                 VAL="${VAL#\'}"
                                 VAL="${VAL%\'}"
                        fi
                fi

                if [ "$VAR" = "vmid" ] && [ $VAL -eq $VMID ]; then
			#echo "VALIM_VMID_SECTION"
			VALID_VMID_SECTION=true
#                        if [[ "$IP" -ne "" ]]; then
 #                               echo $IP
 #                               break
 #                       fi
                fi
                if [ "$VAR" = "host_static_ip" ]; then
			if [ "$VALID_VMID_SECTION" = true ]; then
                                echo $VAL
				break
                        else
                                IP=$VAL
                        fi
                fi
        fi
done < $INVENTORY_FILE
}

SERVER=alchemy4
USERNAME=root@pam
NODE=alchemy4
PASSWORD=******
FROM_VMID=6000
TO_VMID=6006
SUBNET_NAME="Testnet"
SUBNET_MASK=255.255.255.240
INVENTORY_DIR="some-path/inventory/Testnet/"
IS_THIS_JENKINS_MACHINE=false

while [[ $# > 0 ]]; do
  key="$1"
  case $key in
    -u)
      USERNAME=$2
      shift
    ;;

    -p)
      PASSWORD=$2
      shift
    ;;

    -f)
      FROM_VMID=$2
      shift
    ;;
    
    -t)
      TO_VMID=$2
      shift
    ;;
    
    -s)  
      SERVER=$2
      shift
    ;;

    -m)
      SUBNET_MASK=$2
      shift
    ;;

    -i)
      INVENTORY_DIR=$2
      shift
    ;;

    -d)
      PLAYBOOK_DIR=$2
      shift
    ;;

    -j)
       IS_THIS_JENKINS_MACHINE=$2
       shift	    
    ;;

    -h|--help|-?)
      echo "Usage:"
      echo "$0 [options]"
      echo " -u <username>       Username, default $USERNAME"
      echo " -p <password>       Password, default $PASSWORD"
      echo " -s <server>         Server to connect to, default $SERVER"
      echo " -f <fromVmid>       First available subnet vmid number, default $FROM_VMID"
      echo " -t <toVmid>         Last available subnet vmid number, default $TO_VMID"
      echo " -m <subnetMask>     Internal subnet-mask, default $SUBNET_MASK"
      echo " -i <inventoryDir>   The main inventory directory passed, default $INVENTORY_DIR"
      echo " -d <playbookDir>    The main  directory passed, default $PLAYBOOK_DIR"      
      echo " -j <jenkinsMachine> Defines if this is a jenkins-ansible control machine within subnet, default $IS_THIS_JENKINS_MACHINE"

      exit 0
    ;;


    *)
      # unknown option
      echo "Error: unknown option $1"
      exit 1
    ;;

  esac
  shift # past argument or value
done


RESPONSE=$(curl -s -k -d "username=$USERNAME&password=$PASSWORD" https://$SERVER:8006/api2/json/access/ticket)
TOKEN=$(echo $RESPONSE | jq -r .data.ticket)
NODES=$(curl -s -k https://$SERVER:8006/api2/json/nodes -b "PVEAuthCookie=$TOKEN" | jq -r '.data[].node')

for NODE in $(echo $NODES); do
  curl -s -k https://$SERVER:8006/api2/json/nodes/$NODE/qemu -b "PVEAuthCookie=$TOKEN" > /tmp/proxvm-qemu.json
  for VMID in $(cat /tmp/proxvm-qemu.json | jq -r .data[].vmid); do
    if [ $VMID -le $TO_VMID ] && [ $VMID -ge $FROM_VMID ]; then
      curl -s -k https://$SERVER:8006/api2/json/nodes/$NODE/qemu/$VMID/config -b "PVEAuthCookie=$TOKEN" > /tmp/proxvm-$VMID.json
      JSON=$(cat /tmp/proxvm-qemu.json | jq -r ".data[] | select(.vmid | tonumber | contains($VMID))") 
      NET=$(cat /tmp/proxvm-$VMID.json | jq -r .data.net0)
      HWADDR=$(echo $NET | sed -re "s/[a-zA-Z0-9]+=([a-zA-Z0-9:]+),.*/\1/g")
      #echo $VMID
      #echo "MAC:$HWADDR"
     
      if [ "$IS_THIS_JENKINS_MACHINE" = true ] ; then
	IP=$(parse_inventory_and_get_ip_by_given_vmid -v $VMID -f /var/lib/jenkins/custom-user-inventory/user_subnet_vms)
      else
	IP=$(parse_inventory_and_get_ip_by_given_vmid -v $VMID -f $INVENTORY_DIR/user_subnet_vms)
      fi

      if [[ "$IP" = "" ]]; then
        IP=$(parse_inventory_and_get_ip_by_given_vmid -v $VMID -f $INVENTORY_DIR/subnet_templates_and_admin_vms)
      fi
      if [[ "$IP" != "" ]]; then
        echo "Creating dhcp entry with following values: MASK=$SUBNET_MASK MAC=$HWADDR IP=$IP"
        HWADDR=$(echo $HWADDR|sed 's/\(.*\)/\L\1/')
        HWADDR=$(echo $HWADDR|sed 's/://g')
        HWADDR=$(echo $HWADDR|sed 's/.\{4\}/&-/g')
        HWADDR=$(echo $HWADDR|sed 's/.$//')

        sed -i "/forbidden-ip/a\ static-bind ip-address $IP mask $SUBNET_MASK hardware-address $HWADDR" $PLAYBOOK_DIR/files/template.cfg
      fi  
    fi
  done
done

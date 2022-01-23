#!/bin/bash

SERVER=alchemy4
NODE_IP=10.5.200.65
USERNAME=root@pam
PASSWORD=*******
FROM_VMID=6002
TO_VMID=6002
IN_STATE=current
INVENTORY_DIR=../inventory/

while [[ $# > 0 ]]; do
    key="$1"
    case $key in
    
    -s)
      SERVER=$2
      shift
    ;;

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

    -d)
      INVENTORY_DIR=$2
      shift
    ;;

    -h|--help|-?)
      echo "Usage:"
      echo "$0 [options]"
      echo " -s <server>        Server to connect to, default $SERVER"
      echo " -u <username>      Username, default $USERNAME"
      echo " -p <password>      Password, default $PASSWORD"
      echo " -f <fromVmid>      From VMID, default $FROM_VMID"
      echo " -t <toVmid>        To VMID, default $TO_VMID"
      echo " -d <inventoryDir>  Default to $INVENTORY_DIR"
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
CSRF_PRESERVATION_TOKEN=$(echo $RESPONSE | jq -r .data.CSRFPreventionToken)
NODES=$(curl -s -k https://$SERVER:8006/api2/json/nodes -b "PVEAuthCookie=$TOKEN" | jq -r .data[].node)
count=0

for NODE in $(echo $NODES); do
    curl -s -k https://$SERVER:8006/api2/json/nodes/$NODE/qemu -b "PVEAuthCookie=$TOKEN" > /tmp/proxvm-qemu.json
    for VMID in $(cat /tmp/proxvm-qemu.json | jq -r .data[].vmid); do
      if [ $VMID -le $TO_VMID ] && [ $VMID -ge $FROM_VMID ]; then
        TEMPLATE_PROPERTY=$(curl -s -k https://$SERVER:8006/api2/json/nodes/$NODE/qemu/$VMID/config -b "PVEAuthCookie=$TOKEN" | jq .data.template)
        if [ $TEMPLATE_PROPERTY != 1 ]; then
          count=$((count+1))
          echo "[CurrentSubnetHosts]"             >> $INVENTORY_DIR/generatedHostsFile
	  echo "subnetHost$count vmid=$VMID"      >> $INVENTORY_DIR/generatedHostsFile
        fi
      fi
    done
done

echo "[CurrentSubnetHosts]"               >> $INVENTORY_DIR/generatedHostsFile

echo "[CurrentSubnetHosts:vars]"          >> $INVENTORY_DIR/generatedHostsFile
echo "ansible_connection=local"           >> $INVENTORY_DIR/generatedHostsFile

echo "[PrivilegesGroup:children]"         >> $INVENTORY_DIR/generatedHostsFile
echo "CurrentSubnetHosts"                 >> $INVENTORY_DIR/generatedHostsFile

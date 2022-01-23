export ANSIBLE_HOME=$input_variable
echo "Please enter Vault Password:"
read -s input_variable
#echo "You entered: $input_variable"
export VAULT_PASSWORD=$input_variable
#mkdir -p /etc/ansible/roles
#export ANSIBLE_ROLES_PATH=/etc/ansible/roles

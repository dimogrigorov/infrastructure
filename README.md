### Preliminary steps
In order to set-up your ansible machine do(manual step that depends on your linux distribution) do:
wget https://bootstrap.pypa.io/get-pip.py
```
python get-pip.py --user
```
```
sudo ~/.local/bin/pip install --upgrade pip
~/.local/bin/pip install ansible --user
~/.local/bin/pip install requests --user
~/.local/bin/pip install proxmoxer --user
~/.local/bin/pip install pyhpecw7 --user
```
Generate rsk private-publik key pair by executing:
```
ssh-keygen -t rsa
```
A good practise would be when you're asked for a passphrase to enter and REMEMBER. This refers to a secret used to protect your encryption key.
* Last distribute your rsa key to all your Proxmox cluster nodes(hosts) by simply calling: 
```
ssh-copy-id root@proxmoxnode3(the IP adress of one of your proxmox cluster nodes actually comes here)
```
if your cluster is well set-up the key will automatically distribute to all your cluster machines!
### Environment set-up
In order to set-up your environment and to set your vault decription pass in your main(and in every other) shell that would gonna use for 'running subnet re-creation' call: 
```
source environment_set_up.sh
```
### Add ansible to PATH
Call the following command line: 
```
echo "export PATH=~/.local/bin:$PATH" >> ~./bashrc
```

### Fix inventory template to fit your needs
Validates newly created from template inventory! Failing in this task means you have forgot to change/uncomment some necessary variables. This is a good practive step in order to avoid mistakes! 
```
ansible-inventory -i inventory/Testnet --list
```
### Run subnet re-creation
In order to call main(parent) create_limited_access_subnet.yml do:
* First do the 'environment set-up' step. After that from that same shell call:
```
ansible-playbook create_limited_access_subnet.yml --vault-password-file ./vault_pass.py -i inventory/Testnet/  -vvv --extra-vars "@inventory/Testnet/enforce_value_vars.yml
```

References used:
https://gist.github.com/huksley/d36b9a56386ec0a79a333ef74c047be8
https://github.com/rudimeier/bash_ini_parser
https://github.com/HPENetworking/ansible-hpe-cw7
https://www.linuxquestions.org/questions/programming-9/bash-cidr-calculator-646701/

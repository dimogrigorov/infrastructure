job("full-recreate-subnet") {
    authorization {
        permissions('admin', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Configure',
            'hudson.model.Item.Delete',
            'hudson.model.Item.Discover',
            'hudson.model.Item.Read',
            'hudson.model.Item.Workspace',
            'hudson.model.Run.Delete',
            'hudson.model.Run.Update',
            'hudson.scm.SCM.Tag'
        ])

    }

    wrappers {
        credentialsBinding {
            string('VAULT_PASSWORD', 'VAULT_PASSWORD')
        }
    }

    scm {
        cloneWorkspace("cloneSources", "Any")
    }

    steps { shell '''export VAULT_PASSWORD=${VAULT_PASSWORD}

ansible-playbook tasks/generate_current_subnet_state_inventory.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "state=current" \\
--extra-vars "@../inventory/enforce_value_vars.yml"

ansible-playbook tasks/put_vm_in_state.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "state=stopped \\
              host=CurrentSubnetHosts" \\
--extra-vars "@../inventory/enforce_value_vars.yml"

ansible-playbook tasks/put_vm_in_state.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "state=absent \\
              host=CurrentSubnetHosts" \\
--extra-vars "@../inventory/enforce_value_vars.yml"

ansible-playbook tasks/create_subnet_user_and_set_privileges.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "visibilityToSubnet=Internal" \\
--extra-vars "@../inventory/enforce_value_vars.yml" \\
--tags "privileges"

ansible-playbook tasks/create_vm_from_template.yml \\
--vault-password-file ./vault_pass.py \\
-i ../inventory \\
-i /var/lib/jenkins/custom-user-inventory/user_subnet_vms \\
--extra-vars "host=InternalUserVMsGroup \\
              force_variable_check=True" \\
--extra-vars "@../inventory/enforce_value_vars.yml"

ansible-playbook tasks/re_generate_and_re_apply_router_config.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "@../inventory/enforce_value_vars.yml"
        '''
    }
}

job("guest-build-inventory") {
    authorization {
        permissions('admin', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Configure',
            'hudson.model.Item.Delete',
            'hudson.model.Item.Discover',
            'hudson.model.Item.Read',
            'hudson.model.Item.Workspace',
            'hudson.model.Run.Delete',
            'hudson.model.Run.Update',
            'hudson.scm.SCM.Tag'
        ])

        permissions('anonymous', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Read',
            'hudson.model.Item.Configure'
        ])
    }

    steps {
        shell '''# "-------------------------Please put/copy your inventory definition inside the double brackets ------------------------------"

INVENTORY_VALUE="

[InternalUserVMsGroup:children]

ActiveChestFlowerViolenceVM
StupidRejoiceClassDressVM

[ActiveChestFlowerViolenceVM]
activeChestFlowerViolenceVM
[ActiveChestFlowerViolenceVM:vars]
vmid=6004
new_machine_name=VM1
template_vmid=6011
host_static_ip=10.5.202.164
full_clone=no

[StupidRejoiceClassDressVM]
stupidRejoiceClassDressVM
[StupidRejoiceClassDressVM:vars]
vmid=6005
new_machine_name=VM6
template_vmid=6011
host_static_ip=10.5.202.165
full_clone=no"

# "-------------------------Please put/copy your inventory definition above------------------------------"
echo "$INVENTORY_VALUE" > /var/lib/jenkins/custom-user-inventory/user_subnet_vms
'''
    }

    publishers {
        downstream('full-recreate-subnet', 'SUCCESS')
    }
}

job("cron-recreate-privileges") {
    authorization {
        permissions('admin', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Configure',
            'hudson.model.Item.Delete',
            'hudson.model.Item.Discover',
            'hudson.model.Item.Read',
            'hudson.model.Item.Workspace',
            'hudson.model.Run.Delete',
            'hudson.model.Run.Update',
            'hudson.scm.SCM.Tag'
        ])

    }

    wrappers {
        credentialsBinding {
            string('VAULT_PASSWORD', 'VAULT_PASSWORD')
        }
    }

    scm {
        cloneWorkspace("cloneSources", "Any")
    }

    steps { 
        shell '''export VAULT_PASSWORD=${VAULT_PASSWORD}

ansible-playbook tasks/create_subnet_user_and_set_privileges.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "visibilityToSubnet=Internal" \\
--extra-vars "@../inventory/enforce_value_vars.yml" \\
--tags "privileges"'''
        }
    
    triggers {
        cron("H/15 * * * *")
    }

    logRotator {
        numToKeep(1)
    }
}

job("manage-all-subnet-machines") {
    parameters {
        activeChoiceParam('vm_state') {
            choiceType('SINGLE_SELECT')
            groovyScript {
                script("return ['started', 'absent', 'stopped', 'restarted', 'current']")
            }
        }
    }

    wrappers {
        credentialsBinding {
            string('VAULT_PASSWORD', 'VAULT_PASSWORD')
        }
    }

    authorization {
        permissions('admin', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Configure',
            'hudson.model.Item.Delete',
            'hudson.model.Item.Discover',
            'hudson.model.Item.Read',
            'hudson.model.Item.Workspace',
            'hudson.model.Run.Delete',
            'hudson.model.Run.Update',
            'hudson.scm.SCM.Tag'
        ])

        permissions('anonymous', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Read'
        ])
    }

    scm {
        cloneWorkspace('cloneSources', criteria = 'Any')
    }

    steps {
        shell '''export VAULT_PASSWORD=${VAULT_PASSWORD}

ansible-playbook tasks/generate_current_subnet_state_inventory.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "state=current" \\
--extra-vars "@../inventory/enforce_value_vars.yml"

ansible-playbook tasks/put_vm_in_state.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "state=$vm_state \\
              host=CurrentSubnetHosts" \\
--extra-vars "@../inventory/enforce_value_vars.yml"

#TODO: Add check

ansible-playbook tasks/create_subnet_user_and_set_privileges.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "visibilityToSubnet=Internal" \\
--extra-vars "@../inventory/enforce_value_vars.yml" \\
--tags "privileges"
        '''
    }
}

job("manage-single-subnet-machine") {
    authorization {
        permissions('admin', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Configure',
            'hudson.model.Item.Delete',
            'hudson.model.Item.Discover',
            'hudson.model.Item.Read',
            'hudson.model.Item.Workspace',
            'hudson.model.Run.Delete',
            'hudson.model.Run.Update',
            'hudson.scm.SCM.Tag'
        ])

        permissions('anonymous', [
            'hudson.model.Item.Build',
            'hudson.model.Item.Cancel',
            'hudson.model.Item.Read'
        ])
    }

    wrappers {
        credentialsBinding {
            string('VAULT_PASSWORD', 'VAULT_PASSWORD')
        }
    }

    scm {
        cloneWorkspace('cloneSources', criteria = 'Any')
    }

    parameters {
        activeChoiceParam('vm_state') {
            choiceType('SINGLE_SELECT')
            groovyScript {
                script("return ['started', 'absent', 'stopped', 'restarted', 'current']")
            }
        }
        stringParam ('vmid', '', 'the vmid of the machine you want to put in specific state')
    }

    steps {
        shell '''export VAULT_PASSWORD=${VAULT_PASSWORD}

ansible-playbook tasks/put_vm_in_state.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "host=localhostInternalSubnet \\
              state=${vm_state} \\
              vmid=${vmid} \\
              force_variable_check=True" \\
--extra-vars "@../inventory/enforce_value_vars.yml"


#TODO: Add check

ansible-playbook tasks/create_subnet_user_and_set_privileges.yml \\
--vault-password-file ./vault_pass.py -i ../inventory \\
--extra-vars "visibilityToSubnet=Internal" \\
--extra-vars "@../inventory/enforce_value_vars.yml" \\
--tags "privileges"
        '''
    }
}

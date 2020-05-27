#!/bin/bash

# version 0.1

set -e

# Tiggers oc groups sync using oc command
# Since uim identity provider is configured to do a lookup as mapping method
# user has to exist.
# Script will create new users based on their membership in specific group
[[ "$#" -gt 1 || $1 = "dry_run=false" ]] && DRY_RUN=false || DRY_RUN=true

if [[ $LDAP_GROUP == "" ]]; then
    LDAP_GROUP="CN=AA-APP-MicroServicesPlatform-Admins,OU=Applications,OU=Groups,OU=AA,OU=UPC,DC=upcit,DC=ds,DC=upc,DC=biz"
fi

LDAP_SERVER=$(grep -e 'url:' /opt/config/ad-sync.yaml);LDAP_SERVER=$(sed -e 's/^url: "//' -e 's/"$//'<<<$LDAP_SERVER)
LDAP_BINDDN=$(grep -e 'bindDN:' /opt/config/ad-sync.yaml);LDAP_BINDDN=$(sed -e 's/^bindDN: "//' -e 's/"$//'<<<$LDAP_BINDDN)
LDAP_BINDPS=$(grep -e 'bindPassword:' /opt/config/ad-sync.yaml);LDAP_BINDPS=$(sed -e 's/^bindPassword: "//' -e 's/"$//'<<<$LDAP_BINDPS)

ldap_users=()
os_users=()
new_users=()
new_identities=()
msp_users=()
non_msp_users=()
remove_users=()

log() {
    echo "$@"
}

if $DRY_RUN; then
    oc adm groups sync --sync-config=/opt/config/ad-sync.yaml --whitelist=/opt/config/group_whitelist.lst
else
    oc adm groups sync --sync-config=/opt/config/ad-sync.yaml --whitelist=/opt/config/group_whitelist.lst --confirm
fi

IFS=$'\n'
ldap_users=($(ldapsearch -x -H $LDAP_SERVER -D "$LDAP_BINDDN" -w "$LDAP_BINDPS" -b "$LDAP_GROUP" -s base -o ldif-wrap=no | grep member | sed -n "s/^member: //p"))


for i in "${!ldap_users[@]}"; do
  printf "%s\t%s\n" "$i" "${ldap_users[$i]}"
  ldap_users[$i]=$(ldapsearch -x -H $LDAP_SERVER -D "$LDAP_BINDDN" -w "$LDAP_BINDPS" -b "${ldap_users[$i]}" -s base sAMAccountName | grep sAMAccountName | sed -n "s/sAMAccountName: //p")
done


log 'LDAP users: '$ldap_users

os_users=$(oc get users -o custom-columns=NAME:.metadata.name --no-headers)

log 'OS users: '$os_users

msp_users=$(oc get users --no-headers | grep -v UPCIT | awk '{print $1}')
non_msp_users=$(oc get users --no-headers | grep -v htpasswd | awk '{print $1}')

log 'MSP: '$msp_users
log 'NON MSP: '$non_msp_users

new_users=$(echo ${ldap_users[@]} ${os_users[@]} | tr ' ' '\n' | sort | uniq -u)
new_users=$(echo ${ldap_users[@]} ${new_users[@]} | tr ' ' '\n' | sort | uniq -D | uniq)

log 'NEW: '$new_users

new_identities=$(echo ${ldap_users[@]} ${msp_users[@]} | tr ' ' '\n' | sort | uniq -D | uniq)
log 'NEW IDEN: '$new_identities

remove_users=$(echo ${ldap_users[@]} ${non_msp_users[@]} | tr ' ' '\n' | sort | uniq -D | uniq)
remove_users=$(echo ${non_msp_users[@]} ${remove_users[@]} | tr ' ' '\n' | sort | uniq -u)

log 'REMOVE: '$remove_users

for user in ${new_users[@]}; do
    if $DRY_RUN; then
        echo 'Creating user' $user
    else
        oc create user $user
        oc create identity UPCIT:$user
        oc create useridentitymapping UPCIT:$user $user
    fi
done

for user in ${new_identities[@]}; do
    if $DRY_RUN; then
        echo 'Adding identity for '$user
    else
        oc create identity UPCIT:$user
        oc create useridentitymapping UPCIT:$user $user
    fi
done

for user in ${remove_users[@]}; do
    if $DRY_RUN; then
        echo 'Deleting user '$user
    else
        oc delete user $user
        oc delete identity UPCIT:$user
    fi
done

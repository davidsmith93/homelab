group="management"
users=( "watchtower" "portainer")

# getent group ${group} 2>&1 > /dev/null || groupadd ${group}

for user in ${users[@]}
do
    grep "${user}" /etc/passwd 2>&1 > /dev/null || echo "Hello?"
done

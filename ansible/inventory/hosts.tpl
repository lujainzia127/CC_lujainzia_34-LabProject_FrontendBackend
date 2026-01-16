[frontend]
${frontend_public_ip}

[backends]
${backend_public_ips[0]}
${backend_public_ips[1]}
${backend_public_ips[2]}

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=${private_key_path}
backend1_private_ip=${backend_private_ips[0]}
backend2_private_ip=${backend_private_ips[1]}
backup_backend_private_ip=${backend_private_ips[2]}

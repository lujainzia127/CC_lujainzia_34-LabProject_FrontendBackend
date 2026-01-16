[frontend]
frontend ansible_host=${frontend_public_ip}

[backends]
backend1 ansible_host=${backend_public_ips[0]} backend_private_ip=${backend_private_ips[0]}
backend2 ansible_host=${backend_public_ips[1]} backend_private_ip=${backend_private_ips[1]}
backend3 ansible_host=${backend_public_ips[2]} backend_private_ip=${backend_private_ips[2]}

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=${private_key_path}

podman pull quay.io/metal3-io/vbmc
# Run vbmc
mkdir -p /opt/virtualbmc
mkdir /opt/virtualbmc/vbmc
mkdir /opt/virtualbmc/vbmc/conf
mkdir /opt/virtualbmc/vbmc/log
chmod -R 755 /opt/virtualbmc

cat <<EOF > /opt/virtualbmc/vbmc/virtualbmc.conf
[default]
config_dir=/root/.vbmc/conf/
[log]
logfile=/root/.vbmc/log/virtualbmc.log
debug=True
[ipmi]
session_timout=20
EOF

mkdir -p /opt/virtualbmc/vbmc/conf/node-1
mkdir -p /opt/virtualbmc/vbmc/conf/node-2
cat <<EOF > /opt/virtualbmc/vbmc/conf/node-1/config
[VirtualBMC]
username = admin
password = password
domain_name = node-1
libvirt_uri = qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1
address = 192.168.111.1
active = True
port =  6230
EOF

cat <<EOF > /opt/virtualbmc/vbmc/conf/node-2/config
[VirtualBMC]
username = admin
password = password
domain_name = node-2
libvirt_uri = qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1
address = 192.168.111.1
active = True
port =  6231
EOF
# DRBD High Availability Installation Guide

## Prerequisites

### Hardware Requirements
- **DRBD Nodes**: Minimum 2 nodes with local storage
- **Dedicated Network**: Low-latency network connection between DRBD nodes
- **Docker Host**: Server with Docker Engine installed

### Software Requirements
- **Operating System**: Linux (Debian 11+, Ubuntu 20.04+, RHEL/CentOS 8+, SLES 15+)
- **DRBD**: Version 9.x or higher
- **Pacemaker**: Version 2.x or higher
- **Corosync**: For cluster communication
- **NFS Utils**: For NFS services
- **Docker**: Version 20.x or higher

## General Installation Steps

### 1. DRBD Node Preparation

```bash
# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y drbd-utils pacemaker corosync nfs-kernel-server nfs-common

# Configure DRBD resource
cat > /etc/drbd.d/docker-vol.res << EOF
resource docker-vol {
    protocol C;
    device /dev/drbd0;
    disk /dev/sdb1;
    meta-disk internal;
    
    on node1 {
        address 192.168.10.231:7789;
    }
    
    on node2 {
        address 192.168.10.232:7789;
    }
}
EOF

# Initialize DRBD
drbdadm create-md docker-vol
systemctl enable drbd
systemctl start drbd

# On primary node only
drbdadm primary docker-vol --force
mkfs.ext4 /dev/drbd0
```

### 2. Pacemaker Cluster Configuration

```bash
# Install pcs
apt install -y pcs

# Configure hacluster password
passwd hacluster

# Authenticate nodes
pcs host auth node1 node2
pcs cluster setup docker-cluster node1 node2
pcs cluster start --all
pcs cluster enable --all

# Create resources
pcs resource create drbd_resource ocf:linbit:drbd \
    drbd_resource=docker-vol \
    op monitor interval=60s
    
pcs resource create drbd_fs Filesystem \
    device="/dev/drbd0" \
    directory="/mnt/docker-vol" \
    fstype="ext4"
    
pcs resource create nfs_server nfsserver \
    nfs_shared_infodir="/mnt/docker-vol/nfsinfo" \
    nfs_ip="192.168.10.230"
    
pcs resource create virtual_ip IPaddr2 \
    ip="192.168.10.230" \
    cidr_netmask="24"

# Configure dependencies
pcs constraint colocation add drbd_fs with drbd_resource INFINITY with-rsc-role=Master
pcs constraint order drbd_resource then drbd_fs
pcs constraint colocation add nfs_server with virtual_ip INFINITY
pcs constraint order virtual_ip then nfs_server
```

### 3. Docker Host Configuration

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker

# Configure NFS mount
mkdir -p /mnt/nfs-docker
echo "192.168.10.230:/mnt/docker-vol /mnt/nfs-docker nfs defaults,_netdev 0 0" >> /etc/fstab
mount -a

# Configure Docker daemon
cat > /etc/docker/daemon.json << EOF
{
    "data-root": "/mnt/nfs-docker/docker",
    "storage-driver": "overlay2"
}
EOF

# Restart Docker
systemctl restart docker
```

## Monitoring and Maintenance

### Useful Commands

```bash
# DRBD cluster status
drbdadm status docker-vol

# Pacemaker cluster status
pcs status

# Verify NFS mounts
showmount -e 192.168.10.230

# Docker status
docker info
docker system df
```

### Maintenance Procedures

```bash
# Cluster maintenance mode
pcs cluster standby node1

# Manual DRBD synchronization
drbdadm invalidate docker-vol

# Configuration backup
pcs config backup cluster-backup.tar.bz2
```

## Troubleshooting

### Common Issues

1. **DRBD Split-brain**: Check network connectivity and resolve manually
2. **NFS Mount Failure**: Verify permissions and NFS exports
3. **Stuck Pacemaker Resources**: Clean resources with `pcs resource cleanup`

### Important Logs

```bash
# DRBD logs
journalctl -u drbd

# Pacemaker logs
journalctl -u pacemaker

# Docker logs
journalctl -u docker
```

---

*For platform-specific installation instructions, see the dedicated guides in the docs/ directory.*

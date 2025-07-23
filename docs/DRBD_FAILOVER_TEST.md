# DRBD Failover Testing with WebApp

This guide covers how to test DRBD failover functionality with an active WebApp running on Docker with NFS storage.

## Prerequisites

- DRBD cluster properly configured and running
- Docker WebApp deployed using NFS storage
- Both nodes in the DRBD cluster operational

## Testing Procedure

### 1. Initial State Verification

Before starting the failover test, verify the current state:

```bash
# Check DRBD status
drbdadm status

# Check Pacemaker cluster status
pcs status

# Check NFS service status
systemctl status nfs-server

# Verify WebApp is accessible
curl http://your-node-ip
```

### 2. Simulate Primary Node Failure

There are several ways to simulate a node failure:

#### Option A: Graceful shutdown
```bash
# On the primary node
sudo shutdown -h now
```

#### Option B: Network disconnection
```bash
# Disconnect network interface (replace eth0 with your interface)
sudo ip link set eth0 down
```

#### Option C: Force DRBD disconnect
```bash
# Force DRBD to disconnect from peer
drbdadm disconnect all
```

### 3. Monitor Failover Process

On the secondary node, monitor the failover:

```bash
# Watch cluster status in real-time
watch -n 2 "pcs status"

# Monitor DRBD status
watch -n 2 "drbdadm status"

# Check NFS service
systemctl status nfs-server

# Verify Docker containers are still running
docker ps
```

### 4. Verify WebApp Continuity

During and after failover:

```bash
# Test WebApp accessibility
curl http://secondary-node-ip

# Check NFS mount is still active
df -h | grep nfs

# Verify data integrity
ls -la /mnt/nfs-docker/my-webapp/
```

### 5. Expected Results

After successful failover:

- Secondary node becomes primary
- NFS service continues running on new primary
- WebApp remains accessible with no data loss
- All Docker containers maintain their state

### 6. Recovery Testing

When the failed node comes back online:

```bash
# Check DRBD sync status
drbdadm status

# Monitor cluster reintegration
pcs status

# Verify both nodes are operational
pcs node status
```

### 7. Troubleshooting

If failover doesn't work as expected:

```bash
# Check logs
journalctl -u drbd
journalctl -u pacemaker
journalctl -u nfs-server

# Verify resource configuration
pcs resource show

# Check DRBD configuration
drbdadm dump all
```

## Success Criteria

A successful failover test should demonstrate:

1. ✅ Automatic detection of primary node failure
2. ✅ Secondary node promotes to primary within 30 seconds
3. ✅ NFS service continues without interruption
4. ✅ WebApp remains accessible throughout the process
5. ✅ No data loss or corruption
6. ✅ Automatic reintegration when failed node returns

## Notes

- Document the time it takes for failover to complete
- Test different failure scenarios (network, power, service crash)
- Verify failback functionality works correctly
- Consider testing under load for more realistic scenarios

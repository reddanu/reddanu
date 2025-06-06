# AKS Monitoring Cron Job - Quick Setup Guide

## Server Details
- **Host**: `rh01dv-kpt001.chrobinson.com`
- **User**: `reddanupa`
- **Script Path**: `/home/chrobinson.com/reddanupa/monitor-aks-clusters.sh`
- **Azure CLI**: `/home/linuxbrew/.linuxbrew/bin/az`

## Cron Configuration

### File: `/etc/cron.d/monitor-aks-clusters`
```bash
# Set PATH to include Azure CLI
PATH=/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin

# Run at 7:30 AM CST
30 7 * * * reddanupa /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh > /var/log/aks-monitor-cst.log 2>&1

# Run at 8:00 AM Poland time
0 8 * * * reddanupa /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh > /var/log/aks-monitor-poland.log 2>&1
```

## Setup Commands
```bash
# 1. Copy script to server
scp monitor-aks-clusters.sh reddanupa@rh01dv-kpt001.chrobinson.com:~/

# 2. SSH to server
ssh reddanupa@rh01dv-kpt001.chrobinson.com

# 3. Make executable
chmod +x monitor-aks-clusters.sh

# 4. Create cron job
sudo nano /etc/cron.d/monitor-aks-clusters
# (paste configuration above)

# 5. Set permissions
sudo chmod 644 /etc/cron.d/monitor-aks-clusters

# 6. Restart cron service
sudo systemctl restart crond
```

## Testing
```bash
# Test script directly
./monitor-aks-clusters.sh

# Test with cron environment
env -i HOME=/home/chrobinson.com/reddanupa PATH=/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin ./monitor-aks-clusters.sh

# Check cron logs
sudo tail -f /var/log/cron

# Check execution logs
tail -f /var/log/aks-monitor-cst.log
tail -f /var/log/aks-monitor-poland.log
```

## Key Points
- **System-wide cron**: Visible to all users
- **Critical PATH**: Must include `/home/linuxbrew/.linuxbrew/bin` for Azure CLI
- **Service name**: `crond` (not `cron`) on RHEL systems
- **Log files**: Separate logs for each scheduled run
- **Times**: 7:30 AM CST and 8:00 AM Poland time daily
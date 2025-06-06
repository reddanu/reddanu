# AKS Monitoring Cron Job Setup Documentation

## Overview
This document provides detailed instructions on how we configured the AKS monitoring script as a system-wide cron job on the remote server `rh01dv-kpt001.chrobinson.com`. The setup allows the script to run automatically at scheduled times and be visible to all users who log into the system.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Server Environment](#server-environment)
3. [Script Configuration](#script-configuration)
4. [Cron Job Setup](#cron-job-setup)
5. [Testing and Verification](#testing-and-verification)
6. [Monitoring and Logs](#monitoring-and-logs)
7. [Troubleshooting](#troubleshooting)
8. [Maintenance](#maintenance)

## Prerequisites
- SSH access to the remote server `rh01dv-kpt001.chrobinson.com`
- User account: `reddanupa` with sudo privileges
- Azure CLI installed and configured on the remote server
- The AKS monitoring script (`monitor-aks-clusters.sh`)

## Server Environment

### Remote Server Details
- **Hostname**: `rh01dv-kpt001.chrobinson.com`
- **User**: `reddanupa`
- **Home Directory**: `/home/chrobinson.com/reddanupa`
- **Operating System**: RHEL-based Linux (uses `crond` service)
- **Cron Service**: `crond.service` (not `cron.service`)

### Azure CLI Installation
The Azure CLI is installed via Linuxbrew and located at:
```bash
/home/linuxbrew/.linuxbrew/bin/az
```

This location is crucial for the cron job PATH configuration.

## Script Configuration

### Script Location
The monitoring script is located at:
```bash
/home/chrobinson.com/reddanupa/monitor-aks-clusters.sh
```

### Script Permissions
The script has been made executable:
```bash
chmod +x /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh
```

### Script Features
- Monitors multiple Azure subscriptions for AKS cluster health
- Checks both cluster and nodepool status
- Sends notifications to Microsoft Teams via Power Automate webhook
- Generates detailed failure reports
- Logs all activities with timestamps

## Cron Job Setup

### System-wide Cron Configuration
We configured the cron job as a system-wide job (visible to all users) by creating a file in `/etc/cron.d/`.

#### Cron Job File Location
```bash
/etc/cron.d/monitor-aks-clusters
```

#### Cron Job Configuration
```bash
# Set PATH to include Azure CLI location
PATH=/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin

# AKS Monitoring Cron Jobs
# Run at 7:30 AM CST (Central Standard Time)
30 7 * * * reddanupa /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh > /var/log/aks-monitor-cst.log 2>&1

# Run at 8:00 AM Poland time (CET/CEST)
0 8 * * * reddanupa /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh > /var/log/aks-monitor-poland.log 2>&1
```

### Key Configuration Elements

#### 1. PATH Environment Variable
```bash
PATH=/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin
```
- **Purpose**: Ensures the Azure CLI (`az` command) is available when cron runs
- **Critical**: Without this, the script fails with "Missing dependency: az"

#### 2. Schedule Times
- **7:30 AM CST**: `30 7 * * *` (Central Standard Time)
- **8:00 AM Poland Time**: `0 8 * * *` (Central European Time/Central European Summer Time)

#### 3. User Context
- **User**: `reddanupa` - The script runs under this user account
- **Important**: The user must have Azure CLI authentication configured

#### 4. Output Redirection
- **CST Run**: Output goes to `/var/log/aks-monitor-cst.log`
- **Poland Time Run**: Output goes to `/var/log/aks-monitor-poland.log`
- **Error Handling**: `2>&1` captures both stdout and stderr

### File Permissions
```bash
# Cron job file permissions
sudo chmod 644 /etc/cron.d/monitor-aks-clusters

# Log file permissions (if pre-created)
sudo chmod 666 /var/log/aks-monitor-cst.log
sudo chmod 666 /var/log/aks-monitor-poland.log
```

## Testing and Verification

### 1. Manual Script Testing
```bash
# Test script execution directly
/home/chrobinson.com/reddanupa/monitor-aks-clusters.sh

# Test with minimal environment (simulating cron)
env -i HOME=/home/chrobinson.com/reddanupa PATH=/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh
```

### 2. Cron Service Verification
```bash
# Check cron service status
sudo systemctl status crond

# Restart cron service to pick up changes
sudo systemctl restart crond

# View cron job file
cat /etc/cron.d/monitor-aks-clusters
```

### 3. Temporary Testing (Optional)
For immediate testing, you can temporarily add a test job that runs every minute:
```bash
# Edit the cron file
sudo nano /etc/cron.d/monitor-aks-clusters

# Add temporary test line
* * * * * reddanupa /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh > /var/log/aks-monitor-test.log 2>&1

# Wait a minute, then check
cat /var/log/aks-monitor-test.log

# Remove the test line after verification
```

## Monitoring and Logs

### Log Locations
- **Cron System Logs**: `/var/log/cron`
- **CST Execution Logs**: `/var/log/aks-monitor-cst.log`
- **Poland Time Execution Logs**: `/var/log/aks-monitor-poland.log`

### Monitoring Commands
```bash
# Monitor cron system logs in real-time
sudo tail -f /var/log/cron

# Check recent cron activity
sudo grep CRON /var/log/cron | tail -20

# View specific execution logs
tail -f /var/log/aks-monitor-cst.log
tail -f /var/log/aks-monitor-poland.log

# Check for cron job reloads
sudo grep "monitor-aks-clusters" /var/log/cron
```

### Expected Log Entries
When working correctly, you should see entries like:
```
Jun  6 18:08:01 rh01dv-kpt001 crond[1170321]: (*system*) RELOAD (/etc/cron.d/monitor-aks-clusters)
Jun  6 07:30:01 rh01dv-kpt001 CROND[xxxxxx]: (reddanupa) CMD (/home/chrobinson.com/reddanupa/monitor-aks-clusters.sh > /var/log/aks-monitor-cst.log 2>&1)
```

## Troubleshooting

### Common Issues and Solutions

#### 1. "Missing dependency: az" Error
**Problem**: Azure CLI not found in PATH
**Solution**: Ensure PATH includes `/home/linuxbrew/.linuxbrew/bin` in the cron file

#### 2. Script Not Executing
**Problem**: Cron job not running
**Solutions**:
- Check cron service: `sudo systemctl status crond`
- Verify file permissions: `ls -l /etc/cron.d/monitor-aks-clusters`
- Check syntax: `sudo crontab -T /etc/cron.d/monitor-aks-clusters`

#### 3. Azure Authentication Issues
**Problem**: Script fails with Azure login errors
**Solutions**:
- Verify Azure CLI login: `az account show`
- Check if user `reddanupa` has proper Azure credentials
- Consider using service principal authentication

#### 4. Log Files Not Created
**Problem**: No output in log files
**Solutions**:
- Check directory permissions for `/var/log/`
- Verify cron job is actually running in system logs
- Test script execution manually

### Debugging Steps
1. **Check if cron job is loaded**:
   ```bash
   sudo grep "monitor-aks-clusters" /var/log/cron
   ```

2. **Verify Azure CLI availability**:
   ```bash
   which az
   /home/linuxbrew/.linuxbrew/bin/az
   ```

3. **Test minimal environment**:
   ```bash
   env -i PATH=/usr/bin:/bin:/home/linuxbrew/.linuxbrew/bin which az
   ```

4. **Check script syntax**:
   ```bash
   bash -n /home/chrobinson.com/reddanupa/monitor-aks-clusters.sh
   ```

## Maintenance

### Regular Maintenance Tasks

#### 1. Log Rotation
Consider setting up log rotation for the AKS monitoring logs:
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/aks-monitor

# Add content:
/var/log/aks-monitor-*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

#### 2. Monitoring the Monitors
- Regularly check that cron jobs are executing
- Verify Teams notifications are being received
- Monitor log file sizes

#### 3. Updates and Changes
When updating the script or schedule:
1. Test changes in a development environment first
2. Update the cron configuration if needed
3. Restart the crond service: `sudo systemctl restart crond`
4. Monitor logs to ensure changes work correctly

### Backup Considerations
- **Script Backup**: Keep a backup copy of the monitoring script
- **Configuration Backup**: Document or backup the cron configuration
- **Log Archival**: Consider archiving old log files

## Security Considerations

### Access Control
- The cron job runs under the `reddanupa` user account
- Log files are readable by all users (consider restricting if sensitive)
- Azure credentials are managed through Azure CLI authentication

### Network Security
- The script makes outbound calls to Azure APIs and Teams webhook
- Ensure proper firewall rules allow these connections

## Integration Details

### Teams Notifications
- **Webhook URL**: Configured in the script via `TEAMS_WEBHOOK_URL` variable
- **Power Automate**: Uses Power Automate workflow for Teams integration
- **Notification Types**: Success and failure notifications with detailed information

### Azure Subscriptions
The script monitors these hard-coded subscription IDs:
- `c15330fb-8c3c-4d94-a1b5-65b49301f316`
- `ae405cb2-5216-4c2b-8e64-3395b86e6968`
- `0e798920-6ff3-40c3-8e78-732ed0a7a008`
- `566e24ab-22dd-4d94-a98a-aca24fdfccaf`
- `72661385-c651-4789-8ce4-7b12beb93f81`
- `f4e7afe6-046e-4176-9e3b-4bb848e61372`
- `774c1334-960b-48ab-8dba-61215daa3622`

## Summary

This setup provides automated monitoring of AKS clusters across multiple Azure subscriptions with the following benefits:
- **Automated execution** at specified times (7:30 AM CST and 8:00 AM Poland time)
- **System-wide visibility** - all users can see the cron jobs
- **Comprehensive logging** with separate log files for each execution
- **Teams notifications** for immediate alerting of issues
- **Robust error handling** and detailed reporting

The configuration is production-ready and provides reliable monitoring of your AKS infrastructure with minimal maintenance requirements.
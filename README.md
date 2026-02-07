#zfs-util
A set of bash scripts and documentation provding utility ZFS functions.

## References
https://ubuntu.com/tutorials/setup-zfs-storage-pool#1-overview
https://docs.oracle.com/cd/E19253-01/819-5461/index.html

## Table of Contents
- Install
- Disk Pool Selection
- Disk Preparation
- Create Pool
- Test RAID Resilience
    - Will the go into read-only mode right away?
        - Hypothesis is resillient where loss=parity bits (2)
        - Pool will be in state of ONLINE when all working
        - Pool will be in state of DEGRADED if any devices go OFFLINE
        
- Test corruption
    
- Test Rebuilding RAID
- Destroy Pool






## Install
```sh
sudo apt install zfsutils-linux
```


## Disk Pool Selection
Recommend n disks where: 
- n = 2 ^ x + p
    - x: an integer exponent
    - p: the number of parity bits

In our case, we're going with x = 2, and p = 2; which is n = 4 + 2 = **6**

**WARNING: All the physicaal drives should be the same size.  If they are not, the pool will use the smallest drive and waste the rest.

For our "shenanigans" pool, we have 6x 64GB USB3 thumb-drives.  They are connected to a USB 2.0 7-port hub--sacrificing speed for price.

## Disk Preparation

```sh
# Before attaching pool devices, get a baseline of what devices are already attached
ls /dev/disk/by-id/ > ~/disk-by-id.pre

# Before plugging in USB hub
lsusb -vvv > lsusb.pre

# After plugging in USB hub
lsusb -vvv > lsusb.hub

# Get details about USB hub
diff lsusb.pre lsusb.hub

# Repeate after plugging in USB drive as necessary
lsusb -vvv > lsusb...

# See USB device information about drive
diff lsusb.hub lsusb...

# Get latest disk id list map
ls /dev/disk/by-id/ > disk-by-id.1

# Compare with last map
diff disk-by-id.pre disk-by-id.1 

# Repeat as necessary for n disks
```

### Device ID Map
There's a need to know which drive is which when something fails.  We 

We need to define our arrays in a repeatable so we'll be Using `/dev/disk/by-id/` because these identifiers won't change after reboot.

We've stored our list of devices/disks in two files: `DEVICES` adn `DEVICE_MAP` (in .gitignore).  It's TBD how I want to proceed.  There's two options:
1. Have human readable descriptors of drives in documentation
2. Have disk ids printed/labeled on physical drives

A quick way to generate a `DEVICES` file, if you follow the above is:
```sh
comm -13 disk-by-id.pre disk-by-id.6 > DEVICES
```


### Disk Normalization
All the drives need to be normalized and no existing partitions.  Use gparted or dd if=/dev/zero to wipe partitions on each.  Use `zero-devices.sh` to quickly do this.

```sh
dd count=1024 if=/dev/zero of=/dev/disk/by-id/[disk id]

# OR 

sudo ./zero-disks.sh
```



## Create pool

```sh
# Using -f because pool devices aren't all exactly the same size
sudo zpool create -m /mnt/shenanigans -f shenanigans raidz2 \
    /dev/disk/by-id/usb-PNY_USB_3.2.1_FD_[redacted]-0:0  \
    /dev/disk/by-id/usb-VendorCo_ProductCode_[redacted]-0:0 \
    /dev/disk/by-id/usb-VendorCo_ProductCode_[redacted]-0:0 \
    /dev/disk/by-id/usb-VendorCo_ProductCode_[redacted]-0:0  \
    /dev/disk/by-id/usb-VendorCo_ProductCode_[redacted]-0:0 \
    /dev/disk/by-id/usb-VendorCo_ProductCode_[redacted]-0:0

# This has been abstracted into create-pool.sh


# See pool status
sudo zpool status shenanigans

# Get current mountpoint
sudo zfs get mountpoint shenanigans

# Set mountpoint (remounts automatically)
sudo zfs set mountpoint=/mnt/shenanigans shenanigans

```






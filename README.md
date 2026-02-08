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
- Test corruption
- Test Rebuilding RAID
- Destroy Pool
- Testing Portability







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

## Test Subjects
```bash
# Give broader permissions (restrict as necessary)
sudo chmod 777 /mnt/shenanigans

# Generate a test control subject
dd count=1024 if=/dev/urandom of=/mnt/shenanigans/test

sha256sum test > test.sha256sum

# Or if you want to test more than one file at once
cd /mnt/shenanigans/
sha256sum * > sha256sum

# Then later check using
sha256sum -c sha256sum

```


## Test RAID Resilience
- Will the go into read-only mode right away?
    - Hypothesis is resilient where loss=parity bits (2)
    - Pool will be in state of ONLINE when all working
    - Pool will be in state of DEGRADED if any devices go OFFLINE
        
### Method
- Physically disconnect/pull a USB drive out of the hub

### Expected ZFS behavior
- The pool immediately goes **DEGRADED**
- The missing disk shows as **UNAVAIL** or **OFFLINE**
- ZFS continues serving data using parity

### How to detect
```bash
zpool status shenanigans
```

You’ll see something like:

```
state: DEGRADED
status: One or more devices has been removed.
config:
    raidz2-0
      disk1  ONLINE
      disk2  ONLINE
      disk3  ONLINE
      disk4  ONLINE
      disk5  UNAVAIL  removed
      disk6  ONLINE
```

### How to repair
Plug the disk back in, then:
```bash
zpool status shenanigans
```

You’ll see something like:

```
  pool: shenanigans
 state: ONLINE
status: One or more devices is currently being resilvered.  The pool will
	continue to function, possibly in a degraded state.
```

If the drive isn't alrady **ONLINE**:

```bash
sudo zpool online shenanigans /dev/disk/by-id/that-disk
```

If the disk comes back cleanly, no resilver is needed.

If ZFS thinks the disk is “different” (e.g., it came back with a different device path), you may need:

```bash
sudo zpool replace shenanigans old-disk-id new-disk-id
```

If enough drives are removed and not gracefully you may get into a **SUSPENDED** state.

Sometimes, even when re-inserting enough working drives, it still will stay in this state.


```
 zpool status shenanigans 
  pool: shenanigans
 state: SUSPENDED
status: One or more devices are faulted in response to IO failures.
action: Make sure the affected devices are connected, then run 'zpool clear'.
   see: https://openzfs.github.io/openzfs-docs/msg/ZFS-8000-HC
  scan: resilvered 26K in 00:00:05 with 0 errors on Sat Feb  7 15:51:26 2026
```

You can try doing this:

```
sudo zpool export -f shenanigans

sudo zpool import -f shenanigans 
```

However, this may not work.  You may need to just reboot.  Ideally you can get the pool back into the **DEGRADED** state.  If not **ONLINE**



## Test corruption
Corrupt the disk by flipping bits

#### Method
1. Offline the disk cleanly:
```bash
sudo zpool offline shenanigans /dev/disk/by-id/diskX
```
2. Move it to another machine.
3. Overwrite random sectors:
```bash
sudo dd if=/dev/urandom of=/dev/sdX bs=4K count=100 seek=4

sudo dd if=/dev/urandom of=/dev/sdX bs=4K seek=2K count=1

```
   (This corrupts 100 random blocks.)

4. Put the disk back in your ZFS machine.

#### Expected ZFS behavior
- ZFS sees the disk as ONLINE but containing **checksum errors**
- The pool stays ONLINE because RAIDZ2 can correct the bad blocks
- ZFS automatically repairs corrupted blocks during reads

#### How to detect
```bash
zpool status -v shenanigans
```

You’ll see:

```
errors: Permanent errors have been detected in the following files:
    /path/to/file1
    /path/to/file2
```

Or, if the corruption hit unused blocks, you may see:

```
READ: 0 WRITE: 0 CKSUM: 123
```

#### How to repair
Run a scrub:

```bash
sudo zpool scrub shenanigans
```

ZFS will:

- Read every block
- Detect checksum mismatches
- Repair them using parity from the good disks
- Rewrite the corrected blocks to the corrupted disk

After the scrub:

```bash
zpool status shenanigans
```

You should see:

```
scan: scrub repaired 0B in 0 days 00:10:22
```

If corruption was severe, ZFS may offline the disk automatically. Then you replace it.

---

### Corrupting FS Heades

This simulates:
- A failing disk that returns garbage
- A disk that was accidentally reused in another system
- A disk with a damaged label

#### How to test
```bash
sudo dd if=/dev/zero of=/dev/disk/by-id/diskX bs=1M count=10
```

#### Expected behavior
- ZFS sees the disk as **UNAVAIL** or **FAULTED**
- The pool goes DEGRADED
- ZFS will not trust the disk until you explicitly replace it

#### How to detect
```bash
zpool status shenanigans
```

#### How to repair
Replace the disk:

```bash
sudo zpool replace shenanigans old-disk-id /dev/disk/by-id/diskX
```

This triggers a resilver.



### Introduce silent corruption on a live disk
This is the nightmare scenario ZFS was designed for.

#### How to test
Use `hdparm` to force write cache flush issues, or use `dmsetup` to create a corruption layer. But the simplest safe method is:

```bash
sudo zpool scrub shenanigans
```

Then, while the pool is online:

```bash
sudo dd if=/dev/urandom of=/dev/disk/by-id/diskX bs=4K count=10 seek=10000
```


    
## Test Rebuilding RAID


## Benchmarking 
```bash
sudo apt install fio

# For real-time monitoring
zpool iostat -v 1 

# For monitoring any active queues
zpool iostat -q 1


# 192M chosen because another order or magnitude (power of 2) will drive calculation time longer than meeting time
fio --name=randrw --directory=/mnt/shenanigans \
    --size=192M --bs=4k --rw=randrw --direct=1 --iodepth=32

```


## Destroy Pool



# Creating a RAID10 Pool
```
sudo zpool create shenanigans \
    mirror \
        raidz0 /dev/disk/by-id/diskA /dev/disk/by-id/diskB /dev/disk/by-id/diskC \
        raidz0 /dev/disk/by-id/diskD /dev/disk/by-id/diskE /dev/disk/by-id/diskF


# OR more traditional RAID10
zpool create shenanigans \
    mirror disk1 disk2 \
    mirror disk3 disk4 \
    mirror disk5 disk6


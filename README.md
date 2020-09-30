# Ansible Pi

Playbooks for managing a Raspberry Pi 4 cluster using Ansible. 

Assumes Ansible run in a docker container, along with other tools such as `nmap`.

- [Ansible Pi](#ansible-pi)
  - [Setup a new Pi](#setup-a-new-pi)
    - [Create a microSD card with Raspbian - Mac](#create-a-microsd-card-with-raspbian---mac)
    - [Get the IP](#get-the-ip)
    - [Configure new Pi](#configure-new-pi)
  - [Setup PXE boot](#setup-pxe-boot)
    - [Pre-requisites](#pre-requisites)
    - [Test on a single host](#test-on-a-single-host)
    - [Run on all nodes](#run-on-all-nodes)
  - [High Performance Linpack](#high-performance-linpack)
    - [Test on a single host](#test-on-a-single-host-1)
    - [Build on 4 nodes](#build-on-4-nodes)

## Setup a new Pi

### Create a microSD card with Raspbian - Mac

The starting point is a blank microSD card and the latest Raspbian minimal image. Also enables ssh access.

[Copying an operating system image to an SD card using Mac OS](https://www.raspberrypi.org/documentation/installation/installing-images/mac.md)

```
diskutil list
diskutil unmountDisk /dev/disk4
cd ~/Downloads
sudo dd bs=1m if=2020-08-20-raspios-buster-armhf-lite.img of=/dev/rdisk4; sync
touch /Volumes/boot/ssh
sudo diskutil eject /dev/rdisk4
```

Boot the Pi from the microSD card.

### Get the IP

[How to Find All Hosts on Network with nmap](https://osxdaily.com/2018/07/24/find-all-hosts-network-nmap/)

```
sudo dnf -y install nmap
nmap -sn 192.168.1.0/24
```

Add the host key to your local `known_hosts` file:

```bash
ssh-keyscan -H <IP OF PI> >> ~/.ssh/known_hosts
```

Add the IP, and a hostname, to the `hosts` inventory file in the `new` group, and test it:

```
export ANSIBLE_HOST_KEY_CHECKING=False=False
ansible -i new all -u pi -m ping --ask-pass
unset ANSIBLE_HOST_KEY_CHECKING
```


### Configure new Pi

```bash
export NEW_PI_PASSWORD=$(python3 -c 'import crypt; print(crypt.crypt("<YOUR NEW PASSWORD>", crypt.mksalt(crypt.METHOD_SHA512)))')
ansible-playbook -i hosts -l new new_pi_setup.yml --ask-pass --extra-vars "new_pi_password=$NEW_PI_PASSWORD" --list-hosts
ansible-playbook -i hosts -l new new_pi_setup.yml --ask-pass --extra-vars "new_pi_password=$NEW_PI_PASSWORD" --check
ansible-playbook -i hosts -l new new_pi_setup.yml --ask-pass --extra-vars "new_pi_password=$NEW_PI_PASSWORD"
```

In `hosts` file now move all IPs from `new` to `current`.

And test reachable:

```bash
ansible -i hosts all -u pi -m ping
```

## Setup PXE boot

Based on [PXE boot a Raspberry Pi 4 from a Synology Diskstation and compare performance to microSD](https://mikejmcfarlane.github.io/blog/2020/09/12/PXE-boot-raspberry-pi-4-from-synology-diskstation#setting-up-the-raspberry-pi-to-pxe-boot)

### Pre-requisites

+ The `new_hostname` dir for each new Pi needs to exists on the Synology. And should be empty.
+ The `rpi-tftpboot` dir needs to exists on the Synology. And any previous Pi serial number dirs deleted.

### Test on a single host

```bash
ansible-playbook -i hosts -l 192.168.1.184 pxe_boot_setup.yml --check
ansible-playbook -i hosts -l 192.168.1.184 pxe_boot_setup.yml
```

### Run on all nodes

```bash
ansible-playbook -i hosts pxe_boot_setup.yml --list-hosts
ansible-playbook -i hosts pxe_boot_setup.yml
```

nb had some issues with running against multiple nodes, the bootconf.txt file was empty, so had to run the playbook individually against each failed node.

Shutdown all nodes, remove microSD cards, power on and wait a min or two, then test connectivity with:

```bash
ansible -i hosts all -u pi -m ping
```

If this fails, checkout [PXE boot a Raspberry Pi 4 from a Synology Diskstation and compare performance to microSD](https://mikejmcfarlane.github.io/blog/2020/09/12/PXE-boot-raspberry-pi-4-from-synology-diskstation#setting-up-the-raspberry-pi-to-pxe-boot)


## High Performance Linpack

Based on [High Performance Linpack for my Raspberry Pi supercomputer](https://mikejmcfarlane.github.io/blog/2020/09/17/High-Performance-Linpack-for-raspberry-pi-supercomputer) but I'm removed the custom _make_ of ATLAS to simplify the MVP automation. For more performance build ATLAS source code.

*Some changes to the code will be required if not 4 nodes, requires more automation.*

### Test on a single host

```bash
ansible-playbook -i hosts -l 192.168.1.184 hp_linpack.yml --check
ansible-playbook -i hosts -l 192.168.1.184 hp_linpack.yml
```

### Build on 4 nodes

```bash
ansible-playbook -i hosts hp_linpack.yml --list-tasks --skip-tags atlas-repo
ansible-playbook -i hosts hp_linpack.yml --skip-tags atlas-repo
```

or, if already built on one Pi

```bash
ansible-playbook -i hosts -l 'all:!192.168.1.184' hp_linpack.yml --skip-tags atlas-repo
```

To reset performance mode:

```bash
ansible -i hosts all -u pi -m shell -a "echo performance | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
```
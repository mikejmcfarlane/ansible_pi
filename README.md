      # Ansible Pi

Playbooks for managing a Raspberry Pi 4 cluster using Ansible. 

Assumes Ansible run in a docker container, along with other tools such as `nmap`.

- [Ansible Pi](#ansible-pi)
  - [Setup a new Pi as ansible master node](#setup-a-new-pi-as-ansible-master-node)
  - [Setup a new Pi for use in the cluster](#setup-a-new-pi-in-the-cluster)
    - [Create a microSD card with Raspbian - Mac](#create-a-microsd-card-with-raspbian---mac)
    - [Get the IP](#get-the-ip)
    - [Configure new Pi](#configure-new-pi)
  - [Setup PXE boot](#setup-pxe-boot)
    - [Pre-requisites](#pre-requisites)
    - [Test/run on a single host](#testrun-on-a-single-host)
    - [Run on all nodes](#run-on-all-nodes)
  - [High Performance Linpack](#high-performance-linpack)
    - [Test build on a single host](#test-build-on-a-single-host)
    - [Build on 4 nodes](#build-on-4-nodes)
    - [Run HPL tests](#run-hpl-tests)
    - [Resets and clean ups](#resets-and-clean-ups)
    
## Setup a new Pi as ansible master node

[Install the latest Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-debian)

Generate a new ssh key that will be used for the cluster and github (manually add public to GitHub)

```bash
ssh-keygen -t rsa -b 4096 -C "pi@cluster"

```

If using new master with an existing cluster, then copy the new key to all nodes:

```bash
ssh-keyscan -H <IP OF PIs in cluster> >> ~/.ssh/known_hosts
ansible-playbook -i hosts new_pi_setup.yml --tags key-copy --ask-pass
```

And test Ansible can reach all cluster nodes:

```bash
ansible -i hosts all -u pi -m ping
```

Share an NFS mount:

```bash
vi /etc/fstab
192.168.1.191:/volume1/rpi-nfs/ /nfs/rpi-nfs nfs defaults 0 0
sudo mount -a
```

## Setup a new Pi for use in the cluster

### Create a microSD card with Raspbian - Mac

The starting point is a blank microSD card and the latest Raspbian minimal image. Also enables ssh access. The new Pi needs to be connected via ethernet, not wifi which would require a direct login to the new Pi to do some initial config.

[Copying an operating system image to an SD card using Mac OS](https://www.raspberrypi.org/documentation/installation/installing-images/mac.md)

```
diskutil list
diskutil unmountDisk /dev/disk4
cd ~/Downloads
sudo dd bs=1m if=2020-08-20-raspios-buster-armhf-lite.img of=/dev/rdisk4; sync
touch /Volumes/boot/ssh
sudo diskutil eject /dev/rdisk4
```

Linux dd:

```bash
sudo mkdir -p /mnt/sda1
sudo mkdir -p /mnt/sda2
sudo dd bs=4M if=2020-08-20-raspios-buster-armhf-lite.img of=/dev/sda conv=fsync
sudo mount /dev/sda1 /mnt/sda1
sudo touch /mnt/sda1/ssh
sudo umount /mnt/sda1
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

Add the IP, and a hostname, to the `hosts` inventory file in the `new` group, and test it (default pi password is `raspberry`):

```
export ANSIBLE_HOST_KEY_CHECKING=False
ansible -i hosts new -u pi -m ping --ask-pass
unset ANSIBLE_HOST_KEY_CHECKING
```


### Configure new Pi

* Replace `<YOUR NEW PASSWORD>` *

```bash
export YOUR_NEW_PASSWORD=<YOUR NEW PASSWORD>
export NEW_PI_PASSWORD=$(python3 -c "import crypt; print(crypt.crypt('$YOUR_NEW_PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))")
ansible-playbook -i hosts -l new new_pi_setup.yml --ask-pass --extra-vars "new_pi_password=$NEW_PI_PASSWORD" --list-tasks
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

### Test/run on a single host

```bash
ansible-playbook -i hosts -l 192.168.1.184 pxe_boot_setup.yml --list-tasks
ansible-playbook -i hosts -l 192.168.1.184 pxe_boot_setup.yml
```

### Run on all nodes

```bash
ansible-playbook -i hosts pxe_boot_setup.yml --list-tasks
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

### Test build on a single host

This example builds the HPL stack based on OpenBLAS, and skips the tasks for ATLAS and ssh (which will fail for a single node)

```bash
ansible-playbook -i hosts -l 192.168.1.184 hp_linpack.yml --skip-tags atlas-repo,atlas-build,ssh --list-tasks
ansible-playbook -i hosts -l 192.168.1.184 hp_linpack.yml
```

### Build on 4 nodes

Example builds OpenBLAS and ignores ATLAS build and ATLAS from repo.

```bash
ansible-playbook -i hosts hp_linpack.yml --skip-tags atlas-repo,atlas-build --list-tasks
ansible-playbook -i hosts hp_linpack.yml --skip-tags atlas-repo,atlas-build
```

or, if already built on one Pi

```bash
ansible-playbook -i hosts -l 'all:!192.168.1.184' hp_linpack.yml --skip-tags atlas-repo,atlas-build
```

### Run HPL tests

```bash
cd ~/tmp_hpl/hpl-2.3/bin/rpi
./run_log_test_1node.sh
./run_log_test_4node.sh
```

### Resets and clean ups

To reset performance mode after a restart:

```bash
ansible -i hosts all -u pi -m shell -a "echo performance | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
```

To remove all built tools:

Archive test log:

```bash
sudo mv test.log /nfs/rpi-nfs/test_logs/test.log.<EXPERIMENT>
```

```bash
ansible -i hosts all -u pi --become -m shell -a "cd tmp_mpi/mpich-3.4a3/; sudo make arch=rpi uninstall; cd; rm -rf tmp_*"
ansible -i hosts all -u pi --become -m shell -a "sudo apt -y remove libatlas-base-dev; sudo apt -y autoremove"
ansible -i hosts all -u pi --become -m shell -a "sudo reboot"
```

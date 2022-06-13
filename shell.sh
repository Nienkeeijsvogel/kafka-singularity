 sudo setenforce 0
 sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
 swapoff -a
 sudo sed -e '/swap/s/^/#/g' -i /etc/fstab
 sudo systemctl stop firewalld
 lsmod | grep br_netfilter
 modprobe br_netfilter

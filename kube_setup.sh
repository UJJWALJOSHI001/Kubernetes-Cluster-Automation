#!/bin/bash
echo "
#########################################################
#							#
#  	  Thank you for choosing this Scirpt            #
#	  Author   ujjwal   				#
#							#
#########################################################
"
file="/var/lib/libvirt/images/kube1.qcow2"
if [ -f "$file" ]
then 	
		echo "$file found."
else 	
		wget ftp://192.168.10.254/pub/kube1.qcow2  -O /var/lib/libvirt/images/kube1.qcow2
fi

#down and delete
virsh  destroy  master
virsh  destroy  node1
virsh  destroy  node2
virsh  destroy  registry
virsh  undefine   master
virsh  undefine   node1
virsh  undefine   node2 
virsh  undefine   registry

# removing  snapshost
rm  -vrf  /var/lib/libvirt/images/master.qcow2
rm  -vrf  /var/lib/libvirt/images/node1.qcow2
rm  -vrf  /var/lib/libvirt/images/node2.qcow2
rm  -vrf  /var/lib/libvirt/images/registry.qcow2

# creating again 
qemu-img create -f qcow2 -b  /var/lib/libvirt/images/kube1.qcow2  /var/lib/libvirt/images/master.qcow2
qemu-img create -f qcow2 -b  /var/lib/libvirt/images/kube1.qcow2  /var/lib/libvirt/images/node1.qcow2
qemu-img create -f qcow2 -b  /var/lib/libvirt/images/kube1.qcow2  /var/lib/libvirt/images/node2.qcow2
qemu-img create -f qcow2 -b  /var/lib/libvirt/images/kube1.qcow2  /var/lib/libvirt/images/registry.qcow2

#  booting  vms
virt-install --name master --ram 4096  --vcpu 2 --noautoconsole  --disk path=/var/lib/libvirt/images/master.qcow2 --import  --os-type linux --os-variant=rhel7
sleep 8

virt-install --name node1 --ram 1500  --vcpu 1 --noautoconsole --disk path=/var/lib/libvirt/images/node1.qcow2  --import   --os-type linux --os-variant=rhel7
sleep 8

virt-install --name node2 --ram 1500   --vcpu 1 --noautoconsole --disk path=/var/lib/libvirt/images/node2.qcow2   --import  --os-type linux --os-variant=rhel7
sleep 8

virt-install --name registry --ram 1000  --vcpu 1 --noautoconsole --disk path=/var/lib/libvirt/images/registry.qcow2   --import  --os-type linux --os-variant=rhel7
sleep 15

### install some packages #######

yum remove epel-release -y
cat <<X  >/etc/yum.repos.d/ku.repo
[ku]
baseurl=ftp://192.168.10.254/pub/rhel7rpm
gpgcheck=0
X

yum install epel-release -y
yum install arp-scan -y

##greping ips
m=`virsh dumpxml master | grep -i  'mac address' | cut -d"'" -f2`
master=`arp-scan -q -l | grep  "$m" | awk '{print $1}'`
echo $master

 
n=`virsh dumpxml node1 | grep -i  'mac address' | cut -d"'" -f2`
node1=`arp-scan -q -l | grep  "$n" | awk '{print $1}'`
echo $node1
 
 
o=`virsh dumpxml node2 | grep -i  'mac address' | cut -d"'" -f2`
node2=`arp-scan -q -l | grep  "$o" | awk '{print $1}'`
echo $node2
 
p=`virsh dumpxml registry | grep -i  'mac address' | cut -d"'" -f2`
registry=`arp-scan -q -l | grep "$p" | awk '{print $1}'`
echo $registry


yum install sshpass -y
echo "
#############################################################################   
#        Your kubernetes CLuster  is being ready in some times ,            #
#									    #
#        Ignore if some errors you see while installing Like                #
#              COMMAND NOT FOUND, MSSING COMMAND                            #
# 								            #
#############################################################################
"
##setting hostname

`sshpass -p 'redhat'  ssh  -t  -o  StrictHostKeyChecking=no $master   'hostnamectl set-hostname master.example.com'`
sleep 2
`sshpass -p 'redhat'  ssh  -t  -o  StrictHostKeyChecking=no $node1    'hostnamectl set-hostname  node1.example.com'`
sleep 2
`sshpass -p 'redhat'  ssh  -t  -o  StrictHostKeyChecking=no $node2    'hostnamectl set-hostname node2.example.com'`
sleep 2
`sshpass -p 'redhat'  ssh  -t  -o  StrictHostKeyChecking=no $registry 'hostnamectl set-hostname registry.example.com'`
sleep 2
	
##ENtry in hosts file 
a=`sshpass -p 'redhat'  ssh  -o  StrictHostKeyChecking=no $master   'echo " '$master' master  master.example.com " >> /etc/hosts  ; echo  " '$node1' node1 node1.example.com " >> /etc/hosts  ; echo " '$node2' node2 node2.example.com "  >> /etc/hosts ; echo " '$registry'  registry registry.example.com "  >> /etc/hosts'`
echo $a
 
####chaging entry of base machine host file  ##########
`echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6"   >/etc/hosts`

# hosts entry in base machine #######
`echo " $master master master.example.com " >>/etc/hosts ; echo " $node1 node1 node1.example.com " >>/etc/hosts ; echo " $node2 node2 node2.example.com " >>/etc/hosts ; echo " $registry registry registry.example.com " >>/etc/hosts `
 
 
##sending hosts file entry
`sshpass -p 'redhat' scp -o StrictHostKeyChecking=no   /etc/hosts   root@master:/etc/`
`sshpass -p 'redhat' scp -o StrictHostKeyChecking=no   /etc/hosts   root@node1:/etc/`
`sshpass -p 'redhat' scp -o StrictHostKeyChecking=no   /etc/hosts   root@node2:/etc/`
`sshpass -p 'redhat' scp -o StrictHostKeyChecking=no   /etc/hosts   root@registry:/etc/`

#### making yum for kubernetes ####
cat <<X  >/etc/yum.repos.d/main.repo
[a]
baseurl=ftp://192.168.10.254/pub/rhel75
gpgcheck=0
[b]
baseurl=ftp://192.168.10.254/pub/adhoc/kubernetes
gpgcheck=0
X
 
 
`sshpass -p 'redhat'  scp  -o  StrictHostKeyChecking=no  /etc/yum.repos.d/main.repo  root@$master:/etc/yum.repos.d/`
`sshpass -p 'redhat'  scp  -o  StrictHostKeyChecking=no  /etc/yum.repos.d/main.repo  root@$node1:/etc/yum.repos.d/`
`sshpass -p 'redhat'  scp  -o  StrictHostKeyChecking=no  /etc/yum.repos.d/main.repo  root@$node2:/etc/yum.repos.d/`
`sshpass -p 'redhat'  scp  -o  StrictHostKeyChecking=no  /etc/yum.repos.d/main.repo  root@$registry:/etc/yum.repos.d/`

###installation of software ###
q=`sshpass -p 'redhat'  ssh  $master     'yum install vim bash-completion net-tools kubectl kubeadm kubelet docker  -y'`
echo $q
w=`sshpass -p 'redhat'  ssh  $node1      'yum install vim bash-completion net-tools kubectl kubeadm kubelet docker -y'`
echo $w
e=`sshpass -p 'redhat'  ssh  $node2      'yum install vim bash-completion net-tools kubectl kubeadm kubelet docker -y'`
echo $e
r=`sshpass -p 'redhat'  ssh  $registry   'yum install vim bash-completion net-tools docker -y'`
echo $r



#### kubernetes cluster start ###########
### step 1 ###

`sshpass -p 'redhat'  ssh  $master    'setenforce 0'`
`sshpass -p 'redhat'  ssh  $node1     'setenforce 0'`
`sshpass -p 'redhat'  ssh  $node2     'setenforce 0'`


### step 2 ###
`sshpass -p 'redhat'  ssh  $master  'sed  -i   's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config'`
`sshpass -p 'redhat'  ssh  $node1   'sed  -i   's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config'`
`sshpass -p 'redhat'  ssh  $node2     'sed  -i   's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config'`


### firewall rules  ####
`sshpass -p 'redhat'  ssh  $master    'systemctl enable --now firewalld'`
`sshpass -p 'redhat'  ssh  $node1     'systemctl enable --now firewalld'`
`sshpass -p 'redhat'  ssh  $node2     'systemctl enable --now firewalld'`
`sshpass -p 'redhat'  ssh  $registry  'systemctl enable --now firewalld'`

### allowing all port ###
`sshpass -p 'redhat'  ssh  $master    'firewall-cmd --add-port=0-65535/tcp  --permanent'`
`sshpass -p 'redhat'  ssh  $node1     'firewall-cmd --add-port=0-65535/tcp  --permanent'`
`sshpass -p 'redhat'  ssh  $node2     'firewall-cmd --add-port=0-65535/tcp  --permanent'`
`sshpass -p 'redhat'  ssh  $registry  'firewall-cmd --add-port=0-65535/tcp  --permanent'`


`sshpass -p 'redhat'  ssh  $master    'firewall-cmd --add-port=0-65535/udp --permanent'`
`sshpass -p 'redhat'  ssh  $node1     'firewall-cmd --add-port=0-65535/udp --permanent'`
`sshpass -p 'redhat'  ssh  $node2     'firewall-cmd --add-port=0-65535/udp --permanent'`
`sshpass -p 'redhat'  ssh  $registry  'firewall-cmd --add-port=0-65535/udp --permanent'`

`sshpass -p 'redhat'  ssh  $master    'firewall-cmd --reload'`
`sshpass -p 'redhat'  ssh  $node1     'firewall-cmd --reload'`
`sshpass -p 'redhat'  ssh  $node2     'firewall-cmd --reload'`
`sshpass -p 'redhat'  ssh  $registry  'firewall-cmd --reload'`



####  swap memory off ##
`sshpass -p 'redhat' ssh  $master   "sed -i  '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"`
`sshpass -p 'redhat' ssh  $node1    "sed -i  '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"`
`sshpass -p 'redhat' ssh  $master   "sed -i  '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab"`

`sshpass -p 'redhat'  ssh  $master    'swapoff -a'`
`sshpass -p 'redhat'  ssh  $node1     'swapoff -a'`
`sshpass -p 'redhat'  ssh  $node2     'swapoff -a'`



##loading kernel module ####
`sshpass -p 'redhat'  ssh  $master    'modprobe br_netfilter'`
`sshpass -p 'redhat'  ssh  $node1     'modprobe br_netfilter'`
`sshpass -p 'redhat'  ssh  $node2     'modprobe br_netfilter'`

`sshpass -p 'redhat'  ssh  $master    'echo  "net.bridge.bridge-nf-call-ip6tables = 1" >>/etc/sysctl.conf'`
`sshpass -p 'redhat'  ssh  $master    'echo  "net.bridge.bridge-nf-call-iptables = 1" >>/etc/sysctl.conf'`
`sshpass -p 'redhat'  ssh  $node1     'echo  "net.bridge.bridge-nf-call-ip6tables = 1" >>/etc/sysctl.conf'`
`sshpass -p 'redhat'  ssh  $node1     'echo  "net.bridge.bridge-nf-call-iptables = 1" >>/etc/sysctl.conf'`
`sshpass -p 'redhat'  ssh  $node2     'echo  "net.bridge.bridge-nf-call-ip6tables = 1" >>/etc/sysctl.conf'`
`sshpass -p 'redhat'  ssh  $node2     'echo  "net.bridge.bridge-nf-call-iptables = 1" >>/etc/sysctl.conf'`


`sshpass -p 'redhat'  ssh  $master    'sysctl -p'`
`sshpass -p 'redhat'  ssh  $node1     'sysctl -p'`
`sshpass -p 'redhat'  ssh  $node2     'sysctl -p'`

### taking care of services  ##
`sshpass -p 'redhat'  ssh  $master    'systemctl enable --now docker ; systemctl enable kubelet'`
`sshpass -p 'redhat'  ssh  $node1     'systemctl enable --now docker ; systemctl enable kubelet'`
`sshpass -p 'redhat'  ssh  $node2     'systemctl enable --now docker ; systemctl enable kubelet'`

### making registry
`sshpass -p 'redhat'  ssh  $registry  'setenforce 0'` 
`sshpass -p 'redhat'  ssh  $registry  'systemctl enable --now docker'`
sleep 5
`sshpass -p 'redhat'  ssh  $registry  'docker pull registry'`
sleep 10
`sshpass -p 'redhat'  ssh  $registry  'docker run -d -p 5000:5000 --name myprivreg  --restart always docker.io/registry'`
sleep 8
`sshpass -p 'redhat'  ssh  $registry  'docker tag docker.io/registry  registry:5000'`
sleep 4
`sshpass -p 'redhat'  ssh  $registry  'docker pull hello-world'`
sleep 10
`sshpass -p 'redhat'  ssh  $registry  'docker tag docker.io/hello-world  registry:5000/hw'`
sleep 5


###making pull and push client####

`echo "{ "'"insecure-registries"'" : ["'"registry:5000"'"] }" | sshpass -p 'redhat' ssh $master 'cat >/etc/docker/daemon.json'`
`echo "{ "'"insecure-registries"'" : ["'"registry:5000"'"] }" | sshpass -p 'redhat' ssh $node1  'cat >/etc/docker/daemon.json'`
`echo "{ "'"insecure-registries"'" : ["'"registry:5000"'"] }" | sshpass -p 'redhat' ssh $node2  'cat >/etc/docker/daemon.json'`


`sshpass -p 'redhat'  ssh  $master   'systemctl daemon-reload'`
sleep 3
`sshpass -p 'redhat'  ssh  $node1    'systemctl daemon-reload'`
sleep 3
`sshpass -p 'redhat'  ssh  $node2    'systemctl daemon-reload'`
sleep 3


docker_service=`sshpass -p 'redhat' ssh $master   'systemctl restart docker'`
sleep 8
echo $docker_service
docker_node1=`sshpass -p 'redhat' ssh $node1   'systemctl restart docker'`
sleep 8
echo $docker_node1
docker_node2=`sshpass -p 'redhat' ssh $node2   'systemctl restart docker'`
sleep 8
echo $docker_node2


`sshpass -p 'redhat'  ssh  $master   'docker pull hello-world'`
sleep 10
`sshpass -p 'redhat'  ssh  $node1   'docker pull hello-world'`
sleep 10
`sshpass -p 'redhat'  ssh  $node2   'docker pull hello-world'`
sleep 10


`sshpass -p 'redhat' ssh $master  'docker tag hello-world  registry:5000/hwmaster'`
sleep 2
`sshpass -p 'redhat' ssh $node1   'docker tag hello-world  registry:5000/hwnode1'`
sleep 2
`sshpass -p 'redhat' ssh $node2   'docker tag hello-world  registry:5000/hwnode2'`
sleep 2


`sshpass -p 'redhat' ssh $master   'docker push registry:5000/hwmaster'`
sleep 10
`sshpass -p 'redhat' ssh $node1    'docker push registry:5000/hwnode1'`
sleep 10
`sshpass -p 'redhat' ssh $node2    'docker push registry:5000/hwnode2'`
sleep 10

#######ICONS############
yum install virt-viewer -y
`rm -rvf /script ; rm -f /root/Desktop/firefox.desktop`
`mkdir /script`
`echo "#!/bin/bash" >>/script/server.sh`
`echo "virt-manager" >>/script/server.sh`
`chmod +x /script/server.sh`

`cp /usr/share/icons/hicolor/48x48/apps/virt-viewer.png /root/Documents/`

`echo "[Desktop Entry]" >>/root/Desktop/firefox.desktop`
`echo "Version=1.0" >>/root/Desktop/firefox.desktop`
`echo "Name=Kubernetes VM" >>/root/Desktop/firefox.desktop`
`echo "Exec=/script/server.sh" >>/root/Desktop/firefox.desktop`
`echo "Icon=/root/Documents/virt-viewer.png" >>/root/Desktop/firefox.desktop`
`echo "Terminal=false" >>/root/Desktop/firefox.desktop`
`echo "Type=Application" >>/root/Desktop/firefox.desktop`
`echo "MimeType=text/html;text/xml;application/xhtml+xml;application/vnd.mozilla.xul+xml;text/mml;x-scheme-handler/http;x-scheme-handler/https;" >>/root/Desktop/firefox.desktop`
`echo "StartupNotify=true" >>/root/Desktop/firefox.desktop`
`echo "Categories=Network;WebBrowser;" >>/root/Desktop/firefox.desktop`
`echo "X-Desktop-File-Install-Version=0.23" >>/root/Desktop/firefox.desktop`

######## completion bash###########

`echo  "source <(kubectl completion bash)"      | sshpass -p 'redhat' ssh $master 'cat >>/root/.bashrc'`
`sshpass -p 'redhat' ssh $master  'source /root/.bashrc'`
`echo  "alias d='"'kubectl get deployment'"'"   | sshpass -p 'redhat'   ssh $master  'cat >>/root/.bashrc'`
`echo  "alias n='"'kubectl get nodes'"'"        | sshpass -p 'redhat'   ssh $master  'cat >>/root/.bashrc'`
`echo  "alias p='"'kubectl get pods'"'"         | sshpass -p 'redhat'   ssh $master  'cat >>/root/.bashrc'`
`echo  "alias s='"'kubectl get service'"'"      | sshpass -p 'redhat'   ssh $master  'cat >>/root/.bashrc'`


##### cluster setup command ##########
cluster=`sshpass -p 'redhat'  ssh $master  'kubeadm init --pod-network-cidr=172.24.0.0/16'`
echo $cluster
echo $cluster  > /root/output.txt
cat output.txt  | tail -c 168  > a.sh 
`sshpass -p  'redhat' scp -o StrictHostKeyChecking=no a.sh root@$node1:/root/`
`sshpass -p  'redhat' scp -o StrictHostKeyChecking=no a.sh root@$node2:/root/`
`sshpass -p  'redhat' ssh $node1 'bash /root/a.sh'`
`sshpass -p  'redhat' ssh $node2 'bash /root/a.sh'`

`sshpass -p 'redhat'  ssh $master  'mkdir /root/.kube'`
`sshpass -p 'redhat'  ssh $master  'cp -i /etc/kubernetes/admin.conf  /root/.kube/config'`
`sshpass -p 'redhat'  ssh $master  'kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml'`
`sshpass -p 'redhat'  ssh $master  'kubectl apply -f https://docs.projectcalico.org/v3.3/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml'`


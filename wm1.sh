#!/bin/bash
#check docker cmd
echo "Script version Number: v0.10.3"
which docker >/dev/null 2>&1
if  [ $? -ne 0 ] ; then
        echo "docker not found, please install first!"
        echo "ubuntu:sudo apt install docker.io -y"
        echo "centos:yum install  -y docker-ce "
        echo "fedora:sudo dnf  install -y docker-ce"
        exit
fi
#check docker service
docker ps > /dev/null 2>&1
if [ $? -ne 0 ] ; then

        echo "docker service is not running! you can use command start it:"
        echo "sudo service docker start"
        exit
fi

vt5=1670383155
vl=$(wget https://docker.wormholes.com/version>/dev/null 2>&1 && cat version|awk '{print $1}')
vr=$(cat version|awk '{print $2}' && rm version)
worm=$(docker images|grep "wormholestech/wormholes"|grep "v1")
if [ -n "$worm" ];then
        ct=$(docker inspect wormholestech/wormholes:v1 -f {{.Created}})
        cts=$(date -d "$ct" +%s)
        if [ $cts -eq $vl ];then
                container=$(docker ps -a|awk '{if($NF == "wormholes")print $0}')
                if [[ $container =~ "Up" ]];then
                        while true
                        do
                                key=$(docker exec -it wormholes /usr/bin/ls -l wm1/.wormholes/wormholes/nodekey)
                                if [ -n "$key" ];then
                                        echo -e "It is the latest version: $vr \nYour private key:"
                                        docker exec -it wormholes /usr/bin/cat .wormholes/wormholes/nodekey
                                        echo -e "\n"
                                        exit 0
                                else
                                        sleep 5s
                                fi
                        done
                elif [[ $container =~ "Exited" ]];then
                        echo -e "Your peer isn't running\nYou can use 'docker start wormholes' to start the node"
                        exit 0
                else
                        docker rm wormholes
                        read -p "Enter your private key：" ky
                fi
        elif [ $cts -lt $vl ];then
                docker stop wormholes > /dev/null 2>&1
                docker rm wormholes > /dev/null 2>&1
                docker rmi wormholestech/wormholes:v1 > /dev/null 2>&1
                if [ $cts -lt $vt5 ];then
                        if [ -f wm1/.wormholes/wormholes/nodekey ];then
                                echo "Clearing historical data ............"
                                cp wm1/.wormholes/wormholes/nodekey wm1/nodekey
                                rm -rf wm1/.wormholes
                                mkdir -p wm1/.wormholes/wormholes
                                mv wm1/nodekey wm1/.wormholes/wormholes/
                        else
                                read -p "Enter your private key：" ky
                        fi
                elif [ $cts -ge $vt5 ];then
                        if [ ! -f wm1/.wormholes/wormholes/nodekey ];then
                                read -p "Enter your private key：" ky
                        fi
                fi
        fi
else
        read -p "Enter your private key：" ky
fi

if [ -n "$ky" ]; then
        mkdir -p wm1/.wormholes/wormholes
        if [ ${#ky} -eq 64 ];then
                echo $ky > wm1/.wormholes/wormholes/nodekey
        elif [ ${#ky} -eq 66 ] && ([ ${ky:0:2} == "0x" ] || [ ${ky:0:2} == "0X" ]);then
                echo ${ky:2:64} > wm1/.wormholes/wormholes/nodekey
        else
                echo "the nodekey format is not correct"
                exit 1
        fi
fi

docker run -id -p 30303:30303 -p 8545:8545 -v wm1/.wormholes:wm1/.wormholes --name wormholes wormholestech/wormholes:v1 >/dev/null 2>&1 &

while true
do
        s=$(docker ps -a|grep "Up"|awk '{if($NF == "wormholes") print $NF}'|wc -l)
        key=$(docker exec -it wormholes /usr/bin/ls -l wm1/.wormholes/wormholes/nodekey 2>/dev/null)
        if [[ $s -gt 0 ]] && [[ "$key" =~ "nodekey" ]];then
                echo "Your private key is:"
                docker exec -it wormholes /usr/bin/cat wm1/.wormholes/wormholes/nodekey
                echo -ne "\n"
                docker exec -it wormholes ./wormholes version|grep "Version"|grep -v go
                break
        else
                sleep 5s
        fi
done
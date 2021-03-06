# Tunneling

    ssh -L 5454:instance_ip:80 devstack_ip
    
    or
    
    iptables -t nat -A PREROUTING  -p tcp --dport 1234 -j DNAT --to-destination 10.0.0.2:80 (on the Devstack domU)
    
    view with iptables -t nat -L PREROUTING

# The Movie

    mplayer http://localhost:5454/trailer_480p.mov
    mplayer http://localhost:5454/the-xen-movie.mp4
    mplayer -cache 8192 http://10.219.4.132:1235/the-xen-movie.mp4

# The image

    http://copper.eng.hq.xensource.com/havana-demo/streamer.vhd.tgz

## To save it

    glance image-download --file streamer.vhd.tgz 068b1798-374f-452d-99e7-f8f7bf7b5d39
    scp streamer.vhd.tgz ubuntu@copper.eng.hq.xensource.com:/usr/share/nginx/www/havana-demo/

## To load it

    glance image-create \
        --disk-format=vhd \
        --container-format=ovf \
        --copy-from=http://copper.eng.hq.xensource.com/havana-demo/streamer-coalesced.vhd.tgz \
        --is-public=True \
        --name=streamer

## To start it

    nova boot --flavor m1.medium --image streamer bunnyvm

## Resize

    tar -xzf streamer.vhd.tgz
    vhd-util modify -n 0.vhd -p 1.vhd
    vhd-util modify -n 1.vhd -p 2.vhd
    vhd-util coalesce -n 0.vhd
    vhd-util resize -n 2.vhd -s $(vhd-util query -n 1.vhd -v) -j jounral
    vhd-util coalesce -n 1.vhd
    rm 0.vhd 1.vhd
    mv 2.vhd 0.vhd
    vhd-util set -f hidden -v 0 -n 0.vhd
    tar -czf streamer-coalesced.vhd.tgz 0.vhd

## SSH keypair

    ssh-keygen -f somekey.priv -N "" -t rsa
    nova keypair-add --pub-key somekey.priv.pub demo-keypair


    glance image-create \
        --disk-format=vhd \
        --container-format=ovf \
        --copy-from=http://copper.eng.hq.xensource.com/havana-demo/centos.tgz \
        --is-public=True \
        --name=centos

    nova boot --flavor m1.tiny --image tarred tarred

## Proxy

    sudo apt-get -qy install simpleproxy
    simpleproxy -d -L 1235 -R 10.0.0.2:80

#!/bin/bash
if [ ! -d /home/vagrant/hamwerk ]; then
    sudo apt-get install -y curl
    curl https://install.meteor.com | sudo sh
    cd /home/vagrant
    su vagrant -c 'meteor create hamwerk'
    cd hamwerk
    su vagrant -c 'meteor add coffeescript less jquery backbone accounts-password accounts-ui appcache amplify'
    su vagrant -c 'meteor remove autopublish insecure'
    cd /vagrant/hamwerk
    rm -vrf .meteor
    mkdir .meteor
    echo "sudo mount --bind /home/vagrant/hamwerk/.meteor/ /vagrant/hamwerk/.meteor/" >> /home/vagrant/.bashrc
fi

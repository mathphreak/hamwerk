#!/bin/bash
if [ ! -d /home/vagrant/homework ]; then
    sudo apt-get install -y curl
    curl https://install.meteor.com | sudo sh
    cd /home/vagrant
    su vagrant -c 'meteor create homework'
    su vagrant -c 'meteor add coffeescript less bootstrap backbone'
    su vagrant -c 'meteor remove autopublish'
    cd /vagrant/homework
    rm -vrf .meteor
    mkdir .meteor
    echo "sudo mount --bind /home/vagrant/homework/.meteor/ /vagrant/homework/.meteor/" >> /home/vagrant/.bashrc
fi
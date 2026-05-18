#!/bin/bash

reinicio(){
sudo systemctl restart bind9
sudo systemctl enable bind9
}
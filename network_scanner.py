#!/usr/bin/env python

import scapy.all as scapy

def scan(ip):
	# scapy.arping(ip)
    arp_request = scapy.ARP(pdst=ip)
    broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")
    arp_request_broadcast = broadcast/arp_request   # put ARP packet inside Ethernet-frame
    answered_list = scapy.srp(arp_request_broadcast, timeout=1)[0]
	
    for element in answered_list:
        print(element)
        print("-----------------------------------")
    


scan("192.168.1.1/24")

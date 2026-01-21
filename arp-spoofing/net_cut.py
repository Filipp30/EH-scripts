#!/usr/bin/env python

import netfilterqueue

def process_packet(pkt):
    print(pkt)
    pkt.drop()

# iptables -I FORWARD -j NFQUEUE --queue-num 0
queue = netfilterqueue.NetfilterQueue()
queue.bind(0, process_packet)
queue.run()


#!/usr/bin/env python

import subprocess
import optparse
import re

def get_arguments():
    parser = optparse.OptionParser()
    parser.add_option("-i", "--interface", dest="interface", help="Interface to change its MAC address")
    parser.add_option("-m", "--mac", dest="new_mac", help="new MAC-address")
    (options, arguments) = parser.parse_args()
    if not options.interface:
        parser.error("Please specify an interface")
    elif not options.new_mac:
        parser.error("Please specify an mac-address")
    return options

def change_mac(i, m):
    subprocess.call(["ifconfig", i, "down"])
    subprocess.call(["ifconfig", i ,"hw", "ether", m])
    subprocess.call(["ifconfig", i, "up"])

def get_current_mac_address(interface):
    ifconfig_result = subprocess.check_output(["ifconfig", interface]).decode("utf-8")
    mac_address_search_result = re.search(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", ifconfig_result)
    if mac_address_search_result:
        return mac_address_search_result.group(0)
    else:
        print("Could not read MAC address.")


options = get_arguments()
current_mac = get_current_mac_address(options.interface)
print("Current MAC address: " + str(current_mac))

change_mac(options.interface, options.new_mac)

current_mac = get_current_mac_address(options.interface)
if current_mac == options.new_mac:
    print("MAC address changed to " + current_mac)
else:
    print("Could not change MAC address.")
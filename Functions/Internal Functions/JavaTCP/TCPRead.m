function Message = TCPRead(IP, Port)

import java.net.Socket
import java.net.InetSocketAddress
import java.io.*
%output_socket = Socket(IP, Port);

input_socket = Socket;
Address = InetSocketAddress(IP, Port);
input_socket.connect(Address, 2000);
input_stream   = input_socket.getInputStream;
d_input_stream = DataInputStream(input_stream);
bytes_available = input_stream.available;
Message = zeros(1, bytes_available, 'uint8');
for i = 1:bytes_available
    Message(i) = d_input_stream.readByte;
end

Message = char(Message);
d_input_stream.close;
input_socket.close;
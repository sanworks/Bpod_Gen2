function Message = TCPWrite(IP, Port, Message)

import java.net.Socket
import java.net.InetSocketAddress
import java.io.*
Message = sprintf('%s\n',Message);
%output_socket = Socket(IP, Port);

output_socket = Socket;
Address = InetSocketAddress(IP, Port);
output_socket.connect(Address, 2000);

output_stream   = output_socket.getOutputStream;
d_output_stream = DataOutputStream(output_stream);
d_output_stream.writeBytes(Message);  % Send the encoded string to the server
pause(.1);
input_stream   = output_socket.getInputStream;
d_input_stream = DataInputStream(input_stream);
bytes_available = input_stream.available;
Message = zeros(1, bytes_available, 'uint8');
for i = 1:bytes_available
    Message(i) = d_input_stream.readByte;
end

Message = char(Message);
d_input_stream.close;
d_output_stream.close;
output_socket.close;

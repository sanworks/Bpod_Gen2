function varargout = BpodSocketServer(op, varargin)
import java.net.ServerSocket
import java.io.*
global BpodSystem
switch op
    case 'connect'
        %        try
        Port = varargin{1};
        server_socket  = [];
        output_socket  = [];
        BpodSystem.BonsaiSocket.server_socket = ServerSocket(Port);
        BpodSystem.BonsaiSocket.server_socket.setSoTimeout(10000);
        disp('Attempting to initialize socket server...');
        BpodSystem.BonsaiSocket.Socket = BpodSystem.BonsaiSocket.server_socket.accept;
        disp('Connected to client.');
        BpodSystem.BonsaiSocket.output_stream = BpodSystem.BonsaiSocket.Socket.getOutputStream;
        BpodSystem.BonsaiSocket.d_output_stream = DataOutputStream(BpodSystem.BonsaiSocket.output_stream);
        BpodSystem.BonsaiSocket.input_stream = BpodSystem.BonsaiSocket.Socket.getInputStream;
        BpodSystem.BonsaiSocket.input_streamreader = BufferedReader(InputStreamReader(BpodSystem.BonsaiSocket.Socket.getInputStream)); 
    case 'read'
        nBytes = varargin{1};
        Message = uint8(zeros(1,nBytes));
        for x = 1:nBytes
            Message(x) = BpodSystem.BonsaiSocket.input_streamreader.read();
        end
        varargout{1} = Message;
    case 'write'
        BpodSystem.BonsaiSocket.d_output_stream.writeBytes(char(varargin{1}));
    case 'bytesAvailable'
        varargout{1} = BpodSystem.BonsaiSocket.input_stream.available();
    case 'close'
        if isfield(BpodSystem.BonsaiSocket, 'server_socket')
            if ~isempty(BpodSystem.BonsaiSocket.server_socket)
                BpodSystem.BonsaiSocket.server_socket.close;
            end
        end
        if isfield(BpodSystem.BonsaiSocket, 'output_socket')
            if ~isempty(BpodSystem.BonsaiSocket.output_socket)
                BpodSystem.BonsaiSocket.output_socket.close;
            end
        end
end

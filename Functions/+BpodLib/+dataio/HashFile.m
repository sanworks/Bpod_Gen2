function hash = HashFile(filename)
%HashFile - Compute the hash of a file with MD5
%  HASH = HashFile(filename)
%  The hash is returned as a string of hexadecimal digits computed using the MD5 message-digest algorithm.
%  In windows the MD5 hash can be found with the command `certutil -hashfile filename MD5`.
%
%  See also BpodLib.external.DataHash.DataHash.

%  This function requires the DataHash function by Jan Simon.
%  MATLAB FEX: http://www.mathworks.com/matlabcentral/fileexchange/31272
%  The DataHash function is distributed under the BSD license.

hash = BpodLib.external.DataHash.DataHash(filename, 'file');

end
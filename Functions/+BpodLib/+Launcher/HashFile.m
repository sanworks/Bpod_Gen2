function hash = hashfile(filename)
% HASHFILE - Compute the hash of a file
%  HASH = HASHFILE(FILENAME) computes the hash of the file FILENAME.
%  The hash is returned as a string of hexadecimal digits.
%  The hash is computed using the MD5 message-digest algorithm.
%  This function requires the DataHash function by Jan Simon.
%  The DataHash function can be downloaded from the MATLAB Central File
%  Exchange: http://www.mathworks.com/matlabcentral/fileexchange/31272
%  The DataHash function is distributed under the BSD license.
%  This function is distributed under the BSD license.
%  See also DataHash.


hash = BpodLib.External.DataHash.DataHash(filename, 'file');

end
%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function BpodSMS(op, varargin)
% BpodSMS allows Bpod to send you notifications via text message (SMS).
% This version of BpodSMS only works in the United States.
% 
% Here's how to use it:
% 1. Setup BpodSMS with a Gmail account. MATLAB will send SMS messages FROM
% this email address, to the appropriate cellular carrier. Your password 
% will be stored in plain-text, so you are advised to create a dedicated
% Gmail account for your Bpod notifications only.
% 
% BpodSMS('Setup', 'MyAddress@gmail.com', 'MyPassword')
%
% 2. Register a new user in the BpodSMS phone directory. The user will be 
% known to BpodSMS by a user alias. The user's cell phone number and
% cellular carrier must be entered as character strings.
%
% BpodSMS('Register', 'MyAlias', 'MyCellphoneNumber', 'MyCellularCarrier')
%
% 3. Send a text message
%
% BpodSMS('Send', 'MyAlias', 'MyMessage - e.g. Session Complete!!')
%
% 4. When someone leaves the lab, keep the directory clean by removing 
% unused entries
%
% BpodSMS('Unregister', 'MyAlias')
%
global BpodSystem
DirectoryPath = fullfile(BpodSystem.BpodPath, 'Functions', 'Plugins', 'BpodSMS', 'SMSDirectory.mat');
SettingsPath = fullfile(BpodSystem.BpodPath, 'Functions', 'Plugins', 'BpodSMS', 'SMSSettings.mat');
if exist(DirectoryPath)
    load(DirectoryPath);
    nEntries = size(Directory, 1);
else
    Directory = cell(1,3);
    nEntries = 0;
end
if exist(SettingsPath)
    load(SettingsPath);
else
    Settings = struct;
    Settings.GmailAddress = [];
    Settings.PW = [];
end

switch lower(op)
    case 'setup'
        GmailAddress = varargin{1};
        Password = varargin{2};
        if isempty(strfind(GmailAddress, 'gmail.com'))
            error('Error: You must use a valid Gmail address.')
        end
        Settings.GmailAddress = GmailAddress;
        Settings.PW = Password;
        save(SettingsPath, 'Settings');
        disp('BpodSMS setup completed.');
    case 'register'
        Alias = varargin{1};
        PhoneNumber = varargin{2};
        if (PhoneNumber(1) == '+') || (PhoneNumber(1) == '0')
            error('Error: This version of BpodSMS only works with U.S. cellular carriers.')
        end
        Carrier = varargin{3};
        Matches = strcmp(Directory(:,1), Alias);
        if sum(Matches) > 0
            error(['Error: The name ' Directory{find(Matches), 1} ' is already registered, with cellular number: ' Directory{find(Matches), 2} '. Please unregister first.'])
        end
        PhoneNumber = PhoneNumber(uint8(PhoneNumber)>47 & uint8(PhoneNumber) < 58);
        if length(PhoneNumber) ~= 10
            error('Error: Please enter a 10-digit cellular phone number, area code first.')
        end
        Matches = strcmp(Directory(:,2), PhoneNumber);
        if sum(Matches) > 0
            error(['Error: This number is already registered to ' Directory{find(Matches), 1} '. Please unregister first.'])
        end
        ValidCarriers = {'tmobile', 't-mobile', 't mobile', 'at&t', 'att', 'verizon', 'sprint', 'virgin', 'virgin mobile', 'boost','boost mobile', 'altel','alltel', 'us','us cellular','u.s. cellular'};
        ValidCarrier = sum(strcmpi(ValidCarriers, Carrier));
        if ~ValidCarrier
            error('Error: Invalid carrier specified. Valid carriers are: Verizon, Tmobile, AT&T, Sprint, Virgin Mobile, Boost Mobile, Altel, US Cellular')
        end
        Directory(nEntries+1,:) = {Alias, PhoneNumber, Carrier};
        save(DirectoryPath, 'Directory');
        disp(['User ' Alias ' added successfully.'])
    case 'unregister'
        Alias = varargin{1};
        UserIndex = find(strcmp(Directory(:,1), Alias));
        if ~isempty(UserIndex)
            RemainingIndexes = 1:nEntries;
            RemainingIndexes = RemainingIndexes(RemainingIndexes ~= UserIndex);
            Directory = Directory(RemainingIndexes,:);
            save(DirectoryPath, 'Directory');
            disp(['User ''' Alias ''' removed successfully.'])
        else
            error(['Error: User ''' Alias ''' not found.'])
        end
    case 'send'
        Alias = varargin{1};
        Message = varargin{2};
        UserIndex = find(strcmp(Directory(:,1), Alias));
        if isempty(Settings.GmailAddress)
            error('BpodSMS must be set up with a Gmail account. Use BpodSMS(''Setup'',...)')
        end
        if isempty(UserIndex)
            error(['User ''' Alias ''' not found. Use BpodSMS(''Register'', ...) first.'])
        end
        CellNumber = Directory{UserIndex,2};
        CellCarrier = lower(Directory{UserIndex,3});
        Connected = checkConnectivity;
        if ~Connected
            error('BpodSMS cannot connect to the Internet. Please verify that your computer has a live Internet connection, and that MATLAB is not firewalled.')
        end
        OriginalPrefs = 0;
        if ~isempty(getpref('Internet'))
            % Store user original preferences
            OriginalPrefs = 1;
            OldSMTP = getpref('Internet','SMTP_Server');
            OldEmail = getpref('Internet','E_mail');
            OldUsername = getpref('Internet','SMTP_Username');
            OldPW = getpref('Internet','SMTP_Password');
        end
        setpref('Internet','SMTP_Server','smtp.gmail.com');
        setpref('Internet','E_mail',Settings.GmailAddress);
        setpref('Internet','SMTP_Username',Settings.GmailAddress);
        setpref('Internet','SMTP_Password',Settings.PW);
        props = java.lang.System.getProperties;
        props.setProperty('mail.smtp.auth','true');
        props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
        props.setProperty('mail.smtp.socketFactory.port','465');
        switch CellCarrier
            case {'att', 'at&t'}
                EmailAddress = [CellNumber '@txt.att.net'];
            case 'verizon'
                EmailAddress = [CellNumber '@vtext.com'];
            case {'tmobile','t-mobile','t mobile'}
                EmailAddress = [1 CellNumber '@tmomail.net'];
            case 'sprint'
                EmailAddress = [CellNumber '@messaging.sprintpcs.com'];
            case {'virgin','virgin mobile'}
                EmailAddress = [1 CellNumber '@vmobl.com'];
            case {'boost','boost mobile'}
                EmailAddress = [1 CellNumber '@sms.myboostmobile.com'];
            case {'altel','alltel'}
                EmailAddress = [1 CellNumber '@sms.alltelwireless.com'];
            case {'us','us cellular','u.s. cellular'}
                EmailAddress = [1 CellNumber '@email.uscc.net'];
            otherwise
                error('Invalid cellular carrier registered. This should not be possible. Please contact Sanworks to report this bug.')
        end
        sendmail(EmailAddress,'Bpod Notification: ', Message);
        if OriginalPrefs == 1
            % Restore user preferences
            setpref('Internet','SMTP_Server',OldSMTP);
            setpref('Internet','E_mail',OldEmail);
            setpref('Internet','SMTP_Username',OldUsername);
            setpref('Internet','SMTP_Password',OldPW);
        end
    otherwise
        error('Invalid op argument. Valid ops are: Setup, Register, Unregister, Send');
end

function connected = checkConnectivity()

% define the URL for US Naval Observatory Time page
url =java.net.URL('http://time.gov');

% read the URL
try
link = openStream(url);
parse = java.io.InputStreamReader(link);
snip = java.io.BufferedReader(parse);
if ~isempty(snip)
    connected = 1;
else
    connected = 0;
end
catch
    connected = 0;
end

return
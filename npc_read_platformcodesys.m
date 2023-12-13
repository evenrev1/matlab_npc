function [content,msg,status] = npc_read_platformcodesys(platform,request,date)
% NPC_READ_PLATFORMCODESYS	Reads info from NMDreference:platformcodesys
% 
% [content,msg,status] = npc_read_platformcodesys(platform,request,date)
% 
% platform	= platform number
% request	= Name of codesys row, e.g.
%		  'Ship name' or 'ITU Call Sign'.
% date		= datestring in Physchem format, in order to grab the
%		  row valid for a specific time (default = now).
% 
% content	= The found result. Empty char if no result.
% msg		= Message about the results. 
% status	= Integer scaling relating to EDISP and used
%		  directly by NPC_VALIDATE_STRUCT: 
%		  1 - success;
%		  2 - no finds for that request;
%		  3 - system error such as no connectivity;
%		  4 - error in the call to API (wrong platform).
%
% Used by NPC_GET_MISSION NPC_VALIDATE_STRUCT 
% See also NPC_INIT EDISP

% Last updated: Wed Dec 13 10:15:01 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(2,3,nargin));
if nargin < 3 | isempty(date),	date=now;	end

content=''; msg=''; status=2;	% Init as no result 

platform=valuetype(platform,'STR');

if isnumeric(date) 
  if 1 < date & date <= now
    date=datestr(date);		% date as datestr char from now
  else
    msg='Numeric input ''date'' must be valid serial day'; status=4; return
  end
elseif ~contains(valuetype(date),'DATE')
  msg='Badly formatted input ''date'''; status=4; return
end

load npc_init URL

try,	tmp=webread(URL.tomcat);	catch, status = 3; msg=strcat(['No response from ',URL.tomcat]);	return;	end

url=[URL.NMDreference,'platform/',platform,'/platformcodes/',URL.NMDreferenceDescription];

try,   tmp=webread(url);		catch, status = 4; msg=strcat(['ERROR! Unsuccessful URL ',url]);		return;	end
try,   platformcodes=xml2struct(tmp);	catch, status = 4; msg=strcat(['ERROR! Unsuccessful XML2STRUCT from ',url]);	return;	end
if isempty(platformcodes)
  status = 4; msg=strcat(['ERROR! Empty output from  URL ',url]);
else
  try
    [~,~,parent] = egetfield(platformcodes,'sysname',request);
    if length(parent)>1 % Find the sysname inside validity range
      for i=1:length(parent)
	t1=datenum2(eval(strcat(parent(i),'.Attributes.validFrom')),113); 
	t=datenum(date); 
	t2=datenum2(eval(strcat(parent(i),'.Attributes.validTo')),113);
	strcat(datestr(t1)," < ", datestr(t)," < ",datestr(t2)); % test
	if t1 <= t & t <= t2, parent=parent(i); break;
	else, parent(i)="";
	end
      end
    end
    if isempty(char(parent))
      msg=strcat("Platform code ",platform," has no valid '",request,"' for date ",date," according to NMDreference:platform codesys");
    else 
      status=1; 
      content = eval(strcat(parent,'.value.Text')); 
      msg=strcat("The value of '",request,"' for platform code ",platform," in NMDreference:platform codesys is '",content,"'");
    end
  catch
    msg=strcat("'",request,"' for platform code ",platform," cannot be filled, for some reason");
  end
end
      

function [mission,msg,status,url] = npc_get_mission(missionnumber,platform,startyear,missiontype)
% NPC_GET_MISSION	Reads a mission from NMDphyschem API
% 
% [mission,msg,status,url] = 
%	npc_get_mission(missionnumber,platform,startyear,missiontype)
% 
% missionnumber	= 1) mission number accompanied by all three other
%		     inputs of mission keys (platform, startyear, and
%		     missontype);   
%		  2) full missionnumber for cruises directly followed
%		     by missiontype (platform and startyear become
%		     obsolete); 
%		  3) full URL to API as can be acquired from PhysChem 
%		     Editor (all keys then become obsolete). 
% platform	= code for platform, or the exact platform name from
%		  NMDreference:platform.
% startyear	= year for mission start.
% missiontype	= code for missiontype, or the exact mission type
%		  name from NMDreference:missionType.
%
% mission	= struct of full mission.
% msg		= string message related to status.
% status	= Integer (scaling relating to EDISP): 
%		    1 - success;
%		    4 - error in the call to API.
% url		= The URL used to read the mission.
%
% API addresses, paths, and weboptions are set in NPC_INIT. References
% are read directly from reference APIs.

% For 1-3 digit missionnumbers, the ship number used too build the mid
% of the 10 digit cruise number automatically comes from the file
% toktnummer_regler.txt, which is copied from the cruise commitee's
% doc-file of the same name. For older cruises and other missions,
% full missionnumber-string must be entered.
%
% It is recommended to always run NPC_VALIDATE_STRUCT on any newly
% read mission, before further analysis.
% 
% Uses NPC_READ_REFERENCE NPC_READ_PLATFORMCODESYS 
% See also NPC NPC_INIT NPC_VALIDATE_STRUCT WEBREAD JSONDECODE

% Last updated: Wed Dec 13 11:30:19 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,5,nargin));

% GENERAL SETTINGS AND INFO:
mission=struct([]); status=1;
load npc_init URL woptions shipnumbers
% URL defines beginning and end of url.
% woptions is the chosen weboptions for webread.
% shipnumbers is the numbering used by the cruise commitee when defining cruise numbers.

if isempty(missionnumber)						% Empty input (fail)
  msg=strcat("NPC_GET_MISSION : Empty input!");  status=4; return;
elseif ischar(missionnumber) & contains(missionnumber,'https://')	% Assume direct url input
  url=missionnumber;					
elseif length(num2str(missionnumber))==10				% Assume complete cruise number input
  if nargin < 2 || isempty(platform),	msg="NPC_GET_MISSION : Missing second input of missiontype!"; status=4; return; end	
  missiontype   = platform;
  missionnumber = num2str(missionnumber);
  platform      = shipnumbers.Platform(find(shipnumbers.Serie==str2num(missionnumber(5:7))));
  startyear     = missionnumber(1:4);
  missionnumber = str2num(missionnumber(8:10));
else									% Assume normal input of all four
  if nargin < 2 || isempty(platform),	msg="NPC_GET_MISSION : Missing patform input!";		status=4; return; end
  if nargin < 3 || isempty(startyear),	msg="NPC_GET_MISSION : Missing startyear input!";	status=4; return; end
  if nargin < 4 || isempty(missiontype),msg="NPC_GET_MISSION : Missing missiontype input!";	status=4; return; end
end

% THE URL:
if ~exist('url','var')						% Build the proper URL from mission keys:
  if ischar(missiontype) && isempty(str2num(missiontype))	% Assume missiontype name input attempted
    missiontypename = missiontype;
    missiontype = npc_read_reference('missionType','','name',missiontypename);
  else								% otherwise missiontype number is given
    missiontypename = npc_read_reference('missionType',num2str(missiontype),'name');
  end
  if ischar(platform) && isempty(str2num(platform))		% Assume platform name input attempted
    platformname  = platform;
    platform      = shipnumbers.Platform(strcmp(shipnumbers.Fart_y,platformname));
  else								% otherwise platform number is given
    platformname  = npc_read_platformcodesys(platform,'Ship name',datenum(valuetype(startyear,'INT'),1,1));
  end
  callsignal      = npc_read_platformcodesys(platform,'ITU Call Sign',datenum(valuetype(startyear,'INT'),1,1));
  missionnumber   = valuetype(missionnumber,'INT'); %		 Make sure missionnumber is numeric at first
  startyear       = num2str(startyear);
  if missionnumber <= 999					% Build the proper missionnumber
    shipnr        = shipnumbers.Serie(strcmp(shipnumbers.Fart_y,platformname));
    missionnumber = [startyear, num2str(shipnr,'%03d'), num2str(missionnumber,'%03d')];
  else								% or just try to use input as is
    missionnumber = valuetype(missionnumber,'STR');
  end
  url = strcat( ...
      URL.physchem, ...
      missiontypename,'/', ...
      startyear,'/', ...
      platformname,'_',callsignal,'/', ...
      missionnumber,'', ...
      URL.physchemDescription);
end

% READ JSON FROM API:
try
  msg = strcat("NPC_GET_MISSION : Read mission from ",url);
  missionjson=webread(url,woptions);
catch
  msg = strcat("NPC_GET_MISSION : Failed reading from ",url); 
  status=4; return
end

% Remove those annoying silly plurals from webread (the reason we go via json):
missionjson=replace(missionjson,'"operations"','"operation"');
missionjson=replace(missionjson,'"instruments"','"instrument"'); % instrumentserialnumber!
missionjson=replace(missionjson,'"instrumentproperties"','"instrumentproperty"');
missionjson=replace(missionjson,'"parameters"','"parameter"');
missionjson=replace(missionjson,'"parameterproperties"','"parameterproperty"');
missionjson=replace(missionjson,'"readings"','"reading"');

% valueint, valuedec, valuedatetime, valuestr -> value
missionjson=replace(missionjson,'"valueint"','"value"');
missionjson=replace(missionjson,'"valuedec"','"value"');
missionjson=replace(missionjson,'"valuestr"','"value"');
missionjson=replace(missionjson,'"valuedatetime"','"value"');

% % Force/fool JSONDECODE to make all fields cell, even when they have similar content:
IO=strfind(missionjson,'featuretype');	  % Comes before instrument (alphabetical)
II=strfind(missionjson,'instrumenttype'); % Comes before parameter (alphabetical)
IP=strfind(missionjson,'parametercode');  % Comes before reading (alphabetical)
% First "featuretype" after each "mission" 
missionjson(IO(1)+[0:10])='featuretyp1';
for io=1:length(IO) 
  find(II>IO(io)); % First "instrumenttype"s after each "featuretype" 
  missionjson(II(ans(1))+[0:13])='instrumenttyp1';
  for ii=1:length(II) 
    find(IP>II(ii)); % First "parametercode"s after each "instrumenttype" 
    missionjson(IP(ans(1))+[0:12])='parametercod1';
  end
end

% DECODE TO STRUCT:
mission=jsondecode(missionjson);

% Make single operation also cell:
if ~iscell(mission.operation), mission.operation={mission.operation}; end

% Change back those dummy fieldnames:
mission.operation{1}.featuretype = mission.operation{1}.featuretyp1;
mission.operation{1}     = rmfield(mission.operation{1},'featuretyp1');
for O=1:length(mission.operation)
  if length(mission.operation{O}.instrument)<2
    mission.operation{O}=setfield(mission.operation{O},'instrument',{mission.operation{O}.instrument});
  end
  mission.operation{O}.instrument{1}.instrumenttype = mission.operation{O}.instrument{1}.instrumenttyp1;
  mission.operation{O}.instrument{1}        = rmfield(mission.operation{O}.instrument{1},'instrumenttyp1');
  for I=1:length(mission.operation{O}.instrument)
    if length(mission.operation{O}.instrument{I}.parameter)<2
      mission.operation{O}.instrument{I}=setfield(mission.operation{O}.instrument{I},'parameter',{mission.operation{O}.instrument{I}.parameter});
    end
    mission.operation{O}.instrument{I}.parameter{1}.parametercode = mission.operation{O}.instrument{I}.parameter{1}.parametercod1;
    mission.operation{O}.instrument{I}.parameter{1}       = rmfield(mission.operation{O}.instrument{I}.parameter{1},'parametercod1');
  end
end


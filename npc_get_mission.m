function [mission,msg,status,url] = npc_get_mission(missionNumber,platform,startYear,missionType)
% NPC_GET_MISSION	Reads a mission from NMDphyschem API
% 
% [mission,msg,status,url] = 
%	npc_get_mission(missionNumber,platform,startYear,missionType)
% 
% missionNumber	= 1) mission number accompanied by all three other
%		     inputs of mission keys (platform, startYear, and
%		     missontype);   
%		  2) full missionNumber for cruises directly followed
%		     by missionType (platform and startYear become
%		     obsolete); 
%		  3) full URL to API as can be acquired from PhysChem 
%		     Editor (all keys then become obsolete). 
% platform	= code for platform, or the exact platform name from
%		  NMDreference:platform.
% startYear	= year for mission start.
% missionType	= code for missionType, or the exact mission type
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

% For 1-3 digit mission numbers, the ship number used too build the mid
% of the 10 digit cruise number automatically comes from the file
% toktnummer_regler.txt, which is copied from the cruise commitee's
% doc-file of the same name. For older cruises and other missions,
% full mission number string must be entered.
%
% It is recommended to always run NPC_VALIDATE_STRUCT on any newly
% read mission, before further analysis.
% 
% Uses NPC_READ_REFERENCE NPC_READ_PLATFORMCODESYS 
% See also NPC NPC_INIT NPC_VALIDATE_STRUCT WEBREAD JSONDECODE

% Last updated: Thu Jul 11 18:27:17 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,5,nargin));

% GENERAL SETTINGS AND INFO:
mission=struct([]); status=1;
load npc_init URL woptions shipnumbers
% URL defines beginning and end of url.
% woptions is the chosen weboptions for webread.
% shipnumbers is the numbering used by the cruise commitee when defining cruise numbers.

if isempty(missionNumber)						% Empty input (fail)
  msg=strcat("NPC_GET_MISSION : Empty input!");  status=4; return;
elseif ischar(missionNumber) & ( contains(missionNumber,'https://') | contains(missionNumber,'http://') )	% Assume direct url input
  url=missionNumber;					
elseif length(num2str(missionNumber))==10				% Assume complete cruise number input
  if nargin < 2 || isempty(platform),	msg="NPC_GET_MISSION : Missing second input of missionType!"; status=4; return; end	
  missionType   = platform;
  missionNumber = num2str(missionNumber);
  platform      = shipnumbers.Platform(find(shipnumbers.Serie==str2num(missionNumber(5:7))));
  startYear     = missionNumber(1:4);
  missionNumber = str2num(missionNumber(8:10));
else									% Assume normal input of all four
  if nargin < 2 || isempty(platform),	msg="NPC_GET_MISSION : Missing platform input!";	status=4; return; end
  if nargin < 3 || isempty(startYear),	msg="NPC_GET_MISSION : Missing startYear input!";	status=4; return; end
  if nargin < 4 || isempty(missionType),msg="NPC_GET_MISSION : Missing missionType input!";	status=4; return; end
end

% THE URL:
if ~exist('url','var')						% Build the proper URL from mission keys:
  if ischar(missionType) && isempty(str2num(missionType))	% Assume missionType name input attempted
    missionTypeName = missionType;
    missionType = npc_read_reference('missionType','','name',missionTypeName);
  else								% otherwise missionType number is given
    missionTypeName = npc_read_reference('missionType',num2str(missionType),'name');
  end
  if ischar(platform) && isempty(str2num(platform))		% Assume platform name input attempted
    platformName  = platform;
    platform      = shipnumbers.Platform(strcmp(shipnumbers.Fart_y,platformName));
  else								% otherwise platform number is given
    platformName  = npc_read_platformcodesys(platform,'Ship name',datenum(valuetype(startYear,'INT'),1,1));
  end
  callsignal      = npc_read_platformcodesys(platform,'ITU Call Sign',datenum(valuetype(startYear,'INT'),1,1));
  missionNumber   = valuetype(missionNumber,'INT'); %		 Make sure missionNumber is numeric at first
  startYear       = num2str(startYear);
  if missionNumber <= 999					% Build the cruisenumber
    shipnr        = shipnumbers.Serie(strcmp(shipnumbers.Fart_y,platformName));
    cruisenumber = [startYear, num2str(shipnr,'%03d'), num2str(missionNumber,'%03d')];
  else								% or just try to use input as is
    cruisenumber = valuetype(missionNumber,'STR');
  end
  
  % missionType, startYear, platform, missionNumber, cruisenumber
  % whos missionType startYear platform missionNumber
  
  % The PhysChem key-based url: 
  % Example: https://physchem-api-test.hi.no/mission/missionType/4/startYear/2024/platform/4174/missionNumber/10?extend=true
  url = strcat( ...
      URL.base, ...
      'mission/',...
      'missionType/',int2str(missionType),...
      '/startYear/',startYear,...
      '/platform/',int2str(platform),...
      '/missionNumber/',int2str(missionNumber),...
      '?extend=true');
  % https://physchem-api.hi.no/mission/search/findMissionByUniqueConstraint?missionType=4&startYear=2024&callSignal=LMEL&cruise=2024001010	4174
  % url = strcat( URL.base, ...
  %     'mission/search/findMissionByUniqueConstraint',...
  %     '?missionType=',int2str(missionType),...
  %     '&startYear=',startYear,...
  %     '&callSignal=',callsignal,...
  %     '&cruise=',missionNumber)
end

% READ JSON FROM API:
try
  msg = strcat("NPC_GET_MISSION : Read mission from ",url);
  missionjson=webread(url,woptions);
catch
  msg = strcat("NPC_GET_MISSION : Failed reading from ",url); 
  status=4; return
end

% % Remove those annoying silly plurals from webread (the reason we go via json):
% %missionjson=replace(missionjson,'"operations"','"operation"');
% missionjson=replace(missionjson,'"instruments"','"instrument"'); % instrumentserialnumber!
% missionjson=replace(missionjson,'"instrumentProperties"','"instrumentProperty"');
% missionjson=replace(missionjson,'"parameters"','"parameter"');
% missionjson=replace(missionjson,'"parameterProperties"','"parameterProperty"');
% missionjson=replace(missionjson,'"readings"','"reading"');
% Obsolete with the new system 2024

% valueInt, valueDec, valueDateTime, valueStr -> value:
missionjson=replace(missionjson,'"valueInt"','"value"');
missionjson=replace(missionjson,'"valueDec"','"value"');
missionjson=replace(missionjson,'"valueStr"','"value"');
missionjson=replace(missionjson,'"valueDateTime"','"value"');

% Force/fool JSONDECODE to make all fields cell, even when they have similar content:
% We just change the name of one mandatory field in each sub-level.
IO=strfind(missionjson,'"operationType"');	% Comes before instrument
II=strfind(missionjson,'"instrumentType"');	% Comes before parameter
IP=strfind(missionjson,'"parameterCode"');	% Comes before reading
% First "featureType" after each "mission" 
missionjson(IO(1)+[1:13])='operationTyp1';
for io=1:length(IO) 
  find(II>IO(io)); % First "instrumentType"s after each "featureType" 
  missionjson(II(ans(1))+[1:14])='instrumentTyp1';
  for ii=1:length(II) 
    find(IP>II(ii)); % First "parameterCode"s after each "instrumentType" 
    missionjson(IP(ans(1))+[1:13])='parameterCod1';
  end
end

% DECODE TO STRUCT:
mission=jsondecode(missionjson);

% MAKE SINGLES TO CELLS and CHANGE BACK THE DUMMY FIELDNAMES:
% Make single operation also cell:
if ~iscell(mission.operation), mission.operation={mission.operation}; end
% Change back the dummy operation fieldname:
mission.operation{1}.operationType = mission.operation{1}.operationTyp1;
mission.operation{1}       = rmfield(mission.operation{1},'operationTyp1');
for O=1:numel(mission.operation)
  % Make single instruments also cells:
  if numel(mission.operation{O}.instrument)<2
    mission.operation{O}=setfield(mission.operation{O},'instrument',{mission.operation{O}.instrument});
  end
  % Change back the dummy instrument fieldname:
  mission.operation{O}.instrument{1}.instrumentType = mission.operation{O}.instrument{1}.instrumentTyp1;
  mission.operation{O}.instrument{1}        = rmfield(mission.operation{O}.instrument{1},'instrumentTyp1');
  for I=1:numel(mission.operation{O}.instrument)
    % Make single parameters also cells:
    if numel(mission.operation{O}.instrument{I}.parameter)<2
      mission.operation{O}.instrument{I}=setfield(mission.operation{O}.instrument{I},'parameter',{mission.operation{O}.instrument{I}.parameter});
    end
    % Change back the dummy parameter fieldname:
    mission.operation{O}.instrument{I}.parameter{1}.parameterCode = mission.operation{O}.instrument{I}.parameter{1}.parameterCod1;
    mission.operation{O}.instrument{I}.parameter{1}       = rmfield(mission.operation{O}.instrument{I}.parameter{1},'parameterCod1');
  end
end


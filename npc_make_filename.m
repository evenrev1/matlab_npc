function [filename,operationpart,instrumentpart] = npc_make_filename(mission,operationType,instrumentType,operationNumber,instrumentNumber)
% NPC_MAKE_FILENAME	Define filename by mission content
% 
% [filename,operationpart,instrumentpart] = ...
%     npc_make_filename(mission,operationType,instrumentType,operationNumber,instrumentNumber)
% 
% mission	  = mission struct
% operationType	  = operation to be put in file 
%		   (default = the first operationType in mission)
% instrumentType  = n/a! instrument to be put in file
%		   (default = the first instrumentType in the operation)
% operationNumber = n/a! operation  to be put in file
%		   (default = the first operation of operationType)
% instrumentNumber = n/a! instrument to be put in file
%		   (default = the first instrument of instrumentType)
%
% filename	  = string with the filename to use to store these data.
%		    If any of the next two outputs are requested,
%		    this will be only the mission related part of
%		    filename (see below).  
% operationpart	  = Optional 1x2 string output of operation related
%		    part of full file name.
% instrumentpart  = Optional 1x2 string output of instrument related
%		    part of full file name.
%
% The structure of filename is:
%	npc_missionType_startYear_platform_missionNumber ...
%	_operationType_operationNumber ...
%	_instrumentType_instrumentNumber
%
% WARNING: It is safest to use this function on a mission struct that is
% already reduced to the single operation and instrument you will put in
% the file. There is always the possibility of mismatch between the
% sequence of operation and instrument arrays and the fields
% operationNumber and instrumenid (especially when there are jumps in
% stationnumber, or operations are of differen type). Input of a reduced
% structure ensures the filename has the correct operation and
% instrument keys.
%
% The possibillity to select operation and instrument here, is obsolete
% for the time being, as this is a task for hendling the dataset itself.
%
% Used by NPC_WRITE_STRUCT
% See also GETALLFIELDS EGETFIELD  

% This function requires hardcoding when data model of PhysChem changes!

% Last updated: Fri Jul 19 16:20:56 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,5,nargin));
if nargin < 5 | isempty(instrumentNumber),instrumentNumber='';	end
if nargin < 4 | isempty(operationNumber), operationNumber='';	end
if nargin < 3 | isempty(instrumentType),  instrumentType='';	end
if nargin < 2 | isempty(operationType),   operationType='';	end
if isempty(mission)
  disp('NPC_WRITE_STRUCT : Empty input!'); 
  filename='';  operationpart='';  instrumentpart='';
  return; 
end

% ------- Check input and assign strings for parts of filename: -----------------

% operationType is always mandatory.
if isempty(operationType)
  %operationType = string(mission.operation{1}.operationType);   % Always mandatory
  operationType = unique(string(getallfields(mission,'operationType')));
  if numel(operationType)>1 || ~any(strlength(operationType)) % Not unique or missing field
    operationType = "X";
  end
end
% operationNumber is optional on input to PhysChem.
if isempty(operationNumber) %& isfield(mission.operation{1},'operationNumber') && ~isempty(mission.operation{1}.operationNumber); 
  %operationNumber = string(mission.operation{1}.operationNumber);
  operationNumber = unique(string(getallfields(mission,'operationNumber')));
  if numel(operationNumber)>1 || ~any(strlength(operationNumber))  % Not unique or missing field
    operationNumber = "x";
  end
end
% instrumentType is always mandatory.
if isempty(instrumentType)
  %instrumentType = string(mission.operation{1}.instrument{1}.instrumentType);  % Always mandatory
  instrumentType = unique(string(getallfields(mission,'instrumentType')));
  if numel(instrumentType)>1 || ~any(strlength(instrumentType)) % Not unique or missing field
    instrumentType = "X";
  end
end
% instrumentNumber is optional on input to PhysChem.
if isempty(instrumentNumber) %& isfield(mission.operation{1}.instrument{1},'instrumentNumber') && ~isempty(mission.operation{1}.instrument{1}.instrumentNumber)
  %instrumentNumber = string(mission.operation{1}.instrument{1}.instrumentNumber);
  instrumentNumber = unique(string(getallfields(mission,'instrumentNumber')));
  if numel(instrumentNumber)>1 || ~any(strlength(instrumentNumber)) % Not unique or missing field
    instrumentNumber = "x";
  end
end

 
% ----- Build filename (following the rules): ------------------------

% First part is based on input mission stuct:
missionbase=string(['npc', ...
		    '_',num2str(mission.missionType), ...
		    '_',num2str(mission.startYear), ...
		    '_',num2str(mission.platform), ...
		    '_',num2str(mission.missionNumber)]);

operationpart  = [operationType operationNumber];
instrumentpart = [instrumentType instrumentNumber];

if nargout>1
  filename = missionbase;
else
  filename = join([missionbase,operationpart,instrumentpart]);
end
% Add underscores:
filename = replace(filename,{' '},{'_'});

% Translate Norwegian:
filename=replace(filename,'æ','ae');
filename=replace(filename,'ø','oe');
filename=replace(filename,'å','aa');
filename=replace(filename,'Æ','AE');
filename=replace(filename,'Ø','OE');
filename=replace(filename,'Å','AA');

% Strip wildcards at end of filename:
ans=filename;
if endsWith(ans,'_x'), strip(ans,'x'); strip(ans,'_');				% Strip instrumentNumber wildcard
  if endsWith(ans,'_X'), strip(ans,'_'); strip(ans,'X'); strip(ans,'_');	% Strip instrumentType wildcard  
    if endsWith(ans,'_x'), strip(ans,'_'); strip(ans,'x'); strip(ans,'_');	% Strip operationNumber wildcard 
      if endsWith(ans,'_X'), strip(ans,'_'); strip(ans,'X'); strip(ans,'_');	% Strip operationType wildcard   
      end
    end
  end
end
filename = ans;


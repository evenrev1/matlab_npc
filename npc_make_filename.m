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

% Last updated: Fri Jul 12 18:36:45 2024 by jan.even.oeie.nilsen@hi.no

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

% ------- Assume reduced input and use first of all: -----------------

% operationType is always mandatory.
if isempty(operationType)
  operationType = string(mission.operation{1}.operationType); 
else
  operationType = 'X';
end
% operationNumber is optional on input to PhysChem.
if isempty(operationNumber) & ...
      isfield(mission.operation{1},'operationNumber') && ~isempty(mission.operation{1}.operationNumber); 
  operationNumber = string(mission.operation{1}.operationNumber);
else
  operationNumber = 'x';
end
% instrumentType is always mandatory.
if isempty(instrumentType)
  instrumentType = string(mission.operation{1}.instrument{1}.instrumentType);  % Always mandatory
else
  instrumentType = 'X';
end
% instrumentNumber is optional on input to PhysChem.
if isempty(operationNumber) & ...
      isfield(mission.operation{1}.instrument{1},'instrumentNumber') && ~isempty(mission.operation{1}.instrument{1}.instrumentNumber)
  instrumentNumber = string(mission.operation{1}.instrument{1}.instrumentNumber);
else
  instrumentNumber = 'x';
end

% % ---- Check inputs for relevance and use mission struct if not: -----
%
% instrumentNumber    = string(instrumentNumber);	
% operationNumber = string(operationNumber);	
% instrumentType  = string(instrumentType);	
% operationType   = string(operationType);	
%
% % If empty or invalid operationType, use the first in mission:
% operationTypes=string(getallfields(mission,'operationType'));
% if ~ismember(operationTypes,operationType)
%   operationType=operationTypes(1);
% end
%
% % Now find which operations are of this type:
% operationNumbers = string(egetfield(mission,'operationType',operationType,'operationNumber'));
% % If empty or invalid operationNumber for this operationType, use the first valid:
% if ~ismember(operationNumbers,operationNumber)
%   operationNumber=operationNumbers(1);
% end
%
% % Reduce struct to chosen operation:
% s=mission.operation{str2num(operationNumber)};
%
% % If empty or invalid instrumentType, use the first in operation:
% instrumentTypes=string(getallfields(s,'instrumentType'));
% if ~ismember(instrumentTypes,instrumentType)
%   instrumentType=instrumentTypes(1);
% end
%
% % Now find which instruments in this operation that are of this type:
% instrumentNumbers = string(egetfield(s,'instrumentType',instrumentType,'instrumentNumber'));
% % If empty or invalid instrumentNumber for this instrumentType, use the first valid:
% if ~ismember(instrumentNumbers,instrumentNumber)
%   instrumentNumber=instrumentNumbers(1);
% end

 
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


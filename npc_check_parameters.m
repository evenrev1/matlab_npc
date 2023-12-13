function [msg,status] = npc_check_parameters(inst,tests)
% NPC_CHECK_PARAMETERS	Checks for inconsistencies among parameters
% Checks parameter elements of same parametercode for inconsistencies
% in other metadata.
%
% [msg,status] = npc_check_parameters(inst,tests)
% 
% inst	 = structure for an instrument element
% tests	 = character array with which tests to run 
%	   (default='12345', i.e. all)
%	   Put 'none' for no tests. 
% 
% msg	 = string array of error messages, MxN, where M is the number
%	   of tests and N is the number of parameters.
% status = integer according to filtering of display in
%	   NPC_VALIDATE_STRUCT (1 - success; 4 - error detected).
%
% The tests and corresponing rows in msg are:
%
% 1) missing or empty parametercodes are not allowed
% 2) missing or empty units are not allowed
% -- Testing stops here if 1 or 2 fails ---
% 3) All parameterids need to exist and be filled and be unique
%    within the instrument 
% 4) Ordinals are for all parameters, and must be unique among
%    same parametercodes (including the omitted ordinal for
%    the primary sensor) 
% 5) Sensorserialnumbers do not exist for all parameters, but if
%    there are any, they must be unique among same parametercodes,
%    unless some are calculated using different referencescales or to
%    different units. 
%
% Used by NPC_VALIDATE_STRUCT 
% Uses NPC_STRIP_READINGS
% See also GETALLFIELDS EGETFIELD
  
% Last updated: Wed Dec 13 10:20:56 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,2,nargin));
if nargin < 2 | isempty(tests),	tests='123456';	end
if contains(tests,'none'),	tests='';	end

M=5;					% Number of tests available
do=ismember(1:M,str2num(tests(:)));	% Logical for tests to run
N=numel(inst.parameter);		% Number of parameters for instrument
msg=repmat("",M,N);			% Error messages
status=1;				% Assume success initially
base=repmat({''},1,N);			% Preallocate contents of the relevant parameter elements

inst=npc_strip_readings(inst);		% Strip the readings to make it less heavy

jsonString = jsonencode(inst);		% Some test might be faster with JSON


% 1) All parametercodes need to exist and be filled (also for this function)
parametercode = getallfields(jsonString,'parametercode');
if do(1) 
  if size(parametercode,1)~=N
    msg(1,i)=strcat("mandatory parametercode field is missing (inconsistency checks are impossible)");
  else
    i=find(all(isspace(parametercode),2));
    if any(i)
      msg(1,i)=strcat("mandatory parametercode value (",int2str(i(:)),") is missing (inconsistency checks are impossible)");
    end
  end
end

% 2) All units need to exist and be filled 
units = getallfields(jsonString,'units');
if do(2) 
  if size(units,1)~=N
    msg(2,i)=strcat("mandatory units field is missing"); 
  else
    i=find(all(isspace(units),2));
    if any(i)
      msg(2,i)=strcat("mandatory units value (",int2str(i(:)),") missing");
    end
  end
end

if ~isempty(char(msg)), status=4; return; end % critical errors above

% 3) All parameterids need to exist and be filled and unique
parameterid = getallfields(jsonString,'parameterid');
if do(3) 
  if size(parameterid,1)~=N
    msg(3,i)=strcat("mandatory parameterid field is missing");
  else
    i=find(all(isspace(parameterid),2));
    if any(i)
      msg(3,i)=strcat("mandatory parameterid value (",int2str(i(:)),") missing");
    elseif numel(unique(string(parameterid)))~=N
      msg(3,i)=strcat("parameterids are not unique");
    end % Use string so that ids can be cell with numerics.
  end
end

% Further tests requires use of struct (but should be fast with the readings stripped).

% Now, build a matrix with all parameter fields to be checked for consistency:
parid=["parameterid","parametercode","units","sensorserialnumber","referencescale","ordinal"];
m=numel(parid);
partab=strings(N,m);				% row per parameter, column per unique id
for i=1:m
  tmp=base; [y,yfn]=egetfield(inst,char(parid(i))); 
  if ~isempty(y), split(yfn,{'{','}'}); str2num(char(ans(:,2))); tmp(ans)=y;
    partab(:,i)=string(cellfun(@num2str, tmp, 'UniformOutput',false)); % For UNIQUE to work
  end
end

[~,IA]=sort(str2num(char(partab(:,1)))); partab=partab(IA,:);	% Sort by parameterid


% 4) All similar parameters need unique ordinals regardless of units, sensorserialnumber, or referencescale
if do(4)
  [~,IA]=unique(partab(:,[2 6]),'rows','stable');
  i=setdiff(1:N,IA)';
  if ~isempty(i) 
    msg(4,i) = strcat("ordinals of ",partab(i,2)," not unique");
  end
end

% 5) Sensorserialnumbers do not exist for all parameters, but if there are any, they must be unique ...
if do(5)
  part=partab(~strcmp(partab(:,4),""),:);		% part of partab with snrs
  n=size(part,1);					% number of rows with snr
  [~,IA]=unique(part(:,[2 3 4 5]),'rows','stable');	% ... unless there are different referencescales or units
  i=setdiff(1:n,IA)';
  if ~isempty(i) 
    msg(5,i) = strcat("serialnumber of ",part(i,2)," with parameterid ",part(i,1)," is duplicated");
  end
end

% Finally set status:
if ~isempty(char(msg))
  status=4; % errors
else
  status=1; % success for all tests and parameters
end



function [mission,change] = npc_augment_mission(oldmission,newmission,rules,levlim)
% NPC_AUGMENT_MISSION	Adds data to a mission struct.
% Currently only intended for time series.
%
% [mission,change] = npc_augment_mission(oldmission,newmission,rules,levlim)
% 
% oldmission  = An existing mission struct to which you want to
%		add data to.
% newmission  = A mission struct constructed with new data in a
%		single set of readings, in one mission, one operation,
%		and one instrument.
% rules	      = Your rules for creating new operations and new
%		missions. Default (and fixed) is listed below. 
% levlim      = Lower limit integer for filtering of message
%		displays (EDISP) according to levels:
%			1 - success and trivial messages;
%			2 - changes are done to fix things;
%			3 - unable to check;
%			4 - errors in struct.
%
% mission     = The resulting new mission struct, either the
%		oldmission with new reading, instrument, or operation
%		added to it, or a brand new mission based on the
%		newmission. This depends on the rules. 
% change      = 1x3 logical indicating any changes as
%		[NEWMISSION,NEWOPERATION,NEWREADING].
%
% DEFAULT RULES:
% New year => new mission
% Any change in mission level fields => new mission
% The latter includes any addition or change of instruments
% Any change in the operation or instrument level fields => add new operation
% The latter includes any addition or change of parameters
% Any change on any parameter field (apart from reading)=> add new operation
% Only change in reading => add new readings to all parameters
% If there is time in the data, and a gap of more than 2 hours occurs => add new operation
%
% UNRESOLVED:
% [] Rules cannot be set by user yet.
% [] Only buildt for missions with one instrument in each operation.
% [] Assuming only one operation, one instrument, and one reading in newmission.
% [] Assuming only one reading in newmission input
%
% See also ISEQUALN GETALLFIELDS

% Last updated: Thu Jul 11 20:43:36 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(2,4,nargin));
if isempty(oldmission),	edisp('NPC_VALIDATE_STRUCT : Empty input!',4,4); return;	end
if isempty(newmission),	edisp('NPC_VALIDATE_STRUCT : Empty input!',4,4); return;	end
if nargin < 4 | isempty(levlim),	levlim=1;	end
if nargin < 3 | isempty(rules),		rules='';	end

% Init:
[NEWMISSION,NEWOPERATION,NEWREADING] = deal(false);

% --- Compare the structures and check for new content: --------------

if isequaln(newmission,oldmission)  
  % No change; no need to check or do anything further
  mission = oldmission;
  disp("npc_augment_mission: Mission structs are identical; no change in mission.");
  change = [NEWMISSION,NEWOPERATION,NEWREADING];
  return
else
  if str2num(newmission.startYear) > str2num(oldmission.startYear)
    % Entering a new year detected by dynamic update of startYear.
    disp("npc_augment_mission: Additional data is from new year; output is the new mission only.");
    NEWMISSION=true;
  elseif ~isequaln(rmfield(newmission,["operation" "missionStartDate" "missionStopDate" "missionNumber"]),...
		   rmfield(oldmission,["operation" "missionStartDate" "missionStopDate" "missionNumber"]))
    % There are other differences on the mission level apart from the startdate.
    disp("npc_augment_mission: Mission level fields differ; output is the new mission only.");
    NEWMISSION=true;
  else
    while ~NEWOPERATION
      % GENERAL:
      % Now it is time to check the next levels to see if a new operation is in order.
      % Compare only with the latest operation, hence '{end}'.
      % property fields are also checked by the general comparison
      % at the levels.

      % OPERATION LEVEL:
      % On operation level timestart and operationnumber will be
      % different just because newmission is a dummy mission with the
      % new reading only. 
      NEWOPERATION = ~isequaln(rmfield(oldmission.operation{end},["operationNumber" "instrument" "timeStart" "timeEnd"]),...
			       rmfield(newmission.operation{1},  ["operationNumber" "instrument" "timeStart" "timeEnd"]));
      if NEWOPERATION
	disp("npc_augment_mission: Operation level fields differ; adding new operation to old mission.");
      break; % No need to test more 
      end 
      
      % INSTRUMENT LEVEL:
      % Check number of instruments (sequence will be caught on
      % instrument level when comparing instruments one by one):
      NEWOPERATION = NEWOPERATION | ...
	  ~isequal(numel(oldmission.operation{end}.instrument),...
		   numel(newmission.operation{1}.instrument));
      % Looping assumes instruments are sorted in the same order, but
      % this must be a rule. Any switching of the instrument order,
      % in the struct, should trigger a new operation. 
      % We omit instrumentid because newmission has it as a dummy, and
      % parameter because it is the next level.
      for Ii=1:numel(oldmission.operation{end}.instrument)
	NEWOPERATION = NEWOPERATION | ...
	    ~isequaln( rmfield(oldmission.operation{end}.instrument{Ii},["instrumentNumber" "parameter"]),...
		       rmfield(newmission.operation{1}.instrument{Ii},  ["instrumentNumber" "parameter"]) );
	if NEWOPERATION
	  disp("npc_augment_mission: Instrument level fields differ; adding new operation to old mission.");
	  break; % No need to test more 
	end 
	
	% PARAMETER LEVEL:
	% Check number of parameters:
	NEWOPERATION = NEWOPERATION | ...
	    ~isequaln( numel(oldmission.operation{end}.instrument{Ii}.parameter) , ...
		       numel(newmission.operation{1}.instrument{Ii}.parameter) );
	% Check that parameters are the same and listed the same sequence: 
	NEWOPERATION = NEWOPERATION | ...
	    ~isequaln(getallfields(oldmission.operation{end}.instrument{Ii},'parameterCode'),...
		      getallfields(newmission.operation{1}.instrument{Ii},'parameterCode'));
	% Check that parameterids are also the same:
	NEWOPERATION = NEWOPERATION | ...
	    ~isequaln(getallfields(oldmission.operation{end}.instrument{Ii},'parameterNumber'),...
		      getallfields(newmission.operation{1}.instrument{Ii},'parameterNumber'));
	% Check for differences between parameterfields for each
        % parameter, apart from parameterNumber and reading:
	for Pi=1:numel(oldmission.operation{end}.instrument{Ii}.parameter)
	  NEWOPERATION = NEWOPERATION | ...
	      ~isequaln( rmfield(oldmission.operation{end}.instrument{Ii}.parameter{Pi},["parameterNumber" "reading"]),...
			 rmfield(newmission.operation{1}.instrument{Ii}.parameter{Pi},  ["parameterNumber" "reading"]) );
	  if NEWOPERATION
	    disp("npc_augment_mission: Parameter level fields differ; adding new operation to old mission.");
	    break; % No need to test more 
	  end 
	
	  % READING LEVEL:
	  % If none of the above checks require new operation, it is
          % time to check for differences in reading values. This is
          % done in general here in addition to on time below, because
          % there is no guarantee that there is a DATETIME parameter.
	  % Check for any change anywhere in content of any reading value:
	  for Ri=1:numel(oldmission.operation{end}.instrument{Ii}.parameter{Pi}.reading)
	    NEWREADING = NEWREADING | ...
		~isequaln( oldmission.operation{end}.instrument{Ii}.parameter{Pi}.reading(end).value,...
			   newmission.operation{1}.instrument{Ii}.parameter{Pi}.reading(1).value );
	  end 
	
	end
      end
      break % to stop while after all tests
    
    end % while ~NEWOPERATION
  end % ifs about NEWMISSION
end % if whole structs are equal 

% ---- check if reading is new: --------------------------------------

if ~NEWMISSION & ~NEWOPERATION 
  % [] Assuming only one operation and one instrument in the new mission.  
  
  % New time definitely means new reading. Find the parameter containing
  % time.  Have already established that parameters are the same and
  % listed the same way, now only look for which is time:
  timeI=find(contains(string(getallfields(newmission.operation{1}.instrument{1},'parameterCode')),'DATETIME'));
  if any(timeI)
    % If there is a time parameter, check for difference in time. This
    % overrides any difference found in the above check for differences
    % in any parameter reading value. If there is no difference in time,
    % then it is assumed that the reading is not new after all (time is
    % king):
    NEWREADING = ~isequal( oldmission.operation{end}.instrument{1}.parameter{timeI}.reading(end).value,...
			   newmission.operation{1}.instrument{1}.parameter{timeI}.reading(1).value );
    % Now check for gap of more than 1 day:
    if NEWREADING 
      ot=isofix8601(oldmission.operation{end}.instrument{1}.parameter{timeI}.reading(end).value);
      nt=isofix8601(newmission.operation{1}.instrument{1}.parameter{timeI}.reading(1).value);
      if nt-ot > 1
    	NEWOPERATION = true; %NEWREADING = false;
      end
    end
  end
  if NEWOPERATION
    disp("npc_augment_mission: Time gap to new data; adding new operation to old mission.");
  elseif NEWREADING
    disp("npc_augment_mission: There are new readings; adding new readings to old mission.");
  else
    disp("npc_augment_mission: There are no new readings; no change to old mission.");
  end 
end

% --- Manipulate the structures according to test results: -----------

if NEWMISSION
  mission = newmission;
  % Update missionNumber if newmission in the same year:
  if isequal(newmission.startYear,oldmission.startYear)
    mission.missionNumber = oldmission.missionNumber+1;
  end

elseif NEWOPERATION
  mission=oldmission;									% Base the new mission on the old mission
  % [] We assume operations in oldmission struct are ordered according to operationNumber.
  ON=numel(mission.operation);								% Number of operations in existing mission.
  mission.operation{ON+1} = newmission.operation{1};					% Add the temporary operation to the existing mission.
  mission.operation{ON+1}.operationNumber = mission.operation{ON}.operationNumber+1;	% Update the operationNumber.
											% The new reading is in the new mission, so already added.


elseif NEWREADING
  mission=oldmission;									% Base the new mission on the old mission
  % [] Assuming only one instrument. 
  % Have already established that parameters are the same and listed the
  % same way, so we can just loop the parameters:
  for Pi=1:numel(mission.operation{end}.instrument{1}.parameter)
    % Find out how many readings there already are in the old mission struct
    j = numel(mission.operation{end}.instrument{1}.parameter{Pi}.reading)+1;
    % Add the new readings, using j both as index and sampleid value:
    % [] Assuming only one reading in newmission.
    mission.operation{end}.instrument{1}.parameter{Pi}.reading(j) = newmission.operation{1}.instrument{1}.parameter{Pi}.reading;
    mission.operation{end}.instrument{1}.parameter{Pi}.reading(j).sampleid = j;
  end

else % NOTHING NEW
  mission=oldmission;

end

% Extra output information:
change = [NEWMISSION,NEWOPERATION,NEWREADING];

% ---- Always and anyways: -------------------------------------------

% Update the last operation's end time (in the right format):
timeI=find(contains(string(getallfields(newmission.operation{end}.instrument{1},'parameterCode')),'DATETIME'));
if any(timeI)
  mission.operation{end}.timeEnd = isofix8601(isofix8601(mission.operation{end}.instrument{1}.parameter{timeI}.reading(end).value),111);
else
  mission.operation{end}.timeEnd = '';
end
% We adopt the philosophy that mission start and stop dates should
% reflect the content of the dataset, not the planned cruise or
% fieldwork duration. This is definitely valid for autonomous missions,
% where the use of NPC_AUGMENT_MISSION is most relevant. Hence, if there
% has been any change, we here set the missionStopDate based on the last
% operation (which again is based on the last reading):
if any(change) 
  mission.missionStopDate = isofix8601(isofix8601(mission.operation{end}.timeEnd),29);
  % If there is no time parameter, but data has been added,
  % missionStopDate will and should be empty.
end



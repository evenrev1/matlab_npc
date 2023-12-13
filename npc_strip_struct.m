function mission=npc_strip_struct(mission,opt)
% NPC_STRIP_STRUCT	Strips NPC struct of empty fields
% Strips structure of all empty fields but those mandatory for
% NMDphyschem. 
% 
% mission = npc_strip_struct(mission,opt)
% 
% mission = input structure for NMDphyschem.
% opt	  = options char:
%	    'hard' : remove also those of the fields mandatory for
%	             NMDphyschem that can be generated by its import
%	             systems, if they are empty. 
%
% mission = the structure stripped of empty fields
%
% Used by NPC_WRITE_STRUCT
% See also NPC_BUILD_STRUCT NPC_VALIDATE_STRUCT 

% Last updated: Wed Dec 13 16:03:16 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,2,nargin));
if nargin < 2 | isempty(opt),	opt='';	end
if isempty(mission), disp('NPC_STRIP_STRUCT : Empty input!'); return; end

load npc_init % Load valid fieldnames, etc.

if any(contains(opt,'hard'))
  % In this case, and for making input files, there are fields that can
  % be filled by the importer (i.e. Convert Job and Converter API), and
  % thus can be removed from struct. These are explicitly mentioned
  % here.
  removableMissionFields    = [ optionalMissionFields additionalMissionFields ...
		    "missiontypename" "platformname" ];
  removableOperationFields  = [ optionalOperationFields conditionOperationFields additionalOperationFields ...
		    "operationnumber" "operationplatform" ...
		    "timestartquality" "positionstartquality" ];
  removableInstrumentFields = [ optionalInstrumentFields additionalInstrumentFields ...
		   "instrumentid" ];
  removableInstrumentPropertyFields = [ instrumentPropertyTypeCodes ];
  removableParameterFields  = [ optionalParameterFields additionalParameterFields ...
		    "parametercode" "ordinal" "units" "processinglevel" ];
  removableParameterPropertyFields = [ parameterPropertyTypeCodes ];
  removableReadingFields = [ optionalReadingFields additionalReadingFields ...
		    "sampleid" "quality" ];
else
  % Plain removal of the data model's optional fields and NPCs additional fields, if empty.
  removableMissionFields		= [ optionalMissionFields additionalMissionFields ];
  removableOperationFields		= [ optionalOperationFields conditionOperationFields additionalOperationFields ];
  removableInstrumentFields		= [ optionalInstrumentFields additionalInstrumentFields];
  removableInstrumentPropertyFields	= [ instrumentPropertyTypeCodes ];
  removableParameterFields		= [ optionalParameterFields additionalParameterFields ];
  removableParameterPropertyFields	= [ parameterPropertyTypeCodes ];
  removableReadingFields		= [ optionalReadingFields additionalReadingFields ];
end

% Remove the mission (top) level empty removable fields
fieldnames(mission); a=ans(contains(ans,removableMissionFields));
for i=1:length(a)
  if isempty(getfield(mission,a{i}))
    mission=rmfield(mission,a{i}); 
  end
end

% Remove the operation level empty removable fields
for O=1:length(mission.operation)
  fieldnames(mission.operation{O}); a=ans(contains(ans,removableOperationFields));
  for i=1:length(a)
    if isempty(getfield(mission.operation{O},a{i}))
      mission.operation{O}=rmfield(mission.operation{O},a{i}); 
    end
  end

  % INSTRUMENT LEVEL
  for I=1:length(mission.operation{O}.instrument)

    % Remove the instrumentproperty elements that have empty value:
    if isfield(mission.operation{O}.instrument{I},'instrumentproperty')
      ii=true(1,length(mission.operation{O}.instrument{I}.instrumentproperty));
      for IP=1:length(ii)
	fieldnames(mission.operation{O}.instrument{I}.instrumentproperty(IP)); a=ans(contains(ans,'value'));
	if isempty(mission.operation{O}.instrument{I}.instrumentproperty(IP).(a{1}))
	  ii(IP)=false;
	end
      end % instrumentproperties
      mission.operation{O}.instrument{I}.instrumentproperty = mission.operation{O}.instrument{I}.instrumentproperty(ii);
    end % isfield
    
    % Now remove the instrument level empty removable fields:
    fieldnames(mission.operation{O}.instrument{I}); a=ans(contains(ans,removableInstrumentFields));
    for i=1:length(a), 
      if isempty(getfield(mission.operation{O}.instrument{I},a{i}))
	mission.operation{O}.instrument{I}=rmfield(mission.operation{O}.instrument{I},a{i}); 
      end 
    end
    
    % PARAMETER LEVEL
    for P=1:length(mission.operation{O}.instrument{I}.parameter)

      % Remove the parameterproperty elements that have empty value:
      if isfield(mission.operation{O}.instrument{I}.parameter{P},'parameterproperty')
	ii=true(1,length(mission.operation{O}.instrument{I}.parameter{P}.parameterproperty));
	for PP=1:length(ii)
	  fieldnames(mission.operation{O}.instrument{I}.parameter{P}.parameterproperty(PP)); a=ans(contains(ans,'value'));
	  if isempty(mission.operation{O}.instrument{I}.parameter{P}.parameterproperty(PP).(a{1}))
	    ii(PP)=false;
	  end
	end % parameterproperties
	mission.operation{O}.instrument{I}.parameter{P}.parameterproperty = mission.operation{O}.instrument{I}.parameter{P}.parameterproperty(ii);
      end % isfield
      
      % Now remove the parameter level empty removable fields (including parameterproperties):
      fieldnames(mission.operation{O}.instrument{I}.parameter{P}); a=ans(contains(ans,removableParameterFields));
      for i=1:length(a), 
	if isempty(getfield(mission.operation{O}.instrument{I}.parameter{P},a{i}))
	  mission.operation{O}.instrument{I}.parameter{P}=rmfield(mission.operation{O}.instrument{I}.parameter{P},a{i}); 
	end 
      end
      
      % Remove the reading level empty removable fields:
      for R=1:length(mission.operation{O}.instrument{I}.parameter{P}.reading)
	fieldnames(mission.operation{O}.instrument{I}.parameter{P}.reading); a=ans(contains(ans,removableReadingFields));
	for i=1:length(a)
	  if isempty(char(mission.operation{O}.instrument{I}.parameter{P}.reading.(a{i})))
	    mission.operation{O}.instrument{I}.parameter{P}.reading = rmfield(mission.operation{O}.instrument{I}.parameter{P}.reading,a{i}); 
	  end
	end
      end % readings
      
    end % parameters

  end % instruments

end % operations

% Note that it is impossible to remove subfields one by one. A subfield
% must exist in all subscripted fields, or not. This is why we do not
% subscript the deepest subfields when checking and removing them.
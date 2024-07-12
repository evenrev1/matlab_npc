function mission = npc_merge_readings(mission,sortcode)
% NPC_MERGE_READINGS	Merges the reading fields in a mission
% of all parameters into column vectors in single reading fields. 
% 
% mission = npc_merge_readings(mission)
% 
% mission	= input struct with NPC format.
% sortcode	= valid parameterCode with which to sort readings if 
%		  sampleNumber is not present, e.g. 'PRES' (default),
%		  'DEPTH', 'DATETIME', 'LOG', etc.
%
% mission	= output is an altered struct where all reading
%		  fields for each parameter has been merged into
%		  one reading field with vectors.
%
% If sampleNumber is missing (as is usual for import of external data),
% sampleNumber will be made as simple index vectors. It is thus possible
% to use this function to add sampleNumber to data.
% 
% All vectors will be sorted according to 'sampleNumber' if it exists.
%
% Character fields will be merged into character arrays of height
% according to the number of readings and width according to the largest
% character (i.e. largest number of digits).
%
% Used by NPC_MERGE_OPERATIONS NPC_WRITE_STRUCT
% Uses NPC_LOCALMERGE_READINGS
% See also NPC GETALLFIELDS FIELDNAMES

% This function requires hardcoding when data model of PhysChem changes!

% Last updated: Thu Jul 11 14:47:13 2024 by jan.even.oeie.nilsen@hi.no

% [] possibly make some sorting options before making the sampleNumber here.

error(nargchk(1,2,nargin));
if nargin < 2 || isempty(sortcode), sortcode = 'PRES'; end

% SIZES AND PREALLOCATING VARIABLES:
ON=length(mission.operation); 

for O=1:ON
  for I=1:length(mission.operation{O}.instrument)

    for P=1:length(mission.operation{O}.instrument{I}.parameter)
      parameterfield = mission.operation{O}.instrument{I}.parameter{P};
      readingfield = npc_localmerge_readings(parameterfield);
      mission.operation{O}.instrument{I}.parameter{P}.reading = readingfield;
    end
    
    % Now that all parameters of the instrument are merged, assign
    % sampleNumber according to sortcode parameter values, if none exists
    % for this instrument. No need to use GETALLFIELDS in this case,
    % and it won't work since sampleNumber fields are vectors. String searching
    % in jsonencoded struct for the occurence of a fieldname is much faster.
    if ~any(findstr(jsonencode(mission.operation{O}.instrument{I}),'sampleNumber')) 
      pars=strip(string(getallfields(mission.operation{O}.instrument{I},'parameterCode')));
      j=find(ismember(pars,sortcode)); 
      if any(j), j=j(1);
	[~,IA]=sort(mission.operation{O}.instrument{I}.parameter{j}.reading.value);
	for P=1:length(mission.operation{O}.instrument{I}.parameter)
	  fnam = fieldnames(mission.operation{O}.instrument{I}.parameter{P}.reading);
	  data = struct2cell(mission.operation{O}.instrument{I}.parameter{P}.reading);
	  data = cellfun(@(x) x(IA,:), data, 'UniformOutput',false);
	  mission.operation{O}.instrument{I}.parameter{P}.reading = cell2struct(data,fnam);
	end
      end      
    end
    
  end
end  




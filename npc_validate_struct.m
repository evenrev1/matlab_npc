function mission = npc_validate_struct(mission,opt,levlim,API)
% NPC_VALIDATE_STRUCT	Validates an NPC struct
% Outputs a validated and more complete version of struct.
% 
% mission = npc_validate_struct(mission,opt,levlim,API)
% 
% mission	= input struct with NPC format.
% opt		= char combined by the following:
%		  'addnames' : Add fields with names, or in some
%			       cases descriptions, corresponding to
%			       codes.
%		  'ignore'   : Produce corrected struct even though
%		               there are errors. 
%		  'silent'   : No disp, only file report (n/a).
% levlim	= Lower limit integer for filtering of message
%		  displays (EDISP) according to levels:
%			1 - success and trivial messages;
%			2 - changes are done to fix things;
%			3 - unable to check;
%			4 - errors in struct.
% API		= logical to be set to true if validating dataset
%		  from the PhysChem API. This affects which elements
%		  can be considered mandatory. (default=false) 
%
% mission	= output of validated and completed struct.
% 
% Addresses the relevant reference APIs and performs the following:
% At all levels:
%	- Checks validity of field names
%	- Checks for missing or empty mandatory fields
%	- Transforms all fields to correct valueType and format
%	- Checks codes and values against PhysChem Reference and NMDreference
%	- Fills related values using PhysChem Reference and NMDreference
% At mission level:
%	- Checks dates for realism
%	- Adds qualityFlagName, flagValues, and flagMeanings
% At operation level: 
%	- Checks realism of time, position, log, and bottomdepth (global test). 
%	- Fills missing quality flags as 0
% At instrument level:
%	- Checks code and value of instrumentProperty fields
% At parameter level:
%	- Fills mandatory processingLevel 'L0' if empty and all
%	  reading flags are 0 
%	- Fills mandatory parameterCode and units using PhysChem Reference 
%	- Checks code and value of parameterProperty fields
%	- Adds fields with names for codes (optional)
% At reading level:
%	- Fills missing quality flags with 0
%	- Fills quality flags of NaN values with with 9
%
% Definitions and test criteria can be found in NPC_INIT. It is
% recommended to run NPC_INIT prior to any work, to update definitions.
%  
% Use NPC_STRIP_STRUCT to remove unwanted and empty fields prior to
% running, or after, as you prefer.
%
% Uses NPC_READ_REFERENCE NPC_READ_PLATFORCODESYS NPC_CHECK_PARAMETERS
% See also NPC NPC_INIT VALUETYPE

% This function requires hardcoding when data model of PhysChem changes!

% Last updated: Fri Jul 19 14:57:47 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,4,nargin));
if isempty(mission),	edisp('NPC_VALIDATE_STRUCT : Empty input!',4,4); return;	end
if nargin < 4 | isempty(API),		API=false;	end
if nargin < 3 | isempty(levlim),	levlim=1;	end
if nargin < 2 | isempty(opt),		opt='';		end

% Init:
load npc_init	% Load valid fieldnames, some full tables, and URLs:
err=false;	% Init error flag

% Activate options:
if contains(opt,'addnames'), addnames=true; else, addnames=false; end

% Activate switches for what is mandatory when testing ... 
if API % mission from PhysChem DB or planned to be posted to API:
  absolutelyMandatoryMissionFields    = exportMandatoryMissionFields    ;
  absolutelyMandatoryOperationFields  = exportMandatoryOperationFields  ;
  absolutelyMandatoryInstrumentFields = exportMandatoryInstrumentFields ;
  absolutelyMandatoryParameterFields  = exportMandatoryParameterFields  ;
  absolutelyMandatoryReadingFields    = exportMandatoryReadingFields    ;
  parametertests = '45';
else % mission from from various instrumentation on the outside (some DB-internal fields cannot be demanded): 
  absolutelyMandatoryMissionFields    = importMandatoryMissionFields    ;
  absolutelyMandatoryOperationFields  = importMandatoryOperationFields  ;
  absolutelyMandatoryInstrumentFields = importMandatoryInstrumentFields ;
  absolutelyMandatoryParameterFields  = importMandatoryParameterFields  ;
  absolutelyMandatoryReadingFields    = importMandatoryReadingFields    ;
  parametertests = '5';
end

% MISSION FIELDS:
% missionNumber key is always needed here since it is the upper level, but may be reassigned by NMDphyschem system.
% missionTypeName and platformName are no longer mandatory, but will be filled below (hardcoded). 
% So will callSignal

% OPERATION FIELDS:
% operationType and operationNumber are mandatory keys in base, and for input files!
% operationNumber key is assigned by NMDphyschem system and will just be numbering of structure fields here.
	% operation(operationNumber*) cannot be tested (internal to struct and ignored in NMDphyschem):
	% Quality flags for operation meta will added and set to zero below.

% INSTRUMENT FIELDS:
% instrumentNumber key is assigned by NMDphyschem system and will just be numbering of structure fields here.
% instrumentType is not a key, but crucial.
% instrumentProperty is optional as field and has no value type as it is sub-level.
	% instrumentNumber* cannot be tested (internal to struct and ignored in NMDphyschem):

% PARAMETER FIELDS:
% parameterNumber key is assigned by NMDphyschem system and will just be numbering of structure fields here.
% ordinal is assigned by NMDphyschem system, but should be given for input files if more than one of the same parameter.
% suppliedParameterName and suppliedUnits cannot be optional here, even though they are optional in the data model, 
% since we need to translate when importing data from other files.
% parameterCode and units are mandatory in base and can be generated upon file ingestion
% to base, but NPC_VALIDATE_STRUCT can fill them by adressing PhyscChemReference API.
	% parameter(parameterNumber*) cannot be tested (internal to struct and ignored in NMDphyschem)
	% The supplied fields cannot be mandatory, and they are tested above if parameterCode and units are missing.

% READING FIELDS: 
% [√] value has three different types, dependent on the parameter, so may
% have to use CONTAINS when validating struct (valuedatetime, valueint,
% valuedec, valuestr). Solved by creating the function VALUETYPE in EVENMAT-library.
% n is not valid for NMDphyschem (yet), but temporarily used for output files here.
	% sampleNumber cannot be tested 


% PROGRAM PARAMETERS
% Operations:
ON=length(mission.operation); 
opsteps=unique(round(linspace(1,ON,7))); % For limiting non-critical messages
orglevlim=levlim; % Original levlim, so that levlim can change below
edisp(strcat("NPC_VALIDATE_STRUCT : There ",are(ON)," ",int2str(ON)," operation",plurals(ON)," in this mission."),1,levlim); 
edisp(strcat("NPC_VALIDATE_STRUCT : Will display all messages only from operation",plurals(opsteps)," ",zipnumstr(opsteps),"."),1,levlim); 

% For range tests of positions, logs, and bottomdepths (fields with Start and End):
coord     = { 'longitude' 'latitude' 'log'   'bottomDepth'}; 
coordlims = { [-180 180]  [-90 90]   [0 1e5] [0 11e3]	};

% For range tests of conditions, depending of correct units, and taken from general ranges in the world:
conditions = { 'windSpeed' 'windDirection' 'airTemperature' 'wetBulbTemperature' 'airPressureAtSeaLevel' 'surfaceSpecificHumidity' 'surfaceRelativeHumidity' 'seaSurfaceTemperature' 'surfacePar' };
condlims   = { [0 99]      [0 360]         [-40 40]         [0 35]               [800 1100]              [0 30]                    [0 100]                   [-2.5 40]               [0 2000]	  };
condunits  = { 'm/s'       'deg T'         'degC'           'degC'               'mBar'                  'g/kg'                    '%'                       'degC'                  'uE/m^2/s'	  };

% For checking and setting quality at operationlevel:
opx        = [ "timeStart"        "timeEnd"        "longitudeStart"       "longitudeEnd"       "latitudeStart"        "latitudeEnd"        "operationPressure"        "logStart"        "logEnd"	];
opxquality = [ "timeStartQuality" "timeEndQuality" "positionStartQuality" "positionEndQuality" "positionStartQuality" "positionEndQuality" "operationPressureQuality" "logStartQuality" "logEndQuality"	];

% Names to check and fill against pre-read (p) reference tables at operation (o) level:  
pocodnam = [ "operationType"     "featureType"     "stationType"            "weather"            "clouds"            "sea"             ]; 
porefnam = [ "operationType"     "featureType"     "stationtype"            "weather"            "clouds"            "sea"             ];
ponamnam = [ "operationTypeName" "featureTypeName" "stationTypeDescription" "weatherDescription" "cloudsDescription" "seaDescription"  ]; 
pofienam = [ "name"              "name"            "description"            "description"        "description"       "description"     ]; 
% Names to check and fill against (large tables in) NMDreference (n) reference table at operation (o) level:  
nocodnam = [ ]; 
norefnam = [ ];
nonamnam = [ ]; 
nofienam = [ ]; 
% Names to check and fill against pre-read (p) reference tables at instrument (i) level:  
picodnam = [ "instrumentType"     "instrumentDataOwner"     ]; 
pirefnam = [ "instrumentType"     "institution"             ];
pinamnam = [ "instrumentTypeName" "instrumentDataOwnerName" ]; 
pifienam = [ "name"               "name"                    ]; 
% Names to check and fill against (large tables in) NMDreference (n) at instrument (i) level:  
nicodnam = [ "equipment"	]; 
nirefnam = [ "equipment"	];  
ninamnam = [ "equipmentName"	]; 
nifienam = [ "name"         	]; 
% Names to check and fill against physchem (p) reference tables at parameter (p) level:
ppcodnam = [ "parameterCode"	"processingLevel"	"acquirementMethod"	"nrtqcMethod"		"dmqcMethod"		"calibrationMethod"	"sensorOrientation"     ]; 
pprefnam = [ "parameterDefinition" "processingLevel"	"method"		"method"		"method"		"method"		"sensorOrientation"     ];
ppnamnam = [ "parameterName"	"processingLevelName"	"acquirementMethodName"	"nrtqcMethodName"	"dmqcMethodName"	"calibrationMethodName"	"sensorOrientationName" ]; 
ppfienam = [ "name"        	"name"			"name"                	"name"           	"name"          	"name"                 	"name"                  ]; 

% Names to fill some mandatory fields that could be empty on delivery at parameter level:
mannam = [ "parameterCode"		"units"		]; % mandatory field in struct
supnam = [ "suppliedParameterName"	"suppliedUnits" ]; % supplied-field in struct
tabnam = [ "suppliedParameter"		"suppliedUnits" ]; % table from API
felnam = [ "parameterCode"		"units"		]; % field name in table




%%%%%% CHECK THE MISSION (TOP) LEVEL FIELDS: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% CHECK VALIDITY OF FIELD NAMES:
nam=fieldnames(mission);						% The fields present
hasproperty=any(strcmp(nam,'missionProperty'));				% Are there missionproperties?
nam=setdiff(nam,{'missionProperty','operation'});			% Reduce list to those to check
errnam=setdiff(nam,allMissionNam);					% Invalid field names present
mission=rmfield(mission,errnam);					% Remove invalid fields
if ~isempty(errnam)
  edisp(strcat({'NPC_VALIDATE_STRUCT : WARNING! Mission level field name '},errnam,{' is not valid! REMOVED.'}),2,levlim);
end
[nam,~,i]=intersect(string(nam'),allMissionNam,'stable');		% Indices for valid names present now
namtyp=allMissionNamTyp(i);						% The types of the valid, now present fields  

% CHECK FOR MISSING OR EMPTY MANDATORY FIELDS:
% But missionTypeName and platformName will be filled below. 
for i=1:length(absolutelyMandatoryMissionFields)
  try
    getfield(mission,absolutelyMandatoryMissionFields(i));
  catch 
    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Mandatory mission level field '",absolutelyMandatoryMissionFields(i),"' missing!"),4,levlim);
    err=true; continue
  end
  if isempty(ans)
    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Mandatory mission level field '",absolutelyMandatoryMissionFields(i),"' cannot be empty!"),4,levlim);
    err=true; 
  end
end

% TRANSFORM ALL FIELDS TO CORRECT VALUETYPE:
if length(nam)~=length(namtyp),
  error('Number of mission level names and types not matching!');
else
  clear t
  for i=1:length(nam)
    [x,t.(nam{i})]=valuetype(mission.(nam{i}),namtyp(i));
    if isempty(t.(nam{i}))
      edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Value ",num2str(mission.(nam{i}))," of mission.",nam{i}," is not of proper type or format!"),4,levlim);
      err=true;
    else
      mission.(nam{i})=x;
    end
  end
end

% CHECK AND FILL AGAINST NMDREFERENCE (large table; direct call to API):  
% missionType* + missionTypeName
[content,msg,status] = npc_read_reference('missionType',mission.missionType,'name');
% Invalid call
if status >= 3, err=true;
elseif any(strcmp(nam,'missionTypeName')) % field exists, check contents
  if ~isempty(mission.missionTypeName) && ~strcmp(mission.missionTypeName,content) 
    % 1 0 field has right name => makes no difference to fill it
    % 0 field is empty => must be filled regardless
    msg=strcat("WARNING! mission.missionTypeName was '",mission.missionTypeName,"'! ",msg);
  end
  mission.missionTypeName=content;  
  % field does not exist => can be filled only if addnames
elseif addnames	
  mission.missionTypeName=content;  
end
edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.missionType."),status,levlim);

% startYear*
[YYYY,~]=datevec(now); 
if mission.startYear < 1900 | YYYY < mission.startYear
  edisp(['NPC_VALIDATE_STRUCT : ERROR! Unrealistic startYear ',num2str(mission.startYear),' outside 1900-',num2str(YYYY),'.'],4,levlim);
  mission.startYear = ''; 
  err=true;
end

% CHECK AGAINST NMDREFERENCE (very large table; direct call to API):  
% platform*
[~,msg,status] = npc_read_reference('platform',mission.platform);
edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.platform."),status,levlim);
if status >= 3, err=true; 
else
  % FILL FROM NMDREFERENCE PLATFORM CODESYS
  % platformName 
  [content,msg,status] = npc_read_platformcodesys(mission.platform,'Ship name',mission.missionStartDate);
  if status >= 3, err=true;			% Invalid platform code or inaccessible API 
  elseif any(strcmp(nam,'platformName'))	% field exists, check contents:
    if ~isempty(mission.platformName) && ~strcmp(mission.platformName,content) 
      msg=strcat("WARNING! mission.platformName was '",mission.platformName,"'! ",msg);
    end
    mission.platformName=content;
  elseif addnames
    mission.platformName=content;
  end
  edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.platform."),status,levlim);
  % callSignal
  [content,msg,status] = npc_read_platformcodesys(mission.platform,'ITU Call Sign',mission.missionStartDate);
  if status >= 3, err=true;			% Invalid platform code or inaccessible API 
  elseif any(strcmp(nam,'callSignal'))		% field exists, check contents:
    if ~isempty(mission.callSignal) && ~strcmp(mission.callSignal,content) 
      msg=strcat("WARNING! mission.callSignal was '",mission.callSignal,"'! ",msg);
    end
    mission.callSignal=content;
  else						% We add callsignal in any case as long as it can be found
    mission.callSignal=content;
  end
end % if platform is valid

% missionNumber* Only valueType of missionNumber can be tested (done above)


% CHECK REALISM OF SOME FIELDS
% missionStartDate must be realistic:
if t.missionStartDate < datenum(1900,1,1) | now < t.missionStartDate | any(datestr(t.missionStartDate,29)~=mission.missionStartDate(1:10))
  edisp(['NPC_VALIDATE_STRUCT : ERROR! Unrealistic missionStartDate ',mission.missionStartDate(1:10),'!'],4,levlim); 
  err=true;
end 
% missionStopDate must be realistic:
% no check on stopdate since missions may be defined longer than the year
if t.missionStopDate < datenum(1900,1,1) | any(datestr(t.missionStopDate,29)~=mission.missionStopDate(1:10))
  edisp(['NPC_VALIDATE_STRUCT : ERROR! Unrealistic missionStopDate ',mission.missionStopDate(1:10),'!'],4,levlim);
  err=true;
end


% OPTIONAL MISSION FIELDS:
% [] cruise is only for cruises, check against Cruise API??
% [] deployment/retrievalMission must be code to existing mission /4/2018/1173/2/ (Cruise API or PhysChem API): 
% [] csrRefNo should be found by system, when ready, but would be cool to find here too.


% CHECK AND FILL AGAINST NMDREFERENCE (from pre-read table):
% responsibleLaboratory + responsibleLaboratoryName (NMDreference:institution):
if any(strcmp(nam,{'responsibleLaboratory'})) & ~isempty(mission.responsibleLaboratory)
  [content,msg,status] = npc_read_reference(institution,mission.responsibleLaboratory,'name');
  if status >=3, err=true;
  elseif any(strcmp(nam,'responsibleLaboratoryName')) % field exists, check contents:
    if ~isempty(mission.responsibleLaboratoryName) && ~strcmp(mission.responsibleLaboratoryName,content) 
      msg=strcat("WARNING! mission.responsibleLaboratoryName was '",mission.responsibleLaboratoryName,"'! ",msg);
    end
    mission.responsibleLaboratoryName=content;
  elseif addnames
    mission.responsibleLaboratoryName=content;
  end
  edisp(strcat("NPC_VALIDATE_STRUCT : ",msg,"."),status,levlim);
end
% [] mission.responsibleLaboratoryName not erased; possibility for
% backward filling? Maybe with NPC_READ_REFERENCE? This is likely not
% wise to do here, as this function is primarily for validation. Users
% are well advised to use that feature of NPC_READ_REFERENCE when
% creating a struct for validation.

% ADD EXTRA QUALITY FLAG INFORMATION:
% qualityFlagTableName may be added here:
if any(strcmp(nam,{'qualityFlagTableName'}))
  mission.qualityFlagTableName='EuroGOOS/SeaDatanet quality flag scale.';
  edisp(['NPC_VALIDATE_STRUCT : Added ''qualityFlagTableName'' field on mission level.'],1,levlim);
end
% flagValues & flagMeanings (pre-read from NMDreference:quality):
if ~isempty(Quality) % The pre-read table struct
  [qccodes,IA]=sort(cell2mat(egetfield(Quality,'code.Text')));
  if any(strcmp(nam,{'flagValues'})) | any(strcmp(nam,{'flagMeanings'}))
    mission.flagValues = cellstrcat(qccodes,' ');
    cellstr(replace(egetfield(Quality,'description.Text'),{' '},{'_'}));
    ans=ans(IA);
    mission.flagMeanings = cellstrcat(ans,' ');
    edisp(['NPC_VALIDATE_STRUCT : Added ''flagValues'' and ''flagMeanings'' fields on mission level.'],1,levlim);
  end
end
% qccodes will be used below

%----- CHECK THE MISSIONPROPERTY LEVEL FIELDS: -------------------------------------------------------
if hasproperty
  if ~isempty(missionPropertyType)
    n=length(mission.missionProperty);
    keep=true(1,n); 
    for IP=1:n
      code=mission.missionProperty(IP).code;
      % Valid code?
      [~,msg,status] = npc_read_reference(missionPropertyType,code);
      if status >= 3
	edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! ",msg," in mission.missionProperty(",int2str(IP),")."),status,levlim);
	keep(IP)=false;
      else
	% Valid valuetype?
	val=mission.missionProperty(IP).value;
	x=valuetype(val,npc_read_reference(missionPropertyType,code,'valueType'));
	if isempty(x) & ~isempty(val)
	  edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value type for missionProperty '",code,"'. mission.missionProperty(",int2str(IP),").value set to empty."),2,levlim);
	end
	mission.missionProperty(IP).value=x;	
      end % if valid code
	  % % Special rules:
	  % inv=false;
	  % switch code
	  %  case 'castfrom',		if ~strcmp(val,{'M','S',''}),	inv=true; end
	  % end
	  % if inv
	  %   edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value '",val,"' for missionProperty '",code,"'. mission.missionProperty(",int2str(IP),").value set to '' (empty)."),2,levlim);
	  %   mission.missionProperty(IP).value='';
	  % end
    end % for IP
    mission.missionProperty=mission.missionProperty(keep);
  end % has missionPropertyType
end % any missionProperty
%---------------------------------------------------------------------------------------------------------


%%%%%% CHECK THE OPERATION LEVEL FIELDS: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for O=1:ON
  
  % Do not show all messages when mission contains many operations:
  if orglevlim < 3 & ~ismember(O,opsteps), levlim=3; else, levlim=orglevlim; end
  
  % Display counter in case there are many operations:
  edisp(strcat("NPC_VALIDATE_STRUCT : Checking mission.operation{",int2str(O),"}."),1,levlim); 
  
  % CHECK VALIDITY OF FIELD NAMES:
  nam=fieldnames(mission.operation{O});					% The fields present
  hasproperty=any(strcmp(nam,'operationProperty'));			% Are there operationproperties?
  nam=setdiff(nam,{'operationProperty','instrument'});			% Reduce list to those to check
  errnam=setdiff(nam,allOperationNam);					% Invalid field names present
  mission.operation{O}=rmfield(mission.operation{O},errnam);		% Remove invalid fields
  if ~isempty(errnam)
    edisp(strcat({'NPC_VALIDATE_STRUCT : mission.operation{'},int2str(O),{'} field name '},errnam,{' is not valid! REMOVED.'}),2,levlim); 
  end
  [nam,~,i]=intersect(string(nam'),allOperationNam,'stable');	% Indices for valid names present now
  namtyp=allOperationNamTyp(i);					% The types of the valid, now present fields  
  
  % CHECK FOR MISSING OR EMPTY MANDATORY FIELDS:
  % operation(operationNumber*) cannot be tested (internal to struct and ignored in NMDphyschem):
  % Quality flags for operation meta will added and set to zero below.
  for i=1:length(absolutelyMandatoryOperationFields)
    try
      getfield(mission.operation{O},absolutelyMandatoryOperationFields(i));
    catch 
      edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Mandatory operation level field '",absolutelyMandatoryOperationFields(i),"' missing!"),4,levlim);
      err=true; continue % go to next field to avoid error in subsequent if
    end
    if isempty(ans)
      edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Mandatory operation level field '",absolutelyMandatoryOperationFields(i),"' cannot be empty!"),4,levlim);
      err=true;
    end
  end

  % FILL SOME FIELDS THAT COULD BE EMPTY ON DELIVERY:
  % timeStart/EndQuality 0-9 (NDMreference:quality, qccodes from above)
  % positionStart/EndQuality 0-9 (NDMreference:quality, qccodes from above)
  % logStart/EndQuality 0-9 (NDMreference:quality, qccodes from above)
  for i=1:length(opxquality)
    if any(strcmp(nam,opxquality(i)))			% If quality field exists
      if ~any(strcmp(nam,opx(i)))				% If value field doesn't exist  
	mission.operation{O}.(opxquality(i))='';
      else	
	if isempty(mission.operation{O}.(opx(i)))			% If value field is empty
	  mission.operation{O}.(opxquality(i))='';
	else
	  if isempty(mission.operation{O}.(opxquality(i)))						% If quality field is empty
	    mission.operation{O}.(opxquality(i))='0';
	    edisp(strcat('NPC_VALIDATE_STRUCT : Empty mission.operation{',int2str(O),'}.',opxquality(i),' set to ''0''.'),1,levlim);
	  elseif ~any(ismember(string(qccodes),num2str(mission.operation{O}.(opxquality(i)))))		% If quality field is wrong (not in table)
	    edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! mission.operation{',int2str(O),'}.',opxquality(i),{' '},int2str(mission.operation{O}.(opxquality(i))),' is not valid!'),4,levlim);
	    err=true;
	  end
	end
      end
    end    
  end

  % TRANSFORM ALL FIELDS TO CORRECT VALUETYPE:
  if length(nam)~=length(namtyp),
    error('Number of operation level names and types not matching!');
  else
    clear t
    for i=1:length(nam)
      [x,t.(nam{i})]=valuetype(mission.operation{O}.(nam{i}),namtyp(i));
      if isempty(t.(nam{i}))
	edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Value ",num2str(mission.operation{O}.(nam{i}))," of mission.operation{",num2str(O),"}.",nam{i}," is not of proper type or format!"),4,levlim);
	err=true;
      else
	mission.operation{O}.(nam{i})=x;
      end
    end
  end
 
  % CHECK VALIDITY OF CODES AND FILL NAMES (from pre-read tables)
  % operationType* & operationTypeName (Physchem Reference:operationType)
  % featureType* & featureTypeName (Physchem Reference:featureType)
  % stationType & stationTypeDescription (NDMreference:stationType)
  % weather, clouds, sea (NMDreference:weather, -clouds, -sea)
  % [pocodnam; porefnam;, ponamnam; pofienam] 
  % All PhysChem tables are small and pre-read and thus put directly into npc_read_reference.
  for i=1:length(pocodnam)
    if any(strcmp(nam,pocodnam(i))) & ~isempty(mission.operation{O}.(pocodnam(i)))
      eval(strcat("[content,msg,status] = npc_read_reference(",porefnam(i),",mission.operation{O}.(pocodnam(i)),pofienam(i));"));
      if status >= 3, err=true;
      elseif any(strcmp(nam,ponamnam(i))) % field exists, check contents:
	if ~isempty(mission.operation{O}.(ponamnam(i))) && ~strcmp(mission.operation{O}.(ponamnam(i)),content) 
	  msg=strcat("WARNING! mission.operation{",int2str(O),"}.",ponamnam(i)," was '",mission.operation{O}.(ponamnam(i)),"'! ",msg);
	end
	mission.operation{O}.(ponamnam(i))=content;  
      elseif addnames
	mission.operation{O}.(ponamnam(i))=content;  
      end
      edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.operation{",int2str(O),"}.",pocodnam(i),"."),status,levlim);
    end	  
  end	
    
  % CHECK AND FILL AGAINST NMDREFERENCE CODESYS:
  % operationPlatform* & operationPlatformName (NDMreference:platform):
  if any(strcmp(nam,{'operationPlatform'})) & ~isempty(mission.operation{O}.operationPlatform)
    % Using the serial day from the value type checking above is safer, given the variation in PhysChem DATETIME formats:
    [content,msg,status] = npc_read_platformcodesys(mission.operation{O}.operationPlatform,'Ship name',t.timeStart);
    if status >= 3, err=true;				% Invalid platform code or inaccessible API 
    elseif any(strcmp(nam,'operationPlatformName'))	% Field exists, check contents:
      if ~isempty(mission.operation{O}.operationPlatformName) && ~strcmp(mission.operation{O}.operationPlatformName,content) 
	msg=strcat("WARNING! mission.operation{",int2str(O),"}.operationPlatformName was '",mission.operation{O}.operationPlatformName,"'! ",msg);
      end
      mission.operation{O}.operationPlatformName=content;
    elseif addnames
      mission.operation{O}.operationPlatformName=content;
    end
    edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.operation{",int2str(O),"}.operationPlatform."),status,levlim);
  end
  
  % localCdiId can not be checked nor generated here!
  
  % CHECK VALUE OF SOME FIELDS:
  % timeStart/End* YYYY-MM-DDThh:mm:ss(Z) and realistic 1900-now:
  if any(strcmp(nam,{'timeStart'})) & any(strcmp(nam,{'timeEnd'}))
    t1=t.timeStart; t2=t.timeEnd; % datenum is run above
    if t1<693962 | now<t2 | t2<t1
      edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! mission.operation{',int2str(O),'}'," timeStart ",mission.operation{O}.timeStart," or timeEnd ",mission.operation{O}.timeEnd,' is outside of bounds 1900-now or in backward order or wrong format!'),4,levlim);
      err=true;
    end
  elseif any(strcmp(nam,{'timeStart'}))
    t1=t.timeStart;
    if t1<693962 | now<t1
      edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! mission.operation{',int2str(O),'}'," timeStart ",mission.operation{O}.timeStart,' is outside of bounds 1900-now or wrong format!'),4,levlim);
      err=true;
    end
  elseif any(strcmp(nam,{'timeEnd'}))
    t2=t.timeEnd;
    if t2<datenum(1900,1,1) | now<t2
      edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! mission.operation{',int2str(O),'}'," timeEnd ",mission.operation{O}.timeEnd,' is outside of bounds 1900-now or wrong format!'),4,levlim);
      err=true;
    end
  end
  % long/latitudeStart* and -End must be realistic:
  % logStart and -End must be realistic (1e4 nm is Bergen to San
  % Fransisco by 10 knts in 40 days should be a fair maximum for our
  % cruises and missions).
  % bottomDepthStart and -End must be realistic:
  for i=1:length(coord) 
    if any(strcmp(nam,{[coord{i},'Start']})), t1=mission.operation{O}.([coord{i},'Start']);
    else, t1=[]; end
    if any(strcmp(nam,{[coord{i},'End']})), t2=mission.operation{O}.([coord{i},'End']);
    else, t2=[]; end
    if ~isempty(t1) & ~isempty(t2)
      if t1<coordlims{i}(1) | coordlims{i}(2)<t2 | t2<t1
	edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! In mission.operation{',int2str(O),"} ",[coord{i},'Start']," ",num2str(mission.operation{O}.([coord{i},'Start']))," or ",[coord{i},'End']," ",num2str(mission.operation{O}.([coord{i},'End']))," are out of bounds ",num2str(coordlims{i}(1)),"-",num2str(coordlims{i}(2)),", or in oposite order!"),4,levlim);
	  err=true;
      end
    elseif ~isempty(t1)
      if t1<coordlims{i}(1) | coordlims{i}(2)<t1
	edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! In mission.operation{',int2str(O),"} ",[coord{i},'Start']," ",num2str(mission.operation{O}.([coord{i},'Start']))," is out of bounds ",num2str(coordlims{i}(1)),"-",num2str(coordlims{i}(2)),"!"),4,levlim);
	err=true;
      end
    elseif ~isempty(t2)
      if t2<coordlims{i}(1) | coordlims{i}(2)<t2
	edisp(strcat('NPC_VALIDATE_STRUCT : ERROR! In mission.operation{',int2str(O),"} ",[coord{i},'End']," ",num2str(mission.operation{O}.([coord{i},'End']))," is out of bounds ",num2str(coordlims{i}(1)),"-",num2str(coordlims{i}(2)),"!"),4,levlim);
	err=true;
      end
    end
  end
  % windspeed, etc.
  for i=1:length(conditions) 
    if any(strcmp(nam,conditions{i})), t1=mission.operation{O}.(conditions{i});
    else, t1=[]; end
    if ~isempty(t1)
      if t1<condlims{i}(1) | condlims{i}(2)<t1
	edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! In mission.operation{",int2str(O),"}.",conditions{i}," ",num2str(t1)," is out of bounds ",num2str(condlims{i}(1)),"-",num2str(condlims{i}(2))," ",condunits{i},"!"),4,levlim);
	err=true;
      end
    end
  end

  %----- CHECK THE OPERATIONPROPERTY LEVEL FIELDS: -------------------------------------------------------
  if hasproperty
    if ~isempty(operationPropertyType)
      n=length(mission.operation{O}.operationProperty);
      keep=true(1,n); 
      for IP=1:n
	code=mission.operation{O}.operationProperty(IP).code;
	% Valid code?
	[~,msg,status] = npc_read_reference(operationPropertyType,code);
	if status >= 3
	  edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! ",msg," in mission.operation{",int2str(O),"}.operationProperty(",int2str(IP),")."),status,levlim);
	  keep(IP)=false;
	else
	  % Valid valuetype?
	  val=mission.operation{O}.operationProperty(IP).value;
	  x=valuetype(val,npc_read_reference(operationPropertyType,code,'valueType'));
	  if isempty(x) & ~isempty(val)
	    edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value type for operationProperty '",code,"'. mission.operation{",int2str(O),"}.operationProperty(",int2str(IP),").value set to empty."),2,levlim);
	  end
	  mission.operation{O}.operationProperty(IP).value=x;	
	end % if valid code
	% % Special rules:
	% inv=false;
	% switch code
	%  case 'castFrom',		if ~strcmp(val,{'M','S',''}),	inv=true; end
	% end
	% if inv
	%   edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value '",val,"' for operationProperty '",code,"'. mission.operation{",int2str(O),"}.operationProperty(",int2str(IP),").value set to '' (empty)."),2,levlim);
	%   mission.operation{O}.operationProperty(IP).value='';
	% end
      end % for IP
      mission.operation{O}.operationProperty=mission.operation{O}.operationProperty(keep);
    end % has operationPropertyType
  end % any operationProperty
  %---------------------------------------------------------------------------------------------------------

  
  
  %%%%%% CHECK THE INSTRUMENT LEVEL FIELDS: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  for I=1:length(mission.operation{O}.instrument)
    %mission.operation{O}.instrument{I};

    % CHECK VALIDITY OF FIELD NAMES:
    nam=fieldnames(mission.operation{O}.instrument{I});				% The fields present
    hasproperty=any(strcmp(nam,'instrumentProperty'));				% Are there instrumentproperties?
    nam=setdiff(nam,{'instrumentProperty','parameter'});			% Reduce list to those to check
    errnam=setdiff(nam,allInstrumentNam);					% Invalid field names present
    mission.operation{O}.instrument{I}=rmfield(mission.operation{O}.instrument{I},errnam);	% Remove invalid fields
    if ~isempty(errnam)
      edisp(strcat({'NPC_VALIDATE_STRUCT : mission.operation{'},int2str(O),{'}.instrument{'},int2str(I),{'} field name '''},errnam,{''' is not valid! REMOVED.'}),2,levlim);
    end
    [nam,~,i]=intersect(string(nam'),allInstrumentNam,'stable');				% Indices for valid names present now
    namtyp=allInstrumentNamTyp(i);								% The types of the valid, now present fields  
    
    % CHECK FOR MISSING OR EMPTY MANDATORY FIELDS:
    % instrumentNumber* cannot be tested (internal to struct and ignored in NMDphyschem):
    for i=1:length(absolutelyMandatoryInstrumentFields)
      try
	getfield(mission.operation{O}.instrument{I},absolutelyMandatoryInstrumentFields(i));
      catch 
	edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! mission.operation{",int2str(O),"}.instrument{",int2str(I),"} mandatory instrument level field '",absolutelyMandatoryInstrumentFields(i),"' missing!"),4,levlim);
	err=true; continue % go to next field to avoid error in subsequent if
      end
      if isempty(ans)
	edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! mission.operation{",int2str(O),"}.instrument{",int2str(I),"} mandatory instrument level field '",absolutelyMandatoryInstrumentFields(i),"' cannot be empty!"),4,levlim);
	err=true; 
      end
    end

    % TRANSFORM ALL FIELDS TO CORRECT VALUETYPE:
    if length(nam)~=length(namtyp),
      error('Number of instrument level names and types not matching!');
    else
      clear t
      for i=1:length(nam)
	[x,t.(nam{i})]=valuetype(mission.operation{O}.instrument{I}.(nam{i}),namtyp(i));
	if isempty(t.(nam{i}))
	  edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Value ",num2str(mission.operation{O}.instrument{I}.(nam{i}))," of mission.operation{",num2str(O),"}.instrument{",num2str(I),"}.",nam{i}," is not of proper type or format!"),4,levlim)
	  err=true;
	else
	  mission.operation{O}.instrument{I}.(nam{i})=x;
	end
      end
    end

    % CHECK VALIDITY OF CODES AND FILL NAMES (from pre-read tables):
    % instrumentType & instrumentTypeName (Physchem Reference:instrumentType)
    % instrumentDataOwner & instrumentDataOwnerName (NMDreference:institution):
    % [picodnam; pirefnam; pinamnam; pifienam]
    % All PhysChem tables are small and pre-read and thus put directly into npc_read_reference.
    for i=1:length(picodnam)
      if any(strcmp(nam,picodnam(i))) & ~isempty(mission.operation{O}.instrument{I}.(picodnam(i)))
	eval(strcat("[content,msg,status] = npc_read_reference(",pirefnam(i),",mission.operation{O}.instrument{I}.(picodnam(i)),pifienam(i));"));
	if status >= 3, err=true; 
	elseif any(strcmp(nam,pinamnam(i))) % field exists, check contents:
	  if ~isempty(mission.operation{O}.instrument{I}.(pinamnam(i))) && ~strcmp(mission.operation{O}.instrument{I}.(pinamnam(i)),content) 
	    msg=strcat("WARNING! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.",pinamnam(i)," was '",mission.operation{O}.instrument{I}.(pinamnam(i)),"'! ",msg);
	  end
	  mission.operation{O}.instrument{I}.(pinamnam(i))=content;  
	elseif addnames
	  mission.operation{O}.instrument{I}.(pinamnam(i))=content;  
	end
	edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.",picodnam(i),"."),status,levlim);
      end	  
    end	
    
    % CHECK AND FILL AGAINST NMDREFERENCE (large table; direct call to API):
    % equipment & equipmentName (NDMreference:equipment):
    % [nicodnam; nirefnam; ninamnam; nifienam]
    for i=1:length(nicodnam)
      if any(strcmp(nam,nicodnam(i))) & ~isempty(mission.operation{O}.instrument{I}.(nicodnam(i)))
	[content,msg,status] = npc_read_reference(nirefnam(i),mission.operation{O}.instrument{I}.(nicodnam(i)),nifienam(i));
	if status >= 3, err=true; 
	elseif any(strcmp(nam,ninamnam(i))) % field exists, check contents:
	  if ~isempty(mission.operation{O}.instrument{I}.(ninamnam(i))) && ~strcmp(mission.operation{O}.instrument{I}.(ninamnam(i)),content) 
	    msg=strcat("WARNING! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.",ninamnam(i)," was '",mission.operation{O}.instrument{I}.(ninamnam(i)),"'! ",msg);
	  end
	  mission.operation{O}.instrument{I}.(ninamnam(i))=content;  
	elseif addnames
	  mission.operation{O}.instrument{I}.(ninamnam(i))=content;  
	end
	edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.",nicodnam(i),"."),status,levlim);
      end	  
    end	
        

    %----- CHECK THE INSTRUMENTPROPERTY LEVEL FIELDS: -------------------------------------------------------
    if hasproperty
      if ~isempty(instrumentPropertyType)
	n=length(mission.operation{O}.instrument{I}.instrumentProperty);
	keep=true(1,n); 
	for IP=1:n
	  code=mission.operation{O}.instrument{I}.instrumentProperty(IP).code;
	  % Valid code?
	  [~,msg,status] = npc_read_reference(instrumentPropertyType,code);
	  if status >= 3
	    edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! ",msg," in mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.instrumentProperty(",int2str(IP),")."),status,levlim);
	    keep(IP)=false;
	  else
	    % Valid valuetype?
	    val=mission.operation{O}.instrument{I}.instrumentProperty(IP).value;
	    x=valuetype(val,npc_read_reference(instrumentPropertyType,code,'valueType'));
	    if isempty(x) & ~isempty(val)
	      edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value type for instrumentProperty '",code,"'. mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.instrumentProperty(",int2str(IP),").value set to empty."),2,levlim);
	    end
	    mission.operation{O}.instrument{I}.instrumentProperty(IP).value=x;	
	  end % if valid code
	  % Special rules:
	  inv=false;
	  switch code
	   case 'castFrom',		if ~strcmp(val,{'M','S',''}),	inv=true; end
	   case 'profileDirection',	if ~strcmp(val,{'D','A','M',''}),inv=true; end 
	   case 'thrusters',		if ~strcmp(val,{'Y',''}),	inv=true; end
	  end
	  if inv
	    edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value '",val,"' for instrumentProperty '",code,"'. mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.instrumentProperty(",int2str(IP),").value set to '' (empty)."),2,levlim);
	    mission.operation{O}.instrument{I}.instrumentProperty(IP).value='';
	  end
	end % for IP
	mission.operation{O}.instrument{I}.instrumentProperty=mission.operation{O}.instrument{I}.instrumentProperty(keep);
      end % has instrumentPropertyType
    end % any instrumentProperty
    %---------------------------------------------------------------------------------------------------------

    
		
    
    
    %%%%%% CHECK THE PARAMETER LEVEL FIELDS: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for P=1:length(mission.operation{O}.instrument{I}.parameter)
      
      % CHECK VALIDITY OF FIELD NAMES:
      nam=fieldnames(mission.operation{O}.instrument{I}.parameter{P});			% The fields present
      hasproperty=any(strcmp(nam,'parameterProperty'));					% Are there parameterproperties?
      nam=setdiff(nam,{'parameterProperty','reading'});					% Reduce list to those to check
      errnam=setdiff(nam,allParameterNam);						% Invalid field names present
      mission.operation{O}.instrument{I}.parameter{P}=rmfield(mission.operation{O}.instrument{I}.parameter{P},errnam);	% Remove invalid named fields
      if ~isempty(errnam)
	edisp(strcat({'NPC_VALIDATE_STRUCT : mission.operation{'},int2str(O),{'}.instrument{'},int2str(I),{'}.parameter{'},int2str(P),{'} field name '''},errnam,{''' is not valid! REMOVED.'}),2,levlim);
      end
      [nam,~,i]=intersect(string(nam'),allParameterNam,'stable');			% Indices for valid names present now and reduce to valid field names present
      namtyp=allParameterNamTyp(i);							% The types of the valid, now present fields  
      
      % FILL SOME MANDATORY FIELDS THAT COULD BE EMPTY ON DELIVERY:
      % processingLevel* (if not given, assume 'L0')
      if any(strcmp(nam,'processingLevel')); 
	if isempty(mission.operation{O}.instrument{I}.parameter{P}.processingLevel)
	  mission.operation{O}.instrument{I}.parameter{P}.processingLevel='L0';
	  edisp(strcat("NPC_VALIDATE_STRUCT : Empty mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.processingLevel set to 'L0'."),2,levlim);
	end
      end
      % parameterCode* <- suppliedParameterName (PhysChemReference:suppliedParameter)
      % units* <- suppliedUnits (PhysChemReference:suppliedUnits)
      % (mannam, supnam, tabnam, felnam)
      for i=1:length(mannam)	
	if any(strcmp(nam,supnam(i)))												% Need supplied field to do this 
	  eval(strcat('k=find(strcmp({',tabnam(i),'.name},mission.operation{O}.instrument{I}.parameter{P}.',supnam(i),'));'));
	  if isempty(k)	& isempty(mission.operation{O}.instrument{I}.parameter{P}.(mannam(i)))					% If supplied field empty or not defined in table, and code not filled, error!
	    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Empty mandatory mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.",mannam(i)," could not be set!"),4,levlim);
	    err=true; 
	  elseif isempty(mission.operation{O}.instrument{I}.parameter{P}.(mannam(i)))						% If code is not filled, fill by supplied.
	    mission.operation{O}.instrument{I}.parameter{P}.(mannam(i))=eval(strcat(tabnam(i),'(k).',felnam(i)));
	    edisp(strcat("NPC_VALIDATE_STRUCT : Based on ",supnam(i)," '",mission.operation{O}.instrument{I}.parameter{P}.(supnam(i)),"' mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.",(mannam(i))," is set to '",mission.operation{O}.instrument{I}.parameter{P}.(mannam(i)),"'."),2,levlim);
	  elseif ~isempty(k)													% If both code and supplied is filled
	    if ~strcmp(mission.operation{O}.instrument{I}.parameter{P}.(mannam(i)),eval(strcat(tabnam(i),'(k).',felnam(i))))	% check for match, and if mismatch issue error.
	      edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Mismatch between ",supnam(i)," '",mission.operation{O}.instrument{I}.parameter{P}.(supnam(i)),"' and ",mannam(i)," '",mission.operation{O}.instrument{I}.parameter{P}.(mannam(i)),"' in mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}!"),4,levlim);
	      err=true; 
	    end
	  end % empty etc. if		% If only code filled, it will be checked below.
	end % supplied if
      end % mannam loop
      % Add the missing units field in some cases

      % CHECK FOR MISSING OR EMPTY MANDATORY FIELDS:
      % parameter(parameterNumber*) cannot be tested (internal to struct and ignored in NMDphyschem)
      % The supplied fields cannot be mandatory, and they are tested above if parameterCode and units are missing.
      for i=1:length(absolutelyMandatoryParameterFields)
	try
	  getfield(mission.operation{O}.instrument{I}.parameter{P},absolutelyMandatoryParameterFields(i));
	catch 
	  edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"} (",mission.operation{O}.instrument{I}.instrumentType,".",mission.operation{O}.instrument{I}.parameter{P}.parameterCode,") mandatory parameter level field '",absolutelyMandatoryParameterFields(i),"' missing!"),4,levlim);
	  err=true; continue
	end
	if isempty(ans)
	  edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"} mandatory parameter level field '",absolutelyMandatoryParameterFields(i),"' cannot be empty!"),4,levlim);
	  err=true; continue % go to next field to avoid error in subsequent if
	end
      end
      
      % TRANSFORM ALL FIELDS TO CORRECT VALUETYPE:
      if length(nam)~=length(namtyp),
	error('Number of parameter level names and types not matching!');
      else
	clear t
	for i=1:length(nam)
	  [x,t.(nam{i})]=valuetype(mission.operation{O}.instrument{I}.parameter{P}.(nam{i}),namtyp(i));
	  if isempty(t.(nam{i}))
	    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Value ",num2str(mission.operation{O}.instrument{I}.(nam{i}))," of mission.operation{",num2str(O),"}.instrument{",num2str(I),"}.parameter{",num2str(P),"}.",nam{i}," is not of proper type or format!"),4,levlim);
	    err=true;
	  else
	    mission.operation{O}.instrument{I}.parameter{P}.(nam{i})=x;
	  end
	end
      end

      % CHECK VALIDITY OF CODES AND FILL NAMES, AGAINST PHYSCHEM REFERENCE (from pre-read tables):
      % [ppcodnam; pprefnam; ppnamnam; ppfienam]
      % All PhysChem tables are small and pre-read and thus put directly into npc_read_reference.
      for i=1:length(ppcodnam)
	if any(strcmp(nam,ppcodnam(i))) & ~isempty(mission.operation{O}.instrument{I}.parameter{P}.(ppcodnam(i)))
	  eval(strcat("[content,msg,status] = npc_read_reference(",pprefnam(i),",mission.operation{O}.instrument{I}.parameter{P}.(ppcodnam(i)),ppfienam(i));"));
	  if status >= 3, err=true; 
	  elseif any(strcmp(nam,ppnamnam(i))) % field exists, check contents:
	    if ~isempty(mission.operation{O}.instrument{I}.parameter{P}.(ppnamnam(i))) && ~strcmp(mission.operation{O}.instrument{I}.parameter{P}.(ppnamnam(i)),content) 
	      msg=strcat("WARNING! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.",ppnamnam(i)," was '",mission.operation{O}.instrument{I}.parameter{P}.(ppnamnam(i)),"'! ",msg);
	    end
	    mission.operation{O}.instrument{I}.parameter{P}.(ppnamnam(i))=content;  
	  elseif addnames
	    mission.operation{O}.instrument{I}.parameter{P}.(ppnamnam(i))=content;  
	  end
	  edisp(strcat("NPC_VALIDATE_STRUCT : ",msg," for mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.",ppcodnam(i),"."),status,levlim);
	end	  
      end	
      
      
      % CHECK AND FILL AGAINST NMDREFERENCE n/a for parameter level.
      
      % CHECK CONSISTENCY OF PARTICULAR PARAMETER FIELDS
      % ordinal cannot be tested other than valueType above and consistency below
      % [] Check units validity as P06
      % [√] suppliedUnits vs units should match if both exist
      % [below on instrument level] Check for duplicate parameters without correct use of ordinal, also with respect to sensor sereialnumbers 
      
      
      
      %----- CHECK THE PARAMETERPROPERTY LEVEL FIELDS: -------------------------------------------------------
      if hasproperty
	if ~isempty(parameterPropertyType)
	  n=length(mission.operation{O}.instrument{I}.parameter{P}.parameterProperty);
	  keep=true(1,n); 
	  for IP=1:n
	    code=mission.operation{O}.instrument{I}.parameter{P}.parameterProperty(IP).code;
	    % Valid code?
	    [~,msg,status] = npc_read_reference(parameterPropertyType,code);
	    if status >= 3
	      edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! ",msg," in mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.parameterProperty(",int2str(IP),")."),status,levlim);
	      keep(IP)=false;
	    else
	      % Valid valuetype?
	      val=mission.operation{O}.instrument{I}.parameter{P}.parameterProperty(IP).value;
	      x=valuetype(val,npc_read_reference(parameterPropertyType,code,'valueType'));
	      if isempty(x) & ~isempty(val)
		edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value type for parameterProperty '",code,"'. mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.parameterProperty(",int2str(IP),").value set to empty."),2,levlim);
	      end
	      mission.operation{O}.instrument{I}.parameter{P}.parameterProperty(IP).value=x;	
	    end % if valid code
	    % Special rules:
	    if ~isempty(x)
	      inv=false;
	      switch code
	       case 'calibrationCoordinate', try, tmp2=webread(strcat(URL.PhysChemReference,'parameter')); if ~any(strcmp({tmp2.code},x)), inv=true; end; end
	      end
	      if inv
		edisp(strcat("NPC_VALIDATE_STRUCT : WARNING! Invalid value '",val,"' for parameterProperty '",code,"'. mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.parameterProperty(",int2str(IP),").value set to '' (empty)."),4,levlim);
		  mission.operation{O}.instrument{I}.parameter{P}.parameterProperty(IP).value='';
	      end
	    end % isempty x
	  end % for IP
	  mission.operation{O}.instrument{I}.parameter{P}.parameterProperty=mission.operation{O}.instrument{I}.parameter{P}.parameterProperty(keep);
	end % has tmp
      end % any parameterProperty
      %-------------------------------------------------------------------------------------------------------


	

      
      %%%%%% CHECK THE READING LEVEL FIELDS: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      RN=length(mission.operation{O}.instrument{I}.parameter{P}.reading);
      edisp(strcat("NPC_VALIDATE_STRUCT : There ",are(RN)," ",int2str(RN)," reading",plurals(RN)," in this parameter."),1,levlim); 

      for R=1:RN

	% CHECK VALIDITY OF FIELD NAMES:
	nam=fieldnames(mission.operation{O}.instrument{I}.parameter{P}.reading(R));	% The fields present
	%%%hasproperty=any(strcmp(nam,'readingproperty'));				% Are there readingproperties? Never!
	nam=setdiff(nam,{'value','readingproperty'});					% Reduce list to those to check
	errnam=setdiff(nam,allReadingNam);						% Invalid field names present
	mission.operation{O}.instrument{I}.parameter{P}.reading(R)=rmfield(mission.operation{O}.instrument{I}.parameter{P}.reading(R),errnam);	% Remove invalid fields
	if ~isempty(errnam)
	  edisp(strcat({'NPC_VALIDATE_STRUCT : mission.operation{'},int2str(O),{'}.instrument{'},int2str(I),{'}.parameter{'},int2str(P),{'}.reading('},int2str(R),{') field name '''},errnam,{''' is not valid! REMOVED.'}),2,levlim);
	end
	[nam,~,i]=intersect(string(nam'),allReadingNam,'stable');			% Indices for valid names present now
	namtyp=allReadingNamTyp(i);							% The types of the valid, now present fields  
	%%~strcmp(namtyp,""); nam=nam(ans); namtyp=nantyp(ans);				% Fields that cannot be checked are identified in NPC_INIT 
	
	% ASSIGN SOME MANDATORY FIELDS THAT COULD BE EMPTY ON DELIVERY:
	% All parameter.reading.quality set to '0' if empty:
	% valueType will be corrected below.
	if isfield(mission.operation{O}.instrument{I}.parameter{P}.reading(R),'quality')
	  if isempty(mission.operation{O}.instrument{I}.parameter{P}.reading(R).quality)
	    mission.operation{O}.instrument{I}.parameter{P}.reading(R).quality = zeros(size(mission.operation{O}.instrument{I}.parameter{P}.reading(R).value)); 
	  elseif size(mission.operation{O}.instrument{I}.parameter{P}.reading(R).quality)~=size(mission.operation{O}.instrument{I}.parameter{P}.reading(R).value)
	    error([mission.operation{O}.instrument{I}.parameter{P}.suppliedParameterName,' has inconsistent size readings!']);
	  end
	end

	% CHECK FOR MISSING OR EMPTY MANDATORY FIELDS:
	for i=1:length(absolutelyMandatoryReadingFields)
	  try
	    getfield(mission.operation{O}.instrument{I}.parameter{P}.reading(R),absolutelyMandatoryReadingFields(i));
	  catch 
	    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.reading(",int2str(R),") mandatory reading level field '",absolutelyMandatoryReadingFields(i),"' missing!"),4,levlim);
	    err=true; continue
	  end
	  if isempty(ans)
	    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! mission.operation{",int2str(O),"}.instrument{",int2str(I),"}.parameter{",int2str(P),"}.reading(",int2str(R),") mandatory reading level field '",absolutelyMandatoryReadingFields(i),"' cannot be empty!"),4,levlim);
	    err=true; 
	  end
	end
	
	% TRANSFORM ALL FIELDS TO CORRECT VALUETYPE:
	if length(nam)~=length(namtyp),
	  error('Number of reading level names and types not matching!');
	else
	  clear t
	  for i=1:length(nam)					% Loop the fields in the reading.
	    val=mission.operation{O}.instrument{I}.parameter{P}.reading(R).(nam{i});
	    % if length(val) <= 1 || ischar(val)			% PhysChem API delivers readings with single values and
	    %   [x,t.(nam{i})]=valuetype(val,namtyp(i));		% then we can check and set each.
	    % else						% From instrument data we normally put all readings in vectors in one reading element and 
	    %   [~,t.(nam{i})]=valuetype(val(1),namtyp(i));	% then we can just check (with a bogus setting of the first one).
	    % end
	    [x,t.(nam{i})]=valuetype(val,namtyp(i));
	    if isempty(t.(nam{i}))
	      edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! Value ",num2str(val)," of mission.operation{",num2str(O),"}.instrument{",num2str(I),"}.parameter{",num2str(P),"}.reading(",num2str(R),").",nam{i}," is not of proper type or format!"),4,levlim)
	      err=true;
	    else 
	      %if length(val) <= 1 | ischar(val)			% It is only when we have checked everything (the single) that we can assign corrected value type.
		mission.operation{O}.instrument{I}.parameter{P}.reading(R).(nam{i})=x;
	      %end
	    end
	  end
	end

	% CHECK AND FILL AGAINST PHYSCHEM REFERENCE n/a for reading level
	
	% CHECK AND FILL AGAINST NMDREFERENCE:
	% quality (Physchem Reference:instrumentType) only check:    
	% The valid qccodes are already collected from reference base.
	% num2str makes this robust.
	% Works also for vector with all readings in one reading element, since setdiff compares all.
	if isfield(mission.operation{O}.instrument{I}.parameter{P}.reading(R),'quality')
	  if any(setdiff(num2str(mission.operation{O}.instrument{I}.parameter{P}.reading(R).quality(:)),qccodes))
	    edisp(strcat("NPC_VALIDATE_STRUCT : ERROR! There are invalid quality flags in mission.operation{",num2str(O),"}.instrument{",num2str(I),"}.parameter{",num2str(P),"}.reading(",num2str(R),") !"),4,levlim);
	    err=true;
	  else
	    % If OK, also check if there should be some '9' at empty values:
	    isnan(mission.operation{O}.instrument{I}.parameter{P}.reading(R).value);
	    mission.operation{O}.instrument{I}.parameter{P}.reading(R).quality(ans)='9';
	  end
	end	

      end % readings
     
      % Some parameter fields must be treated after subfields:
      % processingLevel is 'L0' if all parameter.reading.quality is '0':
      % Made robust with num2str in case it is decided value type is INT. 
      if isfield(mission.operation{O}.instrument{I}.parameter{P},'processingLevel')
	getallfields(mission.operation{O}.instrument{I}.parameter{P},'quality');
	if any(ans) && ~any(setdiff(str2num(ans),[0 9]))      % Simple 9 (missing) could have been added without any QC done
	  edisp(strcat("NPC_VALIDATE_STRUCT : Setting processingLevel 'L0' for mission.operation{",num2str(O),"}.instrument{",num2str(I),"}.parameter{",num2str(P),"}",...
		       " since the only quality flags are 0 or 9."),1,levlim);
	  mission.operation{O}.instrument{I}.parameter{P}.processingLevel='L0';
	end
      end
      
    end % parameters


    % CHECK CONSISTENCY BETWEEN PARTICULAR PARAMETER FIELDS
    edisp(strcat("NPC_VALIDATE_STRUCT : Checking consistency within parameter fields for mission.operation{",num2str(O),"}.instrument{",num2str(I),"}"),1,levlim);
    [msg,status]=npc_check_parameters(mission.operation{O}.instrument{I},parametertests);
    if status >= 3
      edisp(strcat("NPC_VALIDATE_STRUCT : BUG! ",strvcat(unique(msg'))," in mission.operation{",int2str(O),"}.instrument{",int2str(I),"} (",mission.operation{O}.instrument{I}.instrumentType,")."),status,levlim);
      err=true;
    end
    
    
  end % instruments
  
end % operations


if ~contains(opt,'ignore') & err
  edisp('NPC_VALIDATE_STRUCT : Invalid struct!',4,levlim); mission=struct([]);
end

% NOTES:

% ------ Draw out and fill any other fields from the codes in related field: ------
% missionTypeName (NDMreference):
% platformName (NDMreference):

% cruise is only for cruises, can it be filled from Cruise API??:
% csrRefNo from PhysChem API if exists already?:
% -
% operationPlatform is same as platform in some cases, in other cases it must be filled:
% -
% equipment could for some cases be filled here (7114 is Seabird CTD) maybe search NMDreference:equipment API:
% -
% parameterCode generate in Physchem Reference:Suppliedparameter from suppliedParameterName, and retest against Physchem Reference:ParameterDefinition:
% units generate in Physchem Reference:SuppliedUnits from suppliedUnits:




  


% struct2cell(s.parameter); ans(3,:)

% for i=1:size(s.parameter,1)
%   %  if isfield(s.parameter(i).reading,'quality'), 
%   if isempty(s.parameter(i).reading.quality), s.parameter(i).reading.quality='0'; end 
%   %    end
% end


%%s.parameter(7).reading.quality


% [] remember to fill reference lists in table in https://confluence.imr.no/display/SP/6+Feltene+i+NMDphyschem

% ----- All mandatory filds must be filled now: -----

% ----- Strip away any invalid fields: -----
% n
% add warnings

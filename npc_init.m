function npc_init()
% NPC_INIT	Updates base of valid fieldnames etc. for NMDphyschem
% 
% No input or output. Inquires the necessary APIs, updates objects with
% URLs and field names, and saves to mat file as reference for all NPC
% functions.
%
% URLs to APIs are stored in a struct called URL. Names and value types
% of fields are stored in the following string objects.
%
% The smaller and often used tables are also read into structs from the
% NMDreference and PhysChem Reference APIs: "Quality" "institution"
% (from NMDreference) "operationType" "featureType" "instrumentType"
% "suppliedParameter" "suppliedUnits" "parameter" "processingLevel"
% "method" "sensorOrientation" (from PhysChem Reference).
%
% For all levels string objects with names of fields:
%   ___ = Mission / Operation / Instrument / Parameter / Reading
%   mandatory___Fields		- names of mandatory fields in model API
%   optional___Fields		- names of optional fields in model API
%   additional___Fields		- names of additional fields not found in
%				  model API, but desireable to have in files 
%   ***___FieldTypes		- correct valuetypes for all the above names
%				  (e.g., 'DEC', 'STR, 'DATETIME')  
%   exportMandatory___Fields	- names of mandatory fields for the API
%   importMandatory___Fields	- names of mandatory fields for import
%
% For all levels except reading:
%   ___PropertyTypeCodes      - read from PhysChemReference:___PropertyType
%   ___PropertyTypeValueTypes - read from PhysChemReference:___PropertyType
%
% For specific levels: 
%   conditionOperationFields  - names of fields related to weater etc.
%
% This is where you edit most of the static information, throughout this
% file, to the bottom.
%
% Results are saved in npc_init.mat in toolbox directory, and you can
% 'load npc_init' from anywhere to access these parameters and tables.
%
% Use TYPE NPC_INIT to see notes about the field-name organisation.
%
% Documentation on PhysChem's fields: https://confluence.imr.no/x/4AKzBg
%
% Used by almost all NPC functions.
% Uses toktnummer_regler.txt  
% See also NPC WEBREAD XML2STRUCT

% Last updated: Fri Jul 19 17:35:23 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(0,0,nargin));

% Location of toolbox:
ans=which('npc_init'); ans=dir(ans); 
tooldir=ans.folder

% Load existing fieldnames:
if exist([tooldir,filesep,'npc_init.mat'],'file'), load([tooldir,filesep,'npc_init']); end

% API addresses:
clear URL
URL.base		= 'https://physchem-api-test.hi.no/';
URL.physchem		= [URL.base,'mission/search/findMissionByUniqueConstraint?'];
URL.physchemDescription = '?version=1.0';
URL.PhysChemReference	= 'https://physchem-reference-api-test.hi.no/';
URL.tomcat		= 'http://tomcat7.imr.no:8080/';
URL.NMDreference	= 'http://tomcat7.imr.no:8080/apis/nmdapi/reference/v2/model/';
URL.NMDreferenceDescription='?version=2.0';
URL.NMDreferenceEditor	= 'https://referenceeditor.hi.no/apps/referenceeditor/v2/tables/';
URL.NMDcruise		= 'http://tomcat7.imr.no:8080/apis/nmdapi/cruise/v2';

%apiDocs = webread('https://physchem-api-staging.hi.no/api-docs')
apiDocs = webread([URL.base,'api-docs']);
%https://git.imr.no/digital-utvikling/applications/physchem/physchem-api/-/raw/develop/src/main/java/no/imr/physchemapi/model/Mission.java?ref_type=heads
% (nullable = false) 
% Mission.java
% Operation.java 
% ...

% OPTIONS FOR WEBREAD:
woptions=weboptions('ContentType','text','Timeout',20); % make webread give json and wait longer

% Define fillvalues for use in outfiles.  Matlab uses its NaNs while
% NMDphyschem simply displays nothing or whole elements are missing when
% data are missing, but for files we need to fill something:
fillvalue.STR='';
fillvalue.DEC=-999999.0;
fillvalue.INT=-999999;
fillvalue.FLT=-999999.0;

% THE PLATFORM LIST USED FOR CRUSE NUMBERING:
shipnumbers=readtable('toktnummer_regler.txt');			
shipnumbers.Fart_y= replace(shipnumbers.Fart_y,'. ','.');

% GET SOME FULL TABLES  HERE:
physChemTables = [ "missionPropertyType" "operationPropertyType" "instrumentPropertyType" "parameterPropertyType" ...
		   "collectionType" "methodGroup" "parameterGroup" "valueType" ...
		   "operationType" "instrumentType" "featureType" "suppliedParameter" "suppliedUnits" ...
		   "parameterDefinition" "processingLevel" "method" "sensorOrientation"];

refnam=[ "Quality" "institution" "stationtype" "weather" "clouds" "sea" ];	% From NMDreference
refnam=[ refnam , physChemTables ];						% From both
for i=1:length(refnam)
  try
    if ismember(refnam(i),{'Quality','institution','stationtype','weather','clouds','sea'})	% From NMDreference
      url=strcat(URL.NMDreference,refnam(i),URL.NMDreferenceDescription);
      eval(strcat(refnam(i),'=xml2struct(webread(url));'));
    else
      url=strcat(URL.PhysChemReference,refnam(i));
      eval(strcat(refnam(i),'=webread(url);'));
    end
    lastAPIupdate.(refnam(i)) = now;
    disp(strcat("Successful API access (",url,"). Updated table struct '",refnam(i),"' now on ",datestr(lastAPIupdate.(refnam(i))),"."));
  catch
    warning(strcat("API access failed (",url,")! Keeping table struct '",refnam(i),"' from ",datestr(lastAPIupdate.(refnam(i))),"."));
  end
end


% MISSION FIELDS:
% missionNumber key is needed here since it is the upper level, but may be reassigned by NMDphyschem system.
% missionTypeName and platformName are mandatory in base and can be generated upon file ingestion
% to base, but NPC_VALIDATE_STRUCT can fill them by adressing NMDreference API.
% Get all fields:
missionFields = string(fieldnames(apiDocs.components.schemas.MissionDTO.properties))';
missionFields = setdiff(missionFields,["operation"],'stable');	% Remove the next level from list of fields at this level
% Get all types:
n=numel(missionFields);
missionFieldTypes=string(nan(1,n));
for i=1:n
  apiDocs.components.schemas.MissionDTO.properties.(missionFields(i));
  missionFieldTypes(i) = string(ans.type);
  try, missionFieldTypes(i) = string(ans.format); end
end
% Translate types:
missionFieldTypes = replace(missionFieldTypes,'string','STR');
missionFieldTypes = replace(missionFieldTypes,{'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'},'INT');
missionFieldTypes = replace(missionFieldTypes,'number','DEC');
missionFieldTypes = replace(missionFieldTypes,'date-time','DATETIME');
missionFieldTypes = replace(missionFieldTypes,'array','');
% Sort out mandatory from optional fields by hardcoding (suboptimal, but at least it checks for content): 
nominalMandatoryMissionFields = ["missionType" "startYear" "platform" "missionNumber" ...
		    "missionStartDate" "missionStopDate"];
[mandatoryMissionFields,IA] = intersect(missionFields,nominalMandatoryMissionFields,'stable');
% Check that the API actually has the mandatory fields:
if ~isempty(setdiff(mandatoryMissionFields,nominalMandatoryMissionFields))
  error('The data model (api Doc) does not contain the mandatory mission fields specified for PhysChem!');
end
mandatoryMissionFieldTypes  = missionFieldTypes(IA);
[optionalMissionFields,IA] = setdiff(missionFields,mandatoryMissionFields,'stable');
optionalMissionFieldTypes  = missionFieldTypes(IA);
% Additional fields used by this toolbox:
additionalMissionFields     = [ "responsibleLaboratoryName" "qualityFlagTableName" "flagValues" "flagMeanings" ]; 	
additionalMissionFieldTypes = [ "STR"                       "STR"                  "STR"        "STR"          ]; 
% The flexible properties:
try
  tmp=missionPropertyType;
  missionPropertyTypeCodes = replace(strip(string(char(tmp.code)))',{'-'},'');
  missionPropertyTypeValueTypes = strip(string(char(tmp.valueType)))';
  lastAPIupdate.missionPropertyType = now;
  disp(['Updated table structs ''missionPropertyTypeCodes'' and ''missionPropertyTypeValueTypes'' now on ',datestr(lastAPIupdate.missionPropertyType),'.']);
catch 
  warning(['Keeping table structs ''missionPropertyTypeCodes'' and ''missionPropertyTypeValueTypes'' from ',datestr(lastAPIupdate.missionPropertyType),'.']);
end


% OPERATION FIELDS:
% operationtype and operationnumber are mandatory keys in base, and for input files!
% operationnumber key is assigned by NMDphyschem system and will just be numbering of structure fields here.
operationFields = string(fieldnames(apiDocs.components.schemas.OperationDTO.properties))';
operationFields = setdiff(operationFields,["instrumentTypeList" "instrument"],'stable');	% Remove the next level from list of fields at this level
% Get all types/formats:
n=numel(operationFields);
operationFieldTypes=string(nan(1,n));
for i=1:n
  apiDocs.components.schemas.OperationDTO.properties.(operationFields(i));
  operationFieldTypes(i) = string(ans.type);
  try, operationFieldTypes(i) = string(ans.format); end
end
% Translate types/formats:
operationFieldTypes = replace(operationFieldTypes,'string','STR');
operationFieldTypes = replace(operationFieldTypes,{'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'},'INT');
operationFieldTypes = replace(operationFieldTypes,'number','DEC');
operationFieldTypes = replace(operationFieldTypes,'date-time','DATETIME');
operationFieldTypes = replace(operationFieldTypes,'array','');
% Sort out mandatory from optional fields by hardcoding (suboptimal, but at least it checks for content): 
nominalMandatoryOperationFields = ["operationType" "operationNumber" ...
		    "localCdiId" "operationPlatform" "timeStart" "timeStartQuality" "longitudeStart" "latitudeStart" "positionStartQuality" ...
		    "featureType"];
[mandatoryOperationFields,IA] = intersect(operationFields,nominalMandatoryOperationFields,'stable');
if ~isempty(setdiff(mandatoryOperationFields,nominalMandatoryOperationFields))
  error('The data model (api Doc) does not contain the mandatory operation fields specified for PhysChem!');
end
mandatoryOperationFieldTypes  = operationFieldTypes(IA);
% This toolbox separates out the optional fields concerning conditions at time of operation:
[conditionOperationFields,IA] = intersect(operationFields,[ "bottomDepthStart" "bottomDepthEnd" ...
		    "windSpeed" "windDirection" "airTemperature" "wetBulbTemperature" "airPressureAtSeaLevel" "surfaceSpecificHumidity" "surfaceRelativeHumidity" ...
		    "surfacePar" "seaSurfaceTemperature"  "weather" "clouds" "sea" "ice" "significantWaveHeight" ],'stable');     
conditionOperationFieldTypes   = operationFieldTypes(IA);
% The rest are just optional:
[optionalOperationFields,IA]  = setdiff(operationFields,[mandatoryOperationFields,conditionOperationFields],'stable');
optionalOperationFieldTypes   = operationFieldTypes(IA);
% Additional fields used by this toolbox:
additionalOperationFields     = [ "operationTypeName" "operationPlatformName" "featureTypeName" "weatherDescription" "cloudsDescription" "seaDescription" "iceDescription" "stationTypeDescription" ];
additionalOperationFieldTypes = [ "STR"               "STR"                   "STR"             "STR"                "STR"               "STR"            "STR"            "STR"                    ];
% The flexible properties:
try
  tmp=operationPropertyType;
  operationPropertyTypeCodes = replace(strip(string(char(tmp.code)))',{'-'},'');
  operationPropertyTypeValueTypes = strip(string(char(tmp.valueType)))';
  lastAPIupdate.operationPropertyType = now;
  disp(['Updated table structs ''operationPropertyTypeCodes'' and ''operationPropertyTypeValueTypes'' now on ',datestr(lastAPIupdate.operationPropertyType),'.']);
catch 
  warning(['Keeping table structs ''operationPropertyTypeCodes'' and ''operationPropertyTypeValueTypes'' from ',datestr(lastAPIupdate.operationPropertyType),'.']);
end


% INSTRUMENT FIELDS:
% instrumentid key is assigned by NMDphyschem system and will just be numbering of structure fields here.
% instrumenttype is not a key, but crucial.
% instrumentproperty is optional as field and has no value type as it is sub-level.
instrumentFields = string(fieldnames(apiDocs.components.schemas.InstrumentDTO.properties))';
instrumentFields = setdiff(instrumentFields,["parameter"],'stable');	% Remove the next level from list of fields at this level
% Get all types/formats:
n=numel(instrumentFields);
instrumentFieldTypes=string(nan(1,n));
for i=1:n
  apiDocs.components.schemas.InstrumentDTO.properties.(instrumentFields(i));
  instrumentFieldTypes(i) = string(ans.type);
  try, instrumentFieldTypes(i) = string(ans.format); end
end
% Translate types/formats:
instrumentFieldTypes = replace(instrumentFieldTypes,'string','STR');
instrumentFieldTypes = replace(instrumentFieldTypes,{'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'},'INT');
instrumentFieldTypes = replace(instrumentFieldTypes,'number','DEC');
instrumentFieldTypes = replace(instrumentFieldTypes,'date-time','DATETIME');
instrumentFieldTypes = replace(instrumentFieldTypes,'array','');
% Sort out mandatory from optional fields by hardcoding (suboptimal, but at least it checks for content): 
nominalMandatoryInstrumentFields = ["instrumentType" "instrumentNumber"];
[mandatoryInstrumentFields,IA] = intersect(instrumentFields,nominalMandatoryInstrumentFields,'stable');
if ~isempty(setdiff(mandatoryInstrumentFields,nominalMandatoryInstrumentFields))
  error('The data model (api Doc) does not contain the mandatory instrument fields specified for PhysChem!');
end
mandatoryInstrumentFieldTypes  = instrumentFieldTypes(IA);
[optionalInstrumentFields,IA]  = setdiff(instrumentFields,mandatoryInstrumentFields,'stable');
optionalInstrumentFieldTypes   = instrumentFieldTypes(IA);
% Additional fields used by this toolbox:
additionalInstrumentFields     = [ "instrumentTypeName" "equipmentName" "instrumentDataownerName" ];
additionalInstrumentFieldTypes = [ "STR"                "STR"           "STR"                     ];
% The flexible properties:
try
  tmp=instrumentPropertyType;
  instrumentPropertyTypeCodes = replace(strip(string(char(tmp.code)))',{'-'},'');
  instrumentPropertyTypeValueTypes = strip(string(char(tmp.valueType)))';
  lastAPIupdate.instrumentPropertyType = now;
  disp(['Updated table structs ''instrumentPropertyTypeCodes'' and ''instrumentPropertyTypeValueTypes'' now on ',datestr(lastAPIupdate.instrumentPropertyType),'.']);
catch 
  warning(['Keeping table structs ''instrumentPropertyTypeCodes'' and ''instrumentPropertyTypeValueTypes'' from ',datestr(lastAPIupdate.instrumentPropertyType),'.']);
end

% PARAMETER FIELDS:
% parameterid key is assigned by NMDphyschem system and will just be numbering of structure fields here.
% ordinal is assigned by NMDphyschem system, but should be given for input files if more than one of the same parameter.
% suppliedparametername and suppliedunits cannot be optional here, even though they are optional in the data model, 
% since we need to translate when importing data from other files.
% parametercode and units are mandatory in base and can be generated upon file ingestion
% to base, but NPC_VALIDATE_STRUCT can fill them by adressing PhyscChemReference API.
% ordinal is moved to optional here and should change to optional in the API since never used on primary parameters.
parameterFields = string(fieldnames(apiDocs.components.schemas.ParameterDTO.properties))';
parameterFields = setdiff(parameterFields,["reading"],'stable');	% Remove the next level from list of fields at this level
% Get all types/formats:
n=numel(parameterFields);
parameterFieldTypes=string(nan(1,n));
for i=1:n
  apiDocs.components.schemas.ParameterDTO.properties.(parameterFields(i));
  parameterFieldTypes(i) = string(ans.type);
  try, parameterFieldTypes(i) = string(ans.format); end
end
% Translate types/formats:
parameterFieldTypes = replace(parameterFieldTypes,'string','STR');
parameterFieldTypes = replace(parameterFieldTypes,{'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'},'INT');
parameterFieldTypes = replace(parameterFieldTypes,'number','DEC');
parameterFieldTypes = replace(parameterFieldTypes,'date-time','DATETIME');
parameterFieldTypes = replace(parameterFieldTypes,'array','');
% Sort out mandatory from optional fields by hardcoding (suboptimal, but at least it checks for content): 
nominalMandatoryParameterFields = ["parameterNumber" "parameterCode" "ordinal" ...
		    "units" "processingLevel" "acquirementMethod"];
[mandatoryParameterFields,IA] = intersect(parameterFields,nominalMandatoryParameterFields,'stable');
if ~isempty(setdiff(mandatoryParameterFields,nominalMandatoryParameterFields))
  error('The data model (api Doc) does not contain the mandatory parameter fields specified for PhysChem!');
end
mandatoryParameterFieldTypes  = parameterFieldTypes(IA);
[optionalParameterFields,IA]  = setdiff(parameterFields,mandatoryParameterFields,'stable');
optionalParameterFieldTypes   = parameterFieldTypes(IA);
% Additional fields used by this toolbox:
additionalParameterFields     = [ "parameterName" "processingLevelName" "acquirementMethodName" "sensorOrientationName" "nrtqcMethodName" "dmqcMethodName" "calibrationMethodName" ];
additionalParameterFieldTypes = [ "STR"           "STR"                 "STR"                   "STR"                   "STR"             "STR"            "STR"                   ];
% The flexible properties:
try
  tmp=parameterPropertyType;
  parameterPropertyTypeCodes = replace(strip(string(char(tmp.code)))',{'-'},'');
  parameterPropertyTypeValueTypes = strip(string(char(tmp.valueType)))';
  lastAPIupdate.parameterPropertyType = now;
  disp(['Updated table structs ''parameterPropertyTypeCodes'' and ''parameterPropertyTypeValueTypes'' now on ',datestr(lastAPIupdate.parameterPropertyType),'.']);
catch
  warning(['Keeping table structs ''parameterPropertyTypeCodes'' and ''parameterPropertyTypeValueTypes'' from ',datestr(lastAPIupdate.parameterPropertyType),'.']);
end


% READING FIELDS: 
% [√] value has three different types, dependent on the parameter, so may
% have to use CONTAINS when validating struct (valuedatetime, valueint,
% valuedec, valuestr). Solved by creating the funfction VALUETYPE.
% n is not valid for NMDphyschem (yet), but temporarily used for
% output files here.
readingFields = string(fieldnames(apiDocs.components.schemas.ReadingDTO.properties))';
readingFields = setdiff(readingFields,["valueDateTime" "valueStr" "valueInt"],'stable'); % Remove the type-specific value fieldnames
% Get all types/formats:
n=numel(readingFields);
readingFieldTypes=string(nan(1,n));
for i=1:n
  apiDocs.components.schemas.ReadingDTO.properties.(readingFields(i));
  readingFieldTypes(i) = string(ans.type);
  try, readingFieldTypes(i) = string(ans.format); end
end
% Translate types/formats:
readingFieldTypes = replace(readingFieldTypes,'string','STR');
readingFieldTypes = replace(readingFieldTypes,{'int8' 'int16' 'int32' 'int64' 'uint8' 'uint16' 'uint32' 'uint64'},'INT');
readingFieldTypes = replace(readingFieldTypes,'number','DEC');
readingFieldTypes = replace(readingFieldTypes,'date-time','DATETIME');
readingFieldTypes = replace(readingFieldTypes,'array','');
% Merge the value fields into one:
[readingFields,IA] = setdiff(readingFields,["valueDateTime" "valueStr" "valueInt"],'stable');
readingFields = replace(readingFields,"valueDec","value");						
readingFieldTypes = readingFieldTypes(IA);
% Sort out mandatory from optional fields by hardcoding (suboptimal, but at least it checks for content): 
nominalMandatoryReadingFields = ["sampleNumber" "value" "quality"];
[mandatoryReadingFields,IA] = intersect(readingFields,nominalMandatoryReadingFields,'stable');
if ~isempty(setdiff(mandatoryReadingFields,nominalMandatoryReadingFields))
  error('The data model (api Doc) does not contain the mandatory reading fields specified for PhysChem!');
end
mandatoryReadingFieldTypes  = readingFieldTypes(IA);
[optionalReadingFields,IA]  = setdiff(readingFields,mandatoryReadingFields,'stable');
optionalReadingFieldTypes   = readingFieldTypes(IA);
% Additional fields used by this toolbox:
additionalReadingFields     = [""];
additionalReadingFieldTypes = [""];
% None.

% All valid field names and types of all valid field names for the different levels:
allMissionNam       = [ mandatoryMissionFields		optionalMissionFields     	additionalMissionFields		];
allMissionNamTyp    = [ mandatoryMissionFieldTypes	optionalMissionFieldTypes	additionalMissionFieldTypes	];
allOperationNam     = [ mandatoryOperationFields	optionalOperationFields		additionalOperationFields	conditionOperationFields	];
allOperationNamTyp  = [ mandatoryOperationFieldTypes	optionalOperationFieldTypes	additionalOperationFieldTypes	conditionOperationFieldTypes	];
allInstrumentNam    = [ mandatoryInstrumentFields	optionalInstrumentFields	additionalInstrumentFields	];
allInstrumentNamTyp = [ mandatoryInstrumentFieldTypes	optionalInstrumentFieldTypes	additionalInstrumentFieldTypes	];
allParameterNam     = [ mandatoryParameterFields	optionalParameterFields		additionalParameterFields	];
allParameterNamTyp  = [ mandatoryParameterFieldTypes	optionalParameterFieldTypes	additionalParameterFieldTypes	];
allReadingNam       = [ mandatoryReadingFields		optionalReadingFields		additionalReadingFields		];
allReadingNamTyp    = [ mandatoryReadingFieldTypes	optionalReadingFieldTypes	additionalReadingFieldTypes	];

% Which are mandatory fields are different for the DB & API itself (export) and for import files.
% For mission from PhysChem DB or planned to be posted to API:
[exportMandatoryMissionFields    ,IA]= setdiff(mandatoryMissionFields,  	[""]);
 exportMandatoryMissionFieldTypes    = mandatoryMissionFieldTypes(IA)		;
[exportMandatoryOperationFields  ,IA]= setdiff(mandatoryOperationFields,	[""]);
 exportMandatoryOperationFieldTypes  = mandatoryOperationFieldTypes(IA)		;
[exportMandatoryInstrumentFields ,IA]= setdiff(mandatoryInstrumentFields,	[""]);
 exportMandatoryInstrumentFieldTypes = mandatoryInstrumentFieldTypes(IA)	;
[exportMandatoryParameterFields  ,IA]= setdiff(mandatoryParameterFields,	[""]);
 exportMandatoryParameterFieldTypes  = mandatoryParameterFieldTypes(IA)		;
[exportMandatoryReadingFields    ,IA]= setdiff(mandatoryReadingFields,		[""]);
 exportMandatoryReadingFieldTypes    = mandatoryReadingFieldTypes(IA)		;
% Mission from various instrumentation on the outside (some DB-internal
% fields cannot be demanded, but will instead be generated by PhysChem's
% importer/converter):
[importMandatoryMissionFields    ,IA]= setdiff(mandatoryMissionFields,  	[ "id" ]);
 importMandatoryMissionFieldTypes    = mandatoryMissionFieldTypes(IA)		;
[importMandatoryOperationFields  ,IA]= setdiff(mandatoryOperationFields,	[ "id" "operationNumber" "localCdiId" "timeStartQuality" "positionStartQuality" ]);
 importMandatoryOperationFieldTypes  = mandatoryOperationFieldTypes(IA)		;
[importMandatoryInstrumentFields ,IA]= setdiff(mandatoryInstrumentFields,	[ "id" "instrumentNumber" ]);
 importMandatoryInstrumentFieldTypes = mandatoryInstrumentFieldTypes(IA)	;
[importMandatoryParameterFields  ,IA]= setdiff(mandatoryParameterFields,	[ "id" "parameterNumber" "ordinal" "processingLevel" ]);
 importMandatoryParameterFieldTypes  = mandatoryParameterFieldTypes(IA)		;
[importMandatoryReadingFields    ,IA]= setdiff(mandatoryReadingFields,		[ "id" "sampleNumber" "quality"]);
 importMandatoryReadingFieldTypes    = mandatoryReadingFieldTypes(IA)		;

% SAVE OBJECTS IN TOOLBOX DIRECTORY:"suppliedParameter" "suppliedUnits"  ];
clear url tmp refnam i ans 
save([tooldir,filesep,'npc_init']);
disp(['NPC_INIT : Saved NPC init objects to ',tooldir,filesep,'npc_init.mat.']);

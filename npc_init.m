function npc_init()
% NPC_INIT	Updates base of valid fieldnames for NMDphyschem
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
%   mandatory___Fields	- names of mandatory fields in model API
%   optional___Fields	- names of optional fields in model API
%   additional___Fields	- names of additional fields not found in
%			  model API, but desireable to have in files 
%   _________FieldTypes	- correct valuetypes for all the above names
%			  (e.g. 'DEC', 'STR, 'DATETIME')  
%
% For specific levels: 
%   conditionOperationFields		- names of fields related to
%					  weater etc.
%   instrumentPropertyTypeCodes		- read from
%					  PhysChemReference:instrumentproperty
%   instrumentPropertyTypeValueTypes	- read from 
%					  PhysChemReference:instrumentproperty
%   parameterPropertyTypeCodes		- read from 
%					  PhysChemReference:parameterproperty
%   parameterPropertyTypeValueTypes	- read from 
%					  PhysChemReference:parameterproperty
%
% Results are saved in npc_init.mat in toolbox directory, and
% you can 'load npc_init' from anywhere to access these
% parameters and tables.
%
% Use TYPE NPC_INIT to see notes about the field-name organisation.
%
% Used by almost all NPC functions.
% Uses toktnummer_regler.txt  
% See also NPC WEBREAD XML2STRUCT

% Last updated: Wed Dec 13 11:33:36 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(0,0,nargin));

% Location of toolbox:
ans=which('npc_init'); ans=dir(ans); 
tooldir=ans.folder;

% Load existing fieldnames:
if exist([tooldir,filesep,'npc_init.mat'],'file'), load([tooldir,filesep,'npc_init']); end

% API addresses:
clear URL
URL.physchem		= 'https://physchem-api-staging.hi.no/apis/nmdapi/physchem/v1/dataset/';
URL.physchemDescription = '?version=1.0';
URL.PhysChemReference	= 'https://physchem-reference-api-staging.hi.no/apis/nmdapi/physchem-reference-api/v1/';
URL.tomcat		= 'http://tomcat7.imr.no:8080/';
URL.NMDreference	= 'http://tomcat7.imr.no:8080/apis/nmdapi/reference/v2/model/';
URL.NMDreferenceDescription='?version=2.0';
URL.NMDreferenceEditor	= 'https://referenceeditor.hi.no/apps/referenceeditor/v2/tables/';
URL.NMDcruise		= 'http://tomcat7.imr.no:8080/apis/nmdapi/cruise/v2';

% OPTIONS FOR WEBREAD:
woptions=weboptions('ContentType','text','Timeout',20); % make webread give json and wait longer

% THE PLATFORM LIST USED FOR CRUSE NUMBERING:
shipnumbers=readtable('toktnummer_regler.txt');			
shipnumbers.Fart_y= replace(shipnumbers.Fart_y,'. ','.');

% GET SOME FULL TABLES  HERE:
refnam=[ "Quality" "institution" "stationtype" "weather" "clouds" "sea" ];			% From NMDreference
refnam=[ refnam ...
	 "instrumentPropertyType" "parameterPropertyType" ...					% and from Physchem Reference
	 "operationType" "instrumentType" "featureType" "suppliedParameter" "suppliedUnits" "parameter" "processingLevel" "method" "sensorOrientation"];
for i=1:length(refnam)
  try
    if ismember(refnam(i),{'Quality','institution','stationtype','weather','clouds','sea'})	% From NMDreference
      url=strcat(URL.NMDreference,refnam(i),URL.NMDreferenceDescription);
      eval(strcat(refnam(i),'=xml2struct(webread(url));'));
    else
      url=strcat(URL.PhysChemReference,refnam(i));
      eval(strcat(refnam(i),'=webread(url);'));
    end
    lastAPIupdate.(refnam(i))=now;
    disp(strcat("Successful API access (",url,"). Updated table struct '",refnam(i),"' now on ",datestr(lastAPIupdate.(refnam(i))),"."));
  catch
    warning(strcat("API access failed (",url,")! Keeping table struct '",refnam(i),"' from ",datestr(lastAPIupdate.(refnam(i))),"."));
  end
end

% MISSION FIELDS:
% missionnumber key is needed here since it is the upper level, but may be reassigned by NMDphyschem system.
% missiontypename and platformname are mandatory in base and can be generated upon file ingestion
% to base, but NPC_VALIDATE_STRUCT can fill them by adressing NMDreference API.
mandatoryMissionFields      = [ "missiontype" "startyear" "platform" "missionnumber" "missiontypename" "platformname" "missionstartdate" "missionstopdate" ];
mandatoryMissionFieldTypes  = [ "STR"         "INT"       "STR"      "INT"           "STR"             "STR"          "DATE"             "DATE"            ];
optionalMissionFields       = [ "callsignal" "cruise" "purpose" "missionname" "deploymentmission" "retrievalmission" "csrrefno" "responsiblelaboratory" "chiefscientist" ]; 
optionalMissionFieldTypes   = [ "STR"        "STR"    "STR"     "STR"         "STR"               "STR"              "STR"      "STR"                   "STR"            ]; 
additionalMissionFields     = [ "responsiblelaboratoryname" "flagvalues" "flagmeanings" ]; 
additionalMissionFieldTypes = [ "STR"                       "STR"        "STR"          ]; 
% OPERATION FIELDS:
% operationtype and operationnumber are mandatory keys in base, and for input files!
% operationnumber key is assigned by NMDphyschem system and will just be numbering of structure fields here.
mandatoryOperationFields      = [ "operationtype" "operationnumber" "operationplatform" "timestart" "timestartquality" "longitudestart" "latitudestart" "positionstartquality" "featuretype" ];
mandatoryOperationFieldTypes  = [ "STR"           "STR"             "STR"               "DATETIME"  "STR"              "DEC"            "DEC"           "STR"                  "STR"         ];
optionalOperationFields       = [ "originaloperationnumber" "stationtype" "localcdiid" "timeend"  "timeendquality" "longitudeend" "latitudeend" "positionendquality" "logstart" "logstartquality" "logend" "logendquality" "operationcomment" ];
optionalOperationFieldTypes   = [ "STR"                     "STR"         "STR"        "DATETIME" "STR"            "DEC"          "DEC"         "STR"                "DEC"      "STR"             "DEC"    "STR"           "STR"              ];
conditionOperationFields      = [ "bottomdepthstart" "bottomdepthend" "windspeed" "winddirection" "airtemperature" "wetbulbtemperature" "airpressureatsealevel" "surfacespecifichumidity" "surfacerelativehumidity" "seasurfacetemperature" "surfacepar" "weather" "clouds" "sea" "ice" "significantwaveheight" ];     
conditionOperationFieldTypes  = [ "DEC"              "DEC"            "INT"       "INT"           "DEC"            "DEC"                "DEC"                   "DEC"                     "DEC"                     "DEC"                   "DEC"        "INT"     "INT"    "INT" "INT" "DEC"                   ];     
additionalOperationFields     = [ "operationtypename" "operationplatformname" "featuretypename" "weatherdescription" "cloudsdescription" "seadescription" "icedescription" "stationtypedescription" ];
additionalOperationFieldTypes = [ "STR"               "STR"                   "STR"             "STR"                "STR"               "STR"            "STR"            "STR"                    ];
% INSTRUMENT FIELDS:
% instrumentid key is assigned by NMDphyschem system and will just be numbering of structure fields here.
% instrumenttype is not a key, but crucial.
% instrumentproperty is optional as field and has no value type as it is sub-level.
mandatoryInstrumentFields      = [ "instrumentid" "instrumenttype" ]; 
mandatoryInstrumentFieldTypes  = [ "INT"          "STR"            ]; 
optionalInstrumentFields       = [ "instrumentserialnumber" "instrumentmodel" "equipment" "instrumentdataowner"  "instrumentprincipalinvestigator" "project" "instrumentproperty" ];
optionalInstrumentFieldTypes   = [ "STR"                    "STR"             "STR"       "STR"                  "STR"                             "STR"     ""                   ];
additionalInstrumentFields     = [ "instrumenttypename" "equipmentname" "instrumentdataownername" ];
additionalInstrumentFieldTypes = [ "STR"                "STR"           "STR"                     ];
try
  url=[URL.PhysChemReference,'instrumentPropertyType'];
  %tmp=webread(url);
  tmp=instrumentPropertyType;
  instrumentPropertyTypeCodes = replace(strip(string(char(tmp.code)))',{'-'},'');
  instrumentPropertyTypeValueTypes = strip(string(char(tmp.valueType)))';
  lastAPIupdate.instrumentPropertyType=now;
  disp(['Successful API access (',url,').' ...
	   ' Updated table structs ''instrumentPropertyTypeCodes'' and ''instrumentPropertyTypeValueTypes'' now on ',datestr(lastAPIupdate.instrumentPropertyType),'.']);
catch 
  warning(['API access failed (',url,')!' ...
	   ' Keeping table structs ''instrumentPropertyTypeCodes'' and ''instrumentPropertyTypeValueTypes'' from ',datestr(lastAPIupdate.instrumentPropertyType),'.']);
end

% PARAMETER FIELDS:
% parameterid key is assigned by NMDphyschem system and will just be numbering of structure fields here.
% ordinal is assigned by NMDphyschem system, but should be given for input files if more than one of the same parameter.
% suppliedparametername and suppliedunits cannot be optional here, even though they are optional in the data model, 
% since we need to translate when importing data from other files.
% parametercode and units are mandatory in base and can be generated upon file ingestion
% to base, but NPC_VALIDATE_STRUCT can fill them by adressing PhyscChemReference API.
% ordinal is moved to optional here and should change to optional in the API since never used on primary parameters.
mandatoryParameterFields      = [ "parameterid" "parametercode" "units" "processinglevel" ]; 
mandatoryParameterFieldTypes  = [ "INT"         "STR"           "STR"   "STR" ]; 
optionalParameterFields       = [ "ordinal" "suppliedparametername" "suppliedunits" "sensorserialnumber" "referencescale" "uncertainty" "accuracy" "precision" "resolution" "sensororientation" "acquirementmethod" "acquirementcomment" "nrtqcmethod" "nrtqccomment" "dmqcmethod" "dmqccomment" "calibrationmethod" "calibrationcomment" "parameterproperty" ];
optionalParameterFieldTypes   = [ "INT"     "STR"                   "STR"           "STR"                "STR"            "DEC"         "DEC"      "DEC"       "DEC"        "STR"               "STR"               "STR"                "STR"         "STR"          "STR"        "STR"         "STR"               "STR"                ""                  ];
additionalParameterFields     = [ "parametername" "processinglevelname" "acquirementmethodname" "sensororientationname" "nrtqcmethodname" "dmqcmethodname" "calibrationmethodname" ];
additionalParameterFieldTypes = [ "STR"           "STR"                 "STR"                   "STR"                   "STR"             "STR"            "STR"                   ];
try
  url=[URL.PhysChemReference,'parameterPropertyType'];
  %tmp=webread(url);
  tmp=parameterPropertyType;
  parameterPropertyTypeCodes = replace(strip(string(char(tmp.code)))',{'-'},'');
  parameterPropertyTypeValueTypes = strip(string(char(tmp.valueType)))';
  lastAPIupdate.parameterPropertyType=now;
  disp(['Successful API access (',url,').' ...
	   ' Updated table structs ''parameterPropertyTypeCodes'' and ''parameterPropertyTypeValueTypes'' now on ',datestr(lastAPIupdate.parameterPropertyType),'.']);
catch
  warning(['API access failed (',url,')!' ...
	   ' Keeping table structs ''parameterPropertyTypeCodes'' and ''parameterPropertyTypeValueTypes'' from ',datestr(lastAPIupdate.parameterPropertyType),'.']);
end
% READING FIELDS: 
% [√] value has three different types, dependent on the parameter, so may
% have to use CONTAINS when validating struct (valuedatetime, valueint,
% valuedec, valuestr). Solved by creating the funfction VALUETYPE.
% n is not valid for NMDphyschem (yet), but temporarily used for output files here.
mandatoryReadingFields      = [ "sampleid" "value" "quality" ];
mandatoryReadingFieldTypes  = [ "INT"      ""      "STR"     ];
optionalReadingFields       = [ "uncertainty" "std" ];
optionalReadingFieldTypes   = [ "DEC"         "DEC" ];
additionalReadingFields     = [ "n"   ];
additionalReadingFieldTypes = [ "INT" ];


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



% SAVE OBJECTS IN TOOLBOX DIRECTORY:"suppliedParameter" "suppliedUnits"  ];
clear url tmp refnam i ans 
save([tooldir,filesep,'npc_init']);
disp(['NPC_INIT : Saved NPC init objects to ',tooldir,filesep,'npc_init.mat.']);

function mission = npc_build_struct(npars,ninst,noper,scope,API)
% NPC_BUILD_STRUCT	Builds a struct with fields for NMDphyschem
% Outputs a valid structure object with empty fields for metadata and
% data input to NMDphyschem.
% 
% mission = npc_build_struct(npars,ninst,noper,scope,API)
% 
% npars	= number of parameters expected (default=2).
% ninst	= number of instruments expected (default=1).
% noper	= number of parameters expected (default=1).
% scope	= String to select how many fields to include in output
%	  structure:
%		'mandatory' fields only,
%		'optional' fields as well, 
%		'conditions' fields as well,
%		'properties' fields as well, and
%		'additional' fields in addition (default).
% API	= logical to be set to true if making mission struct to be
%         POSTED directly to the PhysChem API (not recommendable and
%         likely not allowed either, though). This affects which
%         elements can be considered mandatory. (default=false)  
%
% mission	= output structure for NMDphyschem.
%
% It is recommended to first run NPC_INIT in order to have the correct
% set of fields.
% 
% The default gives a complete NMDphyschem data-model structure, plus
% some additional fields to make a file human readable. You can reduce
% this to only mandatory fields with NPC_STRIP_STRUCT or input scope
% here.
%
% If you choose 'mandatory' scope but still cannot fill all fields with
% the info you have, don't worry. NPC_VALIDATE_STRUCT will do much of it
% for you.
% 
% Notes:
%
% 'missionNumber' key is needed here since it is the upper level, but
%	may be reassigned by NMDphyschem system.
% 'missionTypeName' and 'platformName' are mission fields to be assigned 
%	by the NMDphyschem system or other functions in this library 
%	by quiery to the NDMreference API.
% 'operationNumber' key is assigned by NMDphyschem system and will
%	just be numbering of structure fields here. 
% 'instrumentNumber' key is assigned by NMDphyschem system and will
%	just be numbering of structure fields here. 
% 'instrumentType' is not a key, but a most crucial mandatory field.
% 'parameterCode' and 'units' are parameter fields to be assigned 
%	by the NMDphyschem system or other functions in this library 
%	by quiery to the Physchem Reference API.
% 'reading' in the data model has only one value each, but here we
%	use vectors. 
% Additional fields are added, such as names explaining many of the
%	codes, in an effort to make files FAIR. 
%
% Used by NPC_MAKE_STARTSCRIPT
% Uses NPC_INIT
% See also NPC NPC_STRIP_STRUCT NPC_VALIDATE_STRUCT

% This function should not require hardcoding when data model of
% PhysChem changes!

% Last updated: Fri Jul 12 15:41:53 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(0,5,nargin));
if nargin < 5 | isempty(API),	API=false;		end
if nargin < 4 | isempty(scope),	scope='additional';	end
if nargin < 3 | isempty(noper),	noper=1;		end
if nargin < 2 | isempty(ninst),	ninst=1;		end
if nargin < 1 | isempty(npars),	npars=2;		end

% Load valid fieldnames, etc.
load npc_init

% Activate switches for what is mandatory:
if API % mission from PhysChem DB or planned to be posted to API:
  mandatoryMissionFields	= exportMandatoryMissionFields    ;
  mandatoryMissionFieldTypes	= exportMandatoryMissionFieldTypes    ;
  mandatoryOperationFields	= exportMandatoryOperationFields  ;
  mandatoryOperationFieldTypes	= exportMandatoryOperationFieldTypes  ;
  mandatoryInstrumentFields	= exportMandatoryInstrumentFields ;
  mandatoryInstrumentFieldTypes	= exportMandatoryInstrumentFieldTypes ;
  mandatoryParameterFields	= exportMandatoryParameterFields  ;
  mandatoryParameterFieldTypes	= exportMandatoryParameterFieldTypes  ;
  mandatoryReadingFields	= exportMandatoryReadingFields    ;
  mandatoryReadingFieldTypes	= exportMandatoryReadingFieldTypes    ;
else % mission from from various instrumentation on the outside (some DB-internal fields cannot be demanded): 
  mandatoryMissionFields	= importMandatoryMissionFields    ;
  mandatoryMissionFieldTypes    = importMandatoryMissionFieldTypes    ;
  mandatoryOperationFields	= importMandatoryOperationFields  ;
  mandatoryOperationFieldTypes  = importMandatoryOperationFieldTypes  ;
  mandatoryInstrumentFields	= importMandatoryInstrumentFields ;
  mandatoryInstrumentFieldTypes = importMandatoryInstrumentFieldTypes ;
  mandatoryParameterFields	= importMandatoryParameterFields  ;
  mandatoryParameterFieldTypes  = importMandatoryParameterFieldTypes  ;
  mandatoryReadingFields	= importMandatoryReadingFields    ;
  mandatoryReadingFieldTypes    = importMandatoryReadingFieldTypes    ;
end

% Decide selection of fieldnames to use:
switch scope
 case 'mandatory'
  Mf  =cellstr([mandatoryMissionFields ]);
  MfV =cellstr([mandatoryMissionFieldTypes ]);
  MPf =cellstr([""]);
  MPfV=cellstr([""]);
  Of  =cellstr([mandatoryOperationFields ]);
  OfV =cellstr([mandatoryOperationFieldTypes ]);
  OPf =cellstr([""]);
  OPfV=cellstr([""]);
  If  =cellstr([mandatoryInstrumentFields ]);
  IfV =cellstr([mandatoryInstrumentFieldTypes ]);
  IPf =cellstr([""]);
  IPfV=cellstr([""]);
  Pf  =cellstr([mandatoryParameterFields ]);
  PfV =cellstr([mandatoryParameterFieldTypes ]);
  PPf =cellstr([""]);
  PPfV=cellstr([""]);
  Rf  =cellstr([mandatoryReadingFields ]);
  RfV =cellstr([mandatoryReadingFieldTypes ]);
 case 'optional'
  Mf  =cellstr([mandatoryMissionFields		,optionalMissionFields ]);
  MfV =cellstr([mandatoryMissionFieldTypes	,optionalMissionFieldTypes ]);
  MPf =cellstr([""]);
  MPfV=cellstr([""]);
  Of  =cellstr([mandatoryOperationFields	,optionalOperationFields ]);
  OfV =cellstr([mandatoryOperationFieldTypes	,optionalOperationFieldTypes ]);
  OPf =cellstr([""]);
  OPfV=cellstr([""]);
  If  =cellstr([mandatoryInstrumentFields	,optionalInstrumentFields ]);
  IfV =cellstr([mandatoryInstrumentFieldTypes	,optionalInstrumentFieldTypes ]);
  IPf =cellstr([""]);
  IPfV=cellstr([""]);
  Pf  =cellstr([mandatoryParameterFields	,optionalParameterFields ]);
  PfV =cellstr([mandatoryParameterFieldTypes	,optionalParameterFieldTypes ]);
  PPf =cellstr([""]);
  PPfV=cellstr([""]);
  Rf  =cellstr([mandatoryReadingFields		,optionalReadingFields ]);
  RfV =cellstr([mandatoryReadingFieldTypes	,optionalReadingFieldTypes ]);
 case 'conditions'
  Mf  =cellstr([mandatoryMissionFields		,optionalMissionFields ]);
  MfV =cellstr([mandatoryMissionFieldTypes	,optionalMissionFieldTypes ]);
  MPf =cellstr([""]);
  MPfV=cellstr([""]);
  Of  =cellstr([mandatoryOperationFields	,optionalOperationFields	,conditionOperationFields ]);
  OfV =cellstr([mandatoryOperationFieldTypes	,optionalOperationFieldTypes	,conditionOperationFieldTypes ]);
  OPf =cellstr([""]);
  OPfV=cellstr([""]);
  If  =cellstr([mandatoryInstrumentFields	,optionalInstrumentFields ]);
  IfV =cellstr([mandatoryInstrumentFieldTypes	,optionalInstrumentFieldTypes ]);
  IPf =cellstr([""]);
  IPfV=cellstr([""]);
  Pf  =cellstr([mandatoryParameterFields	,optionalParameterFields ]);
  PfV =cellstr([mandatoryParameterFieldTypes	,optionalParameterFieldTypes ]);
  PPf =cellstr([""]);
  PPfV=cellstr([""]);
  Rf  =cellstr([mandatoryReadingFields		,optionalReadingFields ]);
  RfV =cellstr([mandatoryReadingFieldTypes	,optionalReadingFieldTypes ]);
 case 'properties'
  Mf  =cellstr([mandatoryMissionFields		,optionalMissionFields ]);
  MfV =cellstr([mandatoryMissionFieldTypes	,optionalMissionFieldTypes ]);
  MPf =cellstr([missionPropertyTypeCodes ]);
  MPfV=cellstr([missionPropertyTypeValueTypes ]);
  Of  =cellstr([mandatoryOperationFields	,optionalOperationFields	,conditionOperationFields ]);
  OfV =cellstr([mandatoryOperationFieldTypes	,optionalOperationFieldTypes	,conditionOperationFieldTypes ]);
  OPf =cellstr([operationPropertyTypeCodes ]);
  OPfV=cellstr([operationPropertyTypeValueTypes ]);
  If  =cellstr([mandatoryInstrumentFields	,optionalInstrumentFields ]);
  IfV =cellstr([mandatoryInstrumentFieldTypes	,optionalInstrumentFieldTypes ]);
  IPf =cellstr([instrumentPropertyTypeCodes ]);
  IPfV=cellstr([instrumentPropertyTypeValueTypes ]);
  Pf  =cellstr([mandatoryParameterFields	,optionalParameterFields ]);
  PfV =cellstr([mandatoryParameterFieldTypes	,optionalParameterFieldTypes ]);
  PPf =cellstr([parameterPropertyTypeCodes ]);
  PPfV=cellstr([parameterPropertyTypeValueTypes ]);
  Rf  =cellstr([mandatoryReadingFields		,optionalReadingFields ]);
  RfV =cellstr([mandatoryReadingFieldTypes	,optionalReadingFieldTypes ]);
 case 'additional'
  Mf  =cellstr([mandatoryMissionFields		,optionalMissionFields						,additionalMissionFields ]);
  MfV =cellstr([mandatoryMissionFieldTypes	,optionalMissionFieldTypes					,additionalMissionFieldTypes ]);
  MPf =cellstr([missionPropertyTypeCodes ]);
  MPfV=cellstr([missionPropertyTypeValueTypes ]);
  Of  =cellstr([mandatoryOperationFields	,optionalOperationFields	,conditionOperationFields	,additionalOperationFields ]);
  OfV =cellstr([mandatoryOperationFieldTypes	,optionalOperationFieldTypes	,conditionOperationFieldTypes	,additionalOperationFieldTypes ]);
  OPf =cellstr([operationPropertyTypeCodes ]);
  OPfV=cellstr([operationPropertyTypeValueTypes ]);
  If  =cellstr([mandatoryInstrumentFields	,optionalInstrumentFields					,additionalInstrumentFields ]);
  IfV =cellstr([mandatoryInstrumentFieldTypes	,optionalInstrumentFieldTypes					,additionalInstrumentFieldTypes ]);
  IPf =cellstr([instrumentPropertyTypeCodes]);
  IPfV=cellstr([instrumentPropertyTypeValueTypes]);
  Pf  =cellstr([mandatoryParameterFields	,optionalParameterFields					,additionalParameterFields ]);
  PfV =cellstr([mandatoryParameterFieldTypes	,optionalParameterFieldTypes					,additionalParameterFieldTypes ]);
  PPf =cellstr([parameterPropertyTypeCodes]);
  PPfV=cellstr([parameterPropertyTypeValueTypes]);
  Rf  =cellstr([mandatoryReadingFields		,optionalReadingFields						,additionalReadingFields ]);
  RfV =cellstr([mandatoryReadingFieldTypes	,optionalReadingFieldTypes					,additionalReadingFieldTypes ]);
otherwise
  error('Invalid ''scope'' input!');
end
% Remove empty entries (e.g., from levels without additional Fields):
igno={''};
[Mf,IA]=setdiff(Mf,igno,'stable'); MfV(IA);
[MPf,IA]=setdiff(MPf,igno,'stable'); MPfV(IA);
[Of,IA]=setdiff(Of,igno,'stable'); OfV(IA);
[OPf,IA]=setdiff(OPf,igno,'stable'); OPfV(IA);
[If,IA]=setdiff(If,igno,'stable'); IfV(IA);
[IPf,IA]=setdiff(IPf,igno,'stable'); IPfV(IA);
[Pf,IA]=setdiff(Pf,igno,'stable'); PfV(IA);
[PPf,IA]=setdiff(PPf,igno,'stable'); PPfV(IA);
[Rf,IA]=setdiff(Rf,igno,'stable'); RfV(IA);


% ------- Build a valid structure: -----------------------------------

% PARAMETER LEVEL:
parameter=cell2struct(cellstr(repmat("",1,length(Pf))),Pf,2);		% Create a parameter structure with metadata fields
for i=1:numel(Pf)
  parameter.(Pf{i})=valuetype(parameter.(Pf{i}),PfV{i});		% Set correct valuetypes on parameterfields
end
for i=1:length(PPf)								
  parameter.parameterProperty(i,1).code=PPf{i};				% Add the parameterproperties to parameter
  parameter.parameterProperty(i,1).value=valuetype('',PPfV{i});		% Set correct valuetypes to parameterproperties
end

% READING LEVEL:
parameter.reading=cell2struct(cellstr(repmat("",1,length(Rf))),Rf,2);	% Add reading metadata fields to it
for i=1:numel(Rf)
  parameter.reading.(Rf{i})=valuetype(parameter.reading.(Rf{i}),RfV{i});% Set correct valuetypes on readingfields
end

% INSTRUMENT LEVEL:
instrument=cell2struct(cellstr(repmat("",1,length(If))),If,2);		% Create instrument structure with metadata fields
for i=1:numel(If)
  instrument.(If{i})=valuetype(instrument.(If{i}),IfV{i});		% Set correct valuetypes on instrumentfields
end
for i=1:length(IPf)
  instrument.instrumentProperty(i,1).code=IPf{i};			% Add the instrumentproperties to instrument				
  instrument.instrumentProperty(i,1).value=valuetype('',IPfV{i});	% Set correct valuetypes to instrumentproperties
end
instrument.parameter=repmat({parameter},npars,1);			% Add as many parameters as you need, to instrument

% OPERATION LEVEL:
operation=cell2struct(cellstr(repmat("",1,length(Of))),Of,2);		% Create operation with metadata fields
for i=1:numel(Of)
  operation.(Of{i})=valuetype(operation.(Of{i}),OfV{i});		% Set correct valuetypes on operationfields
end
for i=1:length(OPf)
  operation.operationProperty(i,1).code=OPf{i};				% Add the operationproperties to operation				
  operation.operationProperty(i,1).value=valuetype('',OPfV{i});		% Set correct valuetypes to operationproperties
end
operation.instrument=repmat({instrument},ninst,1);			% Add as many instruments as you need, to operation

% MISSION LEVEL:
mission=cell2struct(cellstr(repmat("",1,length(Mf))),Mf,2);		% Create mission with metadata fields
for i=1:numel(Mf)
  mission.(Mf{i})=valuetype(mission.(Mf{i}),MfV{i});		% Set correct valuetypes on missionfields
end
for i=1:length(MPf)
  mission.missionProperty(i,1).code=MPf{i};				% Add the missionproperties to mission				
  mission.missionProperty(i,1).value=valuetype('',MPfV{i});		% Set correct valuetypes to missionproperties
end
mission.operation=repmat({operation},noper,1);				% Add as many operations as you need, to mission



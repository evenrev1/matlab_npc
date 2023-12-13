function mission = npc_build_struct(npars,ninst,noper,scope)
% NPC_BUILD_STRUCT	Builds a struct with fields for NMDphyschem
% Outputs a valid structure object with empty fields for metadata and
% data input to NMDphyschem.
% 
% mission = npc_build_struct(npars,ninst,noper,scope)
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
% 'missionnumber' key is needed here since it is the upper level, but
%	may be reassigned by NMDphyschem system.
% 'missiontypename' and 'platformname' are mission fields to be assigned 
%	by the NMDphyschem system or other functions in this library 
%	by quiery to the NDMreference API.
% 'operationnumber' key is assigned by NMDphyschem system and will
%	just be numbering of structure fields here. 
% 'instrumentid' key is assigned by NMDphyschem system and will just
%	be numbering of structure fields here. 
% 'instrumenttype' is not a key, but a most crucial mandatory field.
% 'parametercode' and 'units' are parameter fields to be assigned 
%	by the NMDphyschem system or other functions in this library 
%	by quiery to the Physchem Reference API.
% 'n' is not valid for NMDphyschem, but temporarily used as reading 
%	field in this library for sample-size csv output.
%	Other additional fields include names explaining many of the
%	codes, in an effort to make files FAIR. 
% 'reading' in the data model has only one value each, but here we
%	use vectors. 
%
% Uses NPC_INIT
% See also NPC NPC_STRIP_STRUCT NPC_VALIDATE_STRUCT

% Last updated: Wed Dec 13 11:05:10 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(0,4,nargin));
if nargin < 4 | isempty(scope),	scope='additional';	end
if nargin < 3 | isempty(noper),	noper=1;		end
if nargin < 2 | isempty(ninst),	ninst=1;		end
if nargin < 1 | isempty(npars),	npars=2;		end

% Load valid fieldnames, etc.
load npc_init

% Decide selection of fieldnames to use:
switch scope
 case 'mandatory'
  Mf=cellstr([mandatoryMissionFields   ]);
  Of=cellstr([mandatoryOperationFields ]);
  If=cellstr([mandatoryInstrumentFields]);
  IPf=cellstr([]);
  IPVf=cellstr([]);
  Pf=cellstr([mandatoryParameterFields ]);
  PPf=cellstr([]);
  PPVf=cellstr([]);
  Rf=cellstr([mandatoryReadingFields   ]);
 case 'optional'
  Mf=cellstr([mandatoryMissionFields   ,optionalMissionFields   ]);
  Of=cellstr([mandatoryOperationFields ,optionalOperationFields ]);
  If=cellstr([mandatoryInstrumentFields,optionalInstrumentFields]);
  IPf=cellstr([]);
  IPVf=cellstr([]);
  Pf=cellstr([mandatoryParameterFields ,optionalParameterFields ]);
  PPf=cellstr([]);
  PPVf=cellstr([]);
  Rf=cellstr([mandatoryReadingFields   ,optionalReadingFields   ]);
 case 'conditions'
  Mf=cellstr([mandatoryMissionFields   ,optionalMissionFields   ]);
  Of=cellstr([mandatoryOperationFields ,optionalOperationFields ,conditionOperationFields ]);
  If=cellstr([mandatoryInstrumentFields,optionalInstrumentFields]);
  IPf=cellstr([]);
  IPVf=cellstr([]);
  Pf=cellstr([mandatoryParameterFields ,optionalParameterFields ]);
  PPf=cellstr([]);
  PPVf=cellstr([]);
  Rf=cellstr([mandatoryReadingFields   ,optionalReadingFields   ]);
 case 'properties'
  Mf=cellstr([mandatoryMissionFields   ,optionalMissionFields   ]);
  Of=cellstr([mandatoryOperationFields ,optionalOperationFields ,conditionOperationFields  ]);
  If=cellstr([mandatoryInstrumentFields,optionalInstrumentFields]);
  IPf=cellstr([instrumentPropertyTypeCodes]);
  IPVf=cellstr([instrumentPropertyTypeValueTypes]);
  Pf=cellstr([mandatoryParameterFields ,optionalParameterFields ]);
  PPf=cellstr([parameterPropertyTypeCodes]);
  PPVf=cellstr([parameterPropertyTypeValueTypes]);
  Rf=cellstr([mandatoryReadingFields   ,optionalReadingFields   ]);
 case 'additional'
  Mf=cellstr([mandatoryMissionFields   ,optionalMissionFields   ,additionalMissionFields   ]);
  Of=cellstr([mandatoryOperationFields ,optionalOperationFields ,conditionOperationFields ,additionalOperationFields ]);
  If=cellstr([mandatoryInstrumentFields,optionalInstrumentFields,additionalInstrumentFields]);
  IPf=cellstr([instrumentPropertyTypeCodes]);
  IPVf=cellstr([instrumentPropertyTypeValueTypes]);
  Pf=cellstr([mandatoryParameterFields ,optionalParameterFields ,additionalParameterFields ]);
  PPf=cellstr([parameterPropertyTypeCodes]);
  PPVf=cellstr([parameterPropertyTypeValueTypes]);
  Rf=cellstr([mandatoryReadingFields   ,optionalReadingFields   ,additionalReadingFields   ]);
otherwise
  error('Invalid ''scope'' input!');
end

% BUILD A VALID STRUCTURE:
parameter=cell2struct(cellstr(repmat("",1,length(Pf))),Pf,2);		% Create a parameter structure with parameter metadata fields
parameter.reading=cell2struct(cellstr(repmat("",1,length(Rf))),Rf,2);	% Add reading metadata fields to it

for i=1:length(PPf)							% Then add the parameterproperties to parameter:
  parameter.parameterproperty(i,1).code=PPf{i};				
  parameter.parameterproperty(i,1).value=valuetype('',PPVf{i});
end

instrument=cell2struct(cellstr(repmat("",1,length(If))),If,2);		% Create instrument with metadata fields
instrument.parameter=repmat({parameter},npars,1);			% Then add as many parameters as you need, to instrument

for i=1:length(IPf)							% Then add the instrumentproperties to instrument
  instrument.instrumentproperty(i,1).code=IPf{i};				
  instrument.instrumentproperty(i,1).value=valuetype('',IPVf{i});				
end

operation=cell2struct(cellstr(repmat("",1,length(Of))),Of,2);		% Create operation with metadata fields
operation.instrument=repmat({instrument},ninst,1);			% Then add as many instruments as you need, to operation

mission=cell2struct(cellstr(repmat("",1,length(Mf))),Mf,2);		% Create mission with metadata fields
mission.operation=repmat({operation},noper,1);				% Then add as many operations as you need, to mission



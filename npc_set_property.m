function s = npc_set_property(s,code,value)
% NPC_SET_PROPERTY	Sets property value for NMDphyschem
% Returns the input substruct with property value set, based on valid
% codes for the flexible property fields at levels of the NMDphyschem
% data model.
%
% s = npc_set_property(s,code,value)
% 
% s	= substruct containing a 'property' field 
%	  (e.g. instrument or parameter field).
% code	= char of code describing the property
% value = the value of the property
%
% s	= returned substruct with the 'property' filled
%
% It is recommended to run NPC_INIT to update the names lists.
%
% See reference lists in Physchem Editor for valid codes, their
% meaning, and ValueTypes: 
% https://physchem-reference-editor.hi.no/missionPropertyType
% https://physchem-reference-editor.hi.no/operationPropertyType
% https://physchem-reference-editor.hi.no/instrumentPropertyType
% https://physchem-reference-editor.hi.no/parameterPropertyType
% 
% Used by NPC_MAKE_STARTSCRIPT (indirectly)
% See also NPC NPC_BUILD_STRUCT EGETFIELD SETFIELD VALUETYPE

% This function requires hardcoding when data model of PhysChem changes!

% Last updated: Thu Jul 11 17:17:29 2024 by jan.even.oeie.nilsen@hi.no

% Find which level s is:
flds=fieldnames(s); 
propertyname=["missionProperty" "operationProperty" "instrumentProperty" "parameterProperty"];
any([contains(flds,'missionType') contains(flds,'operationType') contains(flds,'instrumentType') contains(flds,'parameterCode')]);
propertyname=propertyname(ans);

% Check propertyname and get the relevant lists:  
if isempty(propertyname)
  warning(['Input field cannot have a property field! No property or value has been set.']); return
elseif length(string(propertyname))>1
  warning(['Input field has more than one property field! No property or value has been set.']); return
elseif contains(propertyname,'mission')
  load npc_init missionPropertyType*
  strcmp(missionPropertyTypeCodes,code);
  if any(ans)
    type=missionPropertyTypeValueTypes(ans);
  else
    warning(['Input code for missionProperty is invalid! No property or value has been set.']); return
  end
elseif contains(propertyname,'operation')
  load npc_init operationPropertyType*
  strcmp(operationPropertyTypeCodes,code);
  if any(ans)
    type=operationPropertyTypeValueTypes(ans);
  else
    warning(['Input code for operationProperty is invalid! No property or value has been set.']); return
  end
elseif contains(propertyname,'instrument')
  load npc_init instrumentPropertyType*
  strcmp(instrumentPropertyTypeCodes,code);
  if any(ans)
    type=instrumentPropertyTypeValueTypes(ans);
  else
    warning(['Input code for instrumentProperty is invalid! No property or value has been set.']); return
  end
elseif contains(propertyname,'parameter')
  load npc_init parameterPropertyType*
  strcmp(parameterPropertyTypeCodes,code);
  if any(ans)
    type=parameterPropertyTypeValueTypes(ans);
  else
    warning(['Input code for parameterProperty is invalid! No property or value has been set.']); return
  end
end

% Make sure input has the correct valuetype:
value=valuetype(value,type);

% Find the property field (number) with the given code:
[~,~,fv]=egetfield(s,'code',code);

fv=fv(1);

% Evaluate possibilities and set the value:
if length(fv)>1
  fv
  disp('Result not unique! Input lower level of struct as s.');
elseif ~isempty(char(fv))
  switch type
   case {"STR","DATETIME","DATE"},	eval(strcat(fv,'=setfield(',fv,',''value'',''',value,''');'));	
   case {"DEC","INT","FLT"},		eval(strcat(fv,'=setfield(',fv,',''value'',',num2str(value),');'));	
  end
else % fv is empty; need to initiate a first property field
  s=setfield(s,propertyname,'code',code);
  s=setfield(s,propertyname,'value',value);
end
  

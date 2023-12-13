function s = npc_set_property(s,code,value)
% NPC_SET_PROPERTY	Sets property value for NMDphyschem.
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
% https://physchem-reference-editor.hi.no/instrumentPropertyType
% https://physchem-reference-editor.hi.no/parameterPropertyType
% 
% See also NPC NPC_BUILD_STRUCT EGETFIELD

% Last updated: Wed Dec 13 16:03:16 2023 by jan.even.oeie.nilsen@hi.no

% Check if input struct contains a property field (e.g. instrumentproperty):
fieldnames(s); 
propertyname=char(ans(contains(ans,'property')));
if isempty(propertyname)
  warning(['Input field has no property field! No property or value has been set.'])
  return
elseif length(string(propertyname))>1
  warning(['Input field has more than one property field! No property or value has been set.'])
  return
elseif contains(propertyname,'instrument')
  load npc_init instrumentPropertyType*
  type=instrumentPropertyTypeValueTypes(strcmp(instrumentPropertyTypeCodes,code));
elseif contains(propertyname,'parameter')
  load npc_init parameterPropertyType*
  type=parameterPropertyTypeValueTypes(strcmp(parameterPropertyTypeCodes,code));
end

% Make sure input has the correct valuetype:
value=valuetype(value,type);

% Find the property field (number) with the given code:
[~,~,fv]=egetfield(s,'code',code);	

% Evaluate possibilities and set the value:
if length(fv)>1
  fv
  error('Result not unique! Input lower level of struct as s.');
elseif ~isempty(fv)
  switch type
   case {"STR","DATETIME","DATE"},	eval(strcat(fv,'=setfield(',fv,',''value'',''',value,''');'));	
   case {"DEC","INT","FLT"},		eval(strcat(fv,'=setfield(',fv,',''value'',',num2str(value),');'));	
  end
else
  error(['The code ''',code,''' not valid for ',propertyname,'!']);
end
  

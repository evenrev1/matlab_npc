function [filename,mission] = npc_make_startscript(npars,ninst,noper,scope)
% NPC_MAKE_STARTSCRIPT	Makes a template script for import of data 
% from different instrumentation to NMDphyschem. 
% 
% filename = npc_make_startscript(npars,ninst,noper,scope)
% 
% inputs   = Same as NPC_BUILD_STRUCT.
% 
% filename = Char output of name of template script
%	     (default = 'create_mission.m').  
%
% The resulting template script will have to be filled out by the
% operator whith the relevant data objects from the instrumentation in
% question, and also other metadata at the different levels of the
% NMDphyschem data model. Simply run this function and you will see in
% the file.
%
% When finally run, the finished script will generate a mission object
% as well as npc-type ASCII files for each operation.
%
% Used by 
% Uses NPC_BUILD_STRUCT
% See also  NPC_INIT NPC_WRITE_STRUCT

% This function requires hardcoding when data model of PhysChem changes!

% Last updated: Thu Jul 11 16:50:54 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(0,4,nargin));
if nargin < 4 | isempty(scope),	scope='additional';	end
if nargin < 3 | isempty(noper),	noper=1;		end
if nargin < 2 | isempty(ninst),	ninst=1;		end
if nargin < 1 | isempty(npars),	npars=2;		end

% Load valid fieldnames, etc.
load npc_init

% Let npc_build_struct handle the scope:
mission = npc_build_struct(npars,ninst,noper,scope);

filename = 'create_mission.m';

fid=fopen(filename,'w');

% Preface:
fprintf(fid,'%s\n','% In the following, use the data from your instrumentation and');
fprintf(fid,'%s\n','% knowledge about assigning metadata, and add the missing parts in');
fprintf(fid,'%s\n','% the assignment lines below (''= ;).');
fprintf(fid,'\n','');
fprintf(fid,'%s\n','% Refer to table on https://confluence.imr.no/x/4AKzBg for the meaning of the fields');
fprintf(fid,'\n','');
fprintf(fid,'%s\n','% It is only possible to write one operation and one instrument in the same file,');
fprintf(fid,'%s\n','% But you can run this script in a loop over the operations.');
fprintf(fid,'\n','');

fprintf(fid,'%s\n','% Init:');
fprintf(fid,'%s%u%s\n','ON=',noper,'; % Number of operations');
fprintf(fid,'%s%u%s\n','IN=',ninst,'; % Number of instruments');
fprintf(fid,'%s\n','% NOTE that it is not possible for the time being to make');
fprintf(fid,'%s\n','% NPC_WRITE_STRUCT write more than one ASCII file, i.e. just one');
fprintf(fid,'%s\n','% instrument and one operation. Hence ON and IN should be kept as 1.');
fprintf(fid,'\n','');

fprintf(fid,'%s\n','% FINALLY, remember that this is just a template. Feel free to adjust');
fprintf(fid,'%s\n','% and add as much as you like for your instrumentation and data.');
fprintf(fid,'\n','');

fprintf(fid,'%s\n','% MISSION LEVEL:');
field=string(fieldnames(mission));
field=setdiff(field,{'missionProperty','operation'},'stable');
fieldname=strcat('mission.',field);
n=size(char(fieldname),2);
for i=1:numel(field)
  if ismember(field(i),mandatoryMissionFields), comment='% Mandatory, '; else, comment='% '; end
  TYP=allMissionNamTyp(strcmp(allMissionNam,field(i)));
  if isempty(char(TYP)), typtxt='free valuetype'; else, typtxt='valuetype '; end
  fprintf(fid,['%-',int2str(n),'s %s\t%s%s%s\n'],fieldname(i),' = ;',comment,typtxt,TYP);
end
fprintf(fid,'%s\n','    % MISSIONPROPERTIES (FLEXIBLE FIELDS):');
fprintf(fid,'%s\n','    % Use <property> codes from https://physchem-reference-editor.hi.no/missionPropertyType');
fprintf(fid,'%s\n','    % and add your <value> in this command line. Copy line and insert to set more properties.');
fprintf(fid,'%s\n','    mission = npc_set_property(mission,''<property>'',<value>);');
fprintf(fid,'\n','');

fprintf(fid,'\n','');

fprintf(fid,'%s\n','for O=1:ON % Loop operations (and, i.e. files)');
  fprintf(fid,'\n','');
  fprintf(fid,'%2s%s\n','','% OPERATION LEVEL:');
  field=string(fieldnames(mission.operation{1}));
  field=setdiff(field,{'operationProperty','instrument'},'stable');
  fieldname=strcat('mission.operation{O}.',field);
  n=size(char(fieldname),2);
  for i=1:numel(field)
    if ismember(field(i),mandatoryOperationFields), comment='% Mandatory, '; else, comment='% '; end
    switch field(i)
     case {'timeStart','timeEnd'}, value=['= isofix8601(datenum(<instrument time>),111);'];
     otherwise, value='= ;';
    end
    TYP=allOperationNamTyp(strcmp(allOperationNam,field(i)));
    if isempty(char(TYP)), typtxt='free valuetype'; else, typtxt='valuetype '; end
    fprintf(fid,['%2s%-',int2str(n),'s %s\t%s%s%s\n'],'',fieldname(i),value,comment,typtxt,TYP);
  end
  fprintf(fid,'%s\n','    % OPERATIONPROPERTIES (FLEXIBLE FIELDS):');
  fprintf(fid,'%s\n','    % Use <property> codes from https://physchem-reference-editor.hi.no/operationPropertyType');
  fprintf(fid,'%s\n','    % and add your <value> in this command line. Copy line and insert to set more properties.');
  fprintf(fid,'%s\n','    mission.operation{O} = npc_set_property(mission.operation{O},''<property>'',<value>);');
  fprintf(fid,'\n','');
  
  fprintf(fid,'\n','');

  fprintf(fid,'%2s%s\n','','for I=1:IN % Loop instruments (and, i.e. files)');
    fprintf(fid,'\n','');
    fprintf(fid,'%4s%s\n','','% INSTRUMENT LEVEL:');
    field=string(fieldnames(mission.operation{1}.instrument{1}));
    field=setdiff(field,{'instrumentProperty','parameter'},'stable');
    fieldname=strcat('mission.operation{O}.instrument{I}.',field);
    n=size(char(fieldname),2);
    for i=1:numel(field)
      if ismember(field(i),mandatoryInstrumentFields), comment='% Mandatory, '; else, comment='% '; end
      TYP=allInstrumentNamTyp(strcmp(allInstrumentNam,field(i)));
      if isempty(char(TYP)), typtxt='free valuetype'; else, typtxt='valuetype '; end
      fprintf(fid,['%4s%-',int2str(n),'s %s\t%s%s%s\n'],'',fieldname(i),' = ;',comment,typtxt,TYP);
    end
    fprintf(fid,'%s\n','    % INSTRUMENTPROPERTIES (FLEXIBLE FIELDS):');
    fprintf(fid,'%s\n','    % Use <property> codes from https://physchem-reference-editor.hi.no/instrumentPropertyType');
    fprintf(fid,'%s\n','    % and add your <value> in this command line. Copy line and insert to set more properties.');
    fprintf(fid,'%s\n','    mission.operation{O}.instrument{I} = npc_set_property(mission.operation{O}.instrument{I},''<property>'',<value>);');
    fprintf(fid,'\n','');

    fprintf(fid,'\n','');

    fprintf(fid,'%4s%s\n','','% PARAMETER LEVEL:');
    for k=1:npars
      field=string(fieldnames(mission.operation{1}.instrument{1}.parameter{k}));
      field=setdiff(field,{'parameterProperty','reading'},'stable');
      fieldname=strcat('mission.operation{O}.instrument{I}.parameter{',int2str(k),'}.',field);
      n=size(char(fieldname),2);
      for i=1:numel(field)
	if ismember(field(i),mandatoryParameterFields), comment='% Mandatory, '; else, comment='% '; end
	switch field(i)
	 case 'parameterNumber', value=['= ',int2str(k),';'];
	 otherwise, value='= ;';
	end
	TYP=allParameterNamTyp(strcmp(allParameterNam,field(i)));
	if isempty(char(TYP)), typtxt='free valuetype'; else, typtxt='valuetype '; end
	fprintf(fid,['%4s%-',int2str(n),'s %s\t%s%s%s\n'],'',fieldname(i),value,comment,typtxt,TYP);
      end
      fprintf(fid,'%s\n','    % PARAMETERPROPERTIES (FLEXIBLE FIELDS):');
      fprintf(fid,'%s\n','    % Use <property> codes from https://physchem-reference-editor.hi.no/parameterPropertyType');
      fprintf(fid,'%s\n','    % and add your <value> in this command line. Copy line and insert to set more properties.');
      fprintf(fid,'%s%u%s%u%s\n','    mission.operation{O}.instrument{I}.parameter{',k,'} = npc_set_property(mission.operation{O}.instrument{I}.parameter{',k,'},''<property>'',<value>);');
      fprintf(fid,'\n','');
    end

    fprintf(fid,'%4s%s\n','','% READING LEVEL:');
    for k=1:npars
      field=string(fieldnames(mission.operation{1}.instrument{1}.parameter{k}.reading(1)));
      fieldname=strcat('mission.operation{O}.instrument{I}.parameter{',int2str(k),'}.reading(1).',field);
      n=size(char(fieldname),2);
      for i=1:numel(field)
	if ismember(field(i),mandatoryReadingFields), comment='% Mandatory, '; else, comment='% '; end
	switch field(i)
	 case 'sampleNumber', value='= 1;';
	 case 'quality',  value='= ''0'';';
	 otherwise, value='= ;';
	end
	TYP=allReadingNamTyp(strcmp(allReadingNam,field(i)));
	if isempty(char(TYP)), typtxt='free valuetype'; else, typtxt='valuetype '; end
	fprintf(fid,['%4s%-',int2str(n),'s %s\t%s%s%s\n'],'',fieldname(i),value,comment,typtxt,TYP);
      end
    end
    fprintf(fid,'%s\n','    % Data are to be input as column vectors in the value field.');
    fprintf(fid,'%s\n','    % For time you should use the function ISOFIX8601.');
    fprintf(fid,'%s\n','    % When making datasets for input to NMDphyschem, set sampleNumber to 1 and quality to ''0''.');
    fprintf(fid,'%s\n','    % See the following example:');
    fprintf(fid,'%s\n','    % mission.operation{O}.instrument{I}.parameter{1}.reading(1).sampleNumber	= 1;');
    fprintf(fid,'%s\n','    % mission.operation{O}.instrument{I}.parameter{1}.reading(1).value		= isofix8601(datenum(1970,1,1,0,0,data.body.time),113);');
    fprintf(fid,'%s\n','    % mission.operation{O}.instrument{I}.parameter{1}.reading(1).quality	= ''0'';');
    fprintf(fid,'%s\n','    % mission.operation{O}.instrument{I}.parameter{2}.reading(1).sampleNumber	= 1;');
    fprintf(fid,'%s\n','    % mission.operation{O}.instrument{I}.parameter{2}.reading(1).value		= data.body.temperature;');
    fprintf(fid,'%s\n','    % mission.operation{O}.instrument{I}.parameter{2}.reading(1).quality	= ''0'';');
    fprintf(fid,'\n','');

    fprintf(fid,'%s\n','    % SAVING:');
    fprintf(fid,'%s\n','    % Establish the filename for the new mission:');
    fprintf(fid,'%s\n','    filename = string(npc_make_filename(mission));');
    fprintf(fid,'%s\n','    save filename filename');
    fprintf(fid,'%s\n','    % Save the mission struct:');
    fprintf(fid,'%s\n','    save(filename,''mission'');');
    fprintf(fid,'%s\n','    % Write to ASCII text file:');
    fprintf(fid,'%s\n','    npc_write_struct(mission,''npc'',filename);');
    fprintf(fid,'\n','');

  fprintf(fid,'%s\n','  end % instrument loop');
  fprintf(fid,'\n','');

fprintf(fid,'%s\n','end % operation loop');
fprintf(fid,'\n','');
    
fclose(fid);


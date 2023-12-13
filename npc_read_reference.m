function [content,msg,status] = npc_read_reference(tabl,code,colm,valu)
% NPC_READ_REFERENCE	Reads info from reference lists
% Works on both PhysChem Reference and NMDreference lists.
% 
% [content,msg,status] = npc_read_reference(tabl,code,colm,valu)
% 
% tabl    = name of table, or pre-read struct of table with
%	    name exacly the same as the table it contains. 
% code    = code for row (default=empty).
% colm    = requested column, i.e. 'name' or 'description' 
%	    (default=empty).
% valu    = a specific value in the specified column 
%           (needs colm input; default=empty). 
% 
% content = the found result. See below for details.
% msg	  = string message related to status.
% status  = Integer scaling relating to EDISP and used
%	    directly by NPC_VALIDATE_STRUCT: 
%	      1 - success;
%	      2 - no finds for that column or value request;
%	      3 - system error such as no connectivity;
%	      4 - error in the call to API or wrong code.
%
% If code and colm are empty, content is struct of full table.
% Or if colm is empty, content is struct of row.
% Or if code is empty but colm given, content is cell of column.
% And if valu is also given, content is the code for that value (if input code is empty).
% If all fails, content is empty char.
%
% Used by NPC_GET_MISSION NPC_VALIDATE_STRUCT  
% Uses NPC_SQUEEZE_NMDREFERENCE
% See also NPC_INIT NPC_READ_PLATFORMCODESYS
 
% Last updated: Wed Dec 13 16:03:16 2023 by jan.even.oeie.nilsen@hi.no

physChemTables = [ "collectionType" "featureType" "instrumentPropertyType" ...
		   "instrumentType" "method" "methodGroup" "operationType" ...
		   "parameter" "parameterGroup" "parameterPropertyType" ...
		   "processingLevel" "sensorOrientation" "suppliedParameter" ...
		   "suppliedUnits" "valueType" ];

error(nargchk(1,4,nargin));
if nargin < 4 | isempty(valu),	valu='';	end
if nargin < 3 | isempty(colm),	colm='';	end
if nargin < 2 | isempty(code),	code='';	end

content=''; msg=''; status=2;	% Init as no result 

if isstruct(tabl)
  code=valuetype(code,'STR'); colm=valuetype(colm,'STR');
elseif ~(ischar(tabl) | isstring(tabl)) | ~(ischar(code) | isstring(code)) | ~(ischar(colm) | isstring(colm))
  error('Unless tabl is struct of full table, the inputs tabl, code, and colm must all be char or string');
else
  tabl=valuetype(tabl,'STR'); code=valuetype(code,'STR'); colm=valuetype(colm,'STR');
end

% CHECK WHAT KIND OF TABLE THIS IS (PhysChem Reference or NMDreference)
% Note that PhysChem API also mirrors NMDreference.
% Using list of tables are likely most effective
if isstruct(tabl), refnam=inputname(1);
else,		   refnam=tabl;	
end
if any(ismember(physChemTables,refnam)), 
  physChem=true; ref='PhysChem Reference'; 
else
  physChem=false; ref='NMDreference'; 
end
  

% GET TABLE OR ROW:
try						% Try if pre-read table can give the results 
  % Either table is direct input or read now:
  if isstruct(tabl)
    tmp=tabl; tabl=inputname(1);
  else
    warning off
    load('npc_init',tabl); 
    if exist(tabl,'var')
      tmp=eval(tabl); clear(tabl);
    else
      error;
    end
  end
  % Check if table is empty:
  if isempty(tmp), msg=strcat("Empty output from struct of table ",tabl); status=4; return; end
  % Check code against table:
  if ~isempty(code) 					% Get row number
    if physChem, 
      rowcode={tmp.code};
    else	 
      rowcode=egetfield(tmp,'code.Text');
    end	
    strcmp(rowcode,code);		
    if any(ans)						% Get row as if using it as endpoint in url
      if physChem		% Get simple struct 
	tmp=tmp(ans);		
      else			% Manipulate NMDreference struct:	
	tmp=tmp.list.row{ans};	% Reduce the struct to row 
	tmp=npc_squeeze_nmdreference(tmp);% Squeeze NMDreference struct
      end			
      status=1;						% Have row as simple struct
    else
      msg=strcat("Invalid code '",code,"' for ",ref,":",tabl);
      status=4; return;
    end
  elseif ~physChem
    tmp=npc_squeeze_nmdreference(tmp);	% Squeeze NMDreference struct
  end
catch						% If pre-read table fails, then read from API
  load npc_init URL
  if physChem
    url=strcat(URL.PhysChemReference,tabl,'/',code); % Only endpoint in API is code
    try, tmp=webread(url); catch, status=4; msg=strcat("Unsuccessful URL ",url); return; end
  else
    url=strcat(URL.NMDreference,tabl,'/',code,URL.NMDreferenceDescription);
    try, tmp=webread(url);	catch, status=4; msg=strcat("Unsuccessful URL ",url);		return; end
    try, tmp=xml2struct(tmp);	catch, status=4; msg=strcat("Unsuccessful XML2STRUCT from ",url); return; end
    tmp=npc_squeeze_nmdreference(tmp);
  end
  if isempty(tmp), status=4; msg=strcat("Empty output from URL ",url); return; end
end
% Now we should either way have a simple struct of either full table or row, in the same format.

% GET ROW, COLUMN, OR VALUE:
if ~isempty(code) & ~isempty(colm)									% You have the row and want the value in column
  try
    content=strip(eval(strcat('tmp.',colm)));								% You got the value
    msg=strcat("The value of '",colm,"' for code '",code,"' in ",ref,":",tabl," is '",content,"'");
    status=1;
  catch													% Wrong column name 
    content='';
    msg=strcat("There is no column named '",colm,"' in ",ref,":",tabl);
    msg=strcat(msg," Valid columns are ",snippet(fieldnames(tmp)));   
    status=2;
  end
elseif ~isempty(colm)											% Or you have the whole table but want a specific column
  try
    content=eval(strcat('{tmp.',colm,'}')); 								% You got the column
    msg=strcat("The contents of column '",colm,"' in ",ref,":",tabl," found");
    status=1; 
  catch													% Wrong column name 
    content='';
    msg=strcat("There is no column named '",colm,"' in ",ref,":",tabl);
    msg=strcat(msg," Valid columns are ",snippet(fieldnames(tmp)));   
    status=2;
  end
  if ~isempty(valu) 											% And you want to search for the value in that column
    try
      content=strip(tmp(strcmp(content,valu)).code);							% You got the value
      msg=strcat("The code for the value '",string(valu),"' for column '",colm,"' in ",ref,":",tabl," is '",content,"'");
      status=1;
    catch												% Value doesn't exist
      content='';
      msg=strcat("There is no value '",string(valu),"' for column '",colm,"' in ",ref,":",tabl);
      status=2;  % No listing of valid values in message, it would be too long and is given in output content anyway.
    end
  end
elseif ~isempty(code)											% You only asked for the row, and have it 
  content=tmp;
  msg=strcat("The row for code '",code,"' in ",ref,":",tabl," found");
  status=1;
else													% Or you just want the whole table
  content=tmp;
  msg=strcat("Full struct of table ",ref,":",tabl," found");
  status=1;
end


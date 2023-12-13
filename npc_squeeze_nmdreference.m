function tab = npc_squeeze_nmdreference(tabl)
% NPC_SQUEEZE_NMDREFERENCE	Reorganizes table from NMDreference
% 
% tab = npc_squeeze_nmdreference(tabl)
% 
% tabl	= struct of table from NMDreference, full table or single row.
% 
% Might be heavy on the big tables. Remember to access rows by
% endpoints in API call. 
%
% The extra list fields besides row, are discarded.
%
% Used by NPC_READ_REFERENCE 

% Last updated: Wed Dec 13 16:03:16 2023 by jan.even.oeie.nilsen@hi.no

% Prep the input:
fieldnames(tabl);
if isfield(tabl,'list')
  tabl=tabl.list.row;		% Squeeze the struct down to row 
elseif isfield(tabl,'row')
  tabl=tabl.row;		% Squeeze the struct down to row 
elseif isfield(tabl,'element')	% Some calls it element
  tabl={tabl.element};		% (i.e. Quality, weather, clouds, sea) 
elseif numel(ans) < 2		% It is a row from a named table
  tabl={tabl.(ans{1})};		% (i.e. institution, missionType,
                                % platform, 
else
  tabl={tabl};		% In order for the loops below to work for single row
end

app='Text';		% The name of appended field of the struct
M=length(tabl);

% Find names of all fields of the input:
fienam1="";
fienamA="";
for i=1:M	% find all fieldnames possible
  fienam1=union(fienam1,fieldnames(tabl{i}));
  fienamA=union(fienamA,fieldnames(tabl{i}.Attributes));
end
fienam1=setdiff(fienam1,["","Attributes"]);
fienamA=setdiff(fienamA,[""]);
fienam=union(fienam1,fienamA);

tab=cell2struct(repmat({''},size(fienam)),fienam);
tab=repmat(tab,M,1);

for i=1:M	% loop each row of input struct
  for j=1:length(fienam1) % loop every fieldname
    try tab(i).(fienam1(j)) = tabl{i}.(fienam1(j)).(app); end
  end
  for j=1:length(fienamA) % loop every Attributes fieldname
    try tab(i).(fienamA(j)) = tabl{i}.Attributes.(fienamA(j)); end
  end
end
% Use try because not all fieldnames may exist in all elements


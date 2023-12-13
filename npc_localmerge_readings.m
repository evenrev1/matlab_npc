function readingfield = npc_localmerge_readings(parameterfield)
% NPC_LOCALMERGE_READINGS	Merges separate reading fields
% of a parameter into column vectors in a single reading field. 
% 
% readingfield = npc_localmerge_readings(parameterfield)
% 
% parameterfield = struct of a parameter field.
%
% readingfield   = struct of a single reading field with the reading
%		   fields from the original parameter field combined
%		   into column vectors.
% 
% All vectors will be sorted according to 'sampleid' if it exists. 
%
% Character fields will be merged into character arrays of height
% according to the number of readings and width according to the
% largest character (i.e. largest number of digits).
%
% Used by NPC_MERGE_READINGS
% See also NPC_MERGE_OPERATIONS FIELDNAMES

% Last updated: Wed Dec 13 10:27:00 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,1,nargin));

if ~isstruct(parameterfield)
  readingfield=parameterfield.reading;
  warning('Non-struct input. Returning readingfield unchanged.');
elseif numel(parameterfield.reading)<=1 % Already merged, single, or simply empty
  % if ~isfield(parameterfield.reading,'sampleid') || isempty(parameterfield.reading.sampleid)
  %   % Use indices based on the size of the only really mandatory field
  %   % to make sampleids necessary for NPC_MERGE_OPERATIONS.
  %   parameterfield.reading.sampleid=1:numel(parameterfield.reading.value);
  %   txt=' but with sampleid field added';
  % else
  %   txt='';
  % end
  readingfield=parameterfield.reading;
  warning(['Merged, single or empty readingfield. Returning readingfield unchanged.']);
else
  
  % Init:
  fieldname=fieldnames(parameterfield.reading);
  data=struct2cell(parameterfield.reading);
  [M,N]=size(data);
  
  % Sort everything according to sampleid:
  j=find(strcmp(fieldname,'sampleid'));
  if any(j)
    cdata=cellfun(@str2num,cellstr(string(data(j,:))));	% Convert the cells of row to proper numeric
    [~,IA]=sort(cdata);					% Find sorting
    data=data(:,IA);					% Sort whole matrix
  end
  
  % Assign each row as column to each field:
  for i=1:M 
    if ischar(data{i,1})	% Character content may have different sizes
      readingfield.(fieldname{i})=char(string(data(i,:)'));	% Put row as column
    else
      readingfield.(fieldname{i})=cell2mat(data(i,:)');		% Put row as column
    end
  end
  
end  



function file = npc_write_struct(mission,filetype,prefix,operationNumber,instrumentNumber)
% NPC_WRITE_STRUCT	Writes NPC struct to file
% 
% file = npc_write_struct(mission,filetype,prefix,operationNumber,instrumentNumber)
% 
% mission	  = A valid NPC-struct.
% filetype	  = char extension, indicating type of file to write:
%		    'npc' : The default ASCII format for NMDphyschem.
%			    Takes one operation and one instrument
%			    only. Every instrument field in struct
%			    will be written to separate files.  
%		    'mat' (n/a) : Matlab binary object collection.
%		     'nc' (n/a) : IMR generic NetCDF format.
% prefix	  = string to prepend the standard name of the output
%		    file(s). This can be the name of the original
%		    source file of the data or any other prefferred
%		    identifiers for your own system.  
% operationNumber = n/a! operation field to be put in file 
%		    (default = all operations)
% instrumentNumber	  = n/a! instrument field to be put in file
%		    (default = all instruments)
%
% file		  = string array of names of output files. The
%		    standard file naming following NPC structure is
%		    described in NPC_MAKE_FILENAME. 
%
% It is recommended to run NPC_VALIDATE_STRUCT on struct before writing
% to file that is to be imported to NMDphyschem, and in general
% NPC_STRIP_STRUCT as well to limit empty fields.
% 
% Empty reading fields will not be written to file, even if they are
% mandatory for NMDphyschem, assuming they will be filled by the
% NMDphyschem file-import system (e.g. sampleNumber).
%
% The pairs of code and value for instrumentProperty and
% parameterProperty are written to one line with the code as fieldname
% and value as content.
%
% Uses NPC_MERGE_READINGS NPC_STRIP_STRUCT NPC_MAKE_FILENAME
% See also NPC EFIELDNAMES VALUETYPE FPRINTF

% Last updated: Fri Jul 12 18:21:31 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,5,nargin));
if nargin < 5 | isempty(instrumentNumber),	instrumentNumber='';	end
if nargin < 4 | isempty(operationNumber),	operationNumber='';	end
if nargin < 3 | isempty(prefix),		prefix='';		end
if nargin < 2 | isempty(filetype),		filetype='npc';  	end
if isempty(mission), disp('NPC_WRITE_STRUCT : Empty input!'); file=''; return; end

% Define fillvalues:
fillvalue.STR='';
fillvalue.DEC=-999999.0;
fillvalue.INT=-999999;
fillvalue.FLT=-999999.0;

% MERGE THE READINGS IN THE MISSION FIRST:
mission = npc_merge_readings(mission);

% Code below for the different output formats:
switch filetype
 case 'npc'
  
  % --- Prepare contents of file: ---
  
  % % If operation is selected, mission struct can be reduced already here:
  % operationNumber = str2num(string(operationNumber));
  % instrumentNumber = str2num(string(instrumentNumber));
  % if ~isempty(operationNumber)
  %   mission.operation = mission.operation(operationNumber);
  %   if ~isempty(instrumentNumber)
  %     mission.operation.instrument = mission.operation{1}.instrument(instrumentNumber);
  %   end
  % end
  
  % Strip hard here, since this is file intended for input to NMDphyschem:
  mission=npc_strip_struct(mission,'hard'); % Removes only empty fields 
  file=string([]);
  
  % Accomodate for several operations and instruments when filetypes mat
  % and nc are implemented. [] Cruise 2023007020 is a perfect example to
  % use for two instruments.
  NO=numel(mission.operation);
  for Oi=1:NO
    NI=numel(mission.operation{Oi}.instrument);
    for Ii=1:NI

      % Make mini-mission with just the one operation and instrument to be printed:
      miss=rmfield(mission,'operation'); 
      miss.operation=mission.operation(Oi);
      miss.operation{1}.instrument=mission.operation{Oi}.instrument(Ii);
      
      % Get all field names in input struct (used to call struct):
      names=efieldnames(miss);
      % Strip header field names of superfluous higher level struct field names:
      headerfields=replace(names,'miss.operation{1}.instrument{1}.','\\');
      headerfields=replace(headerfields,'miss.operation{1}.','\\');
      headerfields=replace(headerfields,'miss.','\\');
      % Add numbering to properties, even when there is only one property:
      headerfields=replace(headerfields,'missionProperty.','missionProperty(1).');
      headerfields=replace(headerfields,'operationProperty.','operationProperty(1).');
      headerfields=replace(headerfields,'instrumentProperty.','instrumentProperty(1).');
      headerfields=replace(headerfields,'parameterProperty.','parameterProperty(1).');
      % Separate into header and column information:
      I=contains(headerfields,'.reading.');
      readingnames=names(I); readingfields=headerfields(I);
      headernames=names(~I); headerfields=headerfields(~I);
      % Sort \\parameter{...}. lines by number:
      A=find(contains(headerfields,'\\parameter{'));
      split(headerfields(A),{'{','}.'}); 
      [~,IA]=sort(str2num(char(ans(:,2))));
      headerfields(A)=headerfields(A(IA));
      headernames(A)=headernames(A(IA));
    
      % Rearrange properties into fieldname and content:
      property={'missionProperty' 'operationProperty' 'instrumentProperty' 'parameterProperty'};
      for j=1:length(property)
	I=find(contains(headerfields,property{j})); I=I(1:2:end);
	for i=1:length(I)
	  % Put the code as fieldname for the value:
	  headerfields(I(i)+1)=replace(headerfields(I(i)),[property{j},'(',int2str(i),').code'],[property{j},'.',eval(headernames(I(i)))]); 
	  headerfields(I(i))=""; headernames(I(i))=""; % Empty the superfluous code line
	end
      end
      ~strcmp(headerfields,""); headerfields=headerfields(ans); headernames=headernames(ans); % Strip away the superfluous lines
      
      % Check readings:
      N=length(readingfields); % Number of fields
      M=zeros(N,1);
      for j=1:N
	D = size(eval(readingnames(j))); % Assumed size of all readings
	if length(D)>2
	  disp(strcat("NPC_WRITE_STRUCT : field more than 2D, thus omitted ",readingnames(j)));
	elseif eval(strcat("ischar(",readingnames(j),")")) && all(D>1) 
	  % Most likely a char array with values as columns. Leave further
	  % checks to the valuetype checks below.
	  %d=size(eval(readingnames(j+1))); % Get another field's size
	  %M(j)=D(D==d); % Take the one with 'normal size', and assume it's OK.
	  % NO, we need to be strict! DATETIME and DATE valuetypes are the
	  % ONLY reading values that should result in char arrays, and
	  % then they should have sampleNumber running in first dimension like
	  % all the other:
	  M(j)=D(1);
	elseif any(D==0)
	  disp(strcat("NPC_WRITE_STRUCT : empty and omitted field ",readingnames(j)));
	elseif D(2)~=1 && ~any(strcmp(valuetype(eval(readingnames(j))),{'DATE','DATETIME'}))
	  % It could be a single date string, from a single reading; not to be transposed.  
	  disp(strcat("NPC_WRITE_STRUCT : row vector transposed in field ",readingnames(j)));
	  eval(strcat(readingnames(j),"=",readingnames(j),"';"))
	  M(j)=D(2);
	else
	  M(j)=D(1);
	end
      end   
      if length(unique(M(M>0)))>1, error('Readings are not of uniform length!'); end
      keep=find(M);
      readingnames=readingnames(keep);
      readingfields=readingfields(keep);
    
      % Define formats and fill the matrix to be written to file:
      nform='';				% Format for the top numbering
      form='';				% Format for the columns
      readingmatrix=string(nan(D(1),N));% Preallocate string matrix
      for j=1:N				% Loop columns
	y=eval(readingnames(j));	% The j-th column 
	type=valuetype(y);		% Its valuetype (handles non-scalar input now) 
	switch type
	 case {'DEC','FLT'}		% Most parameters are DEC
	  y(isnan(y)) = fillvalue.DEC;
	  readingmatrix(:,j) = num2str(y(:),'%f'); 
	 case 'INT'			% Such as PHASE, PROFILE, SAMPLE, SAMPLESIZE
	  y(isnan(y)) = fillvalue.INT;
	  readingmatrix(:,j) = num2str(y(:),'%d'); 
	 case 'STR'			% DIRECTION
	  readingmatrix(:,j) = y;
	 case {'DATETIME','DATE'}	% DATETIME
	  readingmatrix(:,j) = y;
	 otherwise
	  error(strcat("Undefined format in ",readingnames(j),"!"))
	end
	n=int2str(size(char(readingmatrix(:,j)),2));
	form = [form,'%',n,'s\t'];
	nform = [nform,'%',n,'u\t'];
      end
    
      form=[form,'\n']; nform=[nform,'\n'];
      if any(ismissing(readingmatrix),'all'), error('Readings are not of uniform length!'); end
    
      % --- Write to file: ---
      
      % Build filename for this operation and instrument
      filename = npc_make_filename(miss);
      if isempty(prefix)
	file(end+1,1)=strcat(filename,".npc");
      else     
	file(end+1,1)=strcat(prefix,"_",filename,".npc");
      end
      
      % Open file:
      fid=fopen(file(end),'w');
    
      % Write header while also getting contents of metadata for header:
      fprintf(fid,'%s\n','% Metadata:');
      for j=1:length(headerfields)
	fprintf(fid,'%s%s\t',headerfields(j),': ');
	fprintf(fid,'%s\n',eval(strcat("num2str(",headernames(j),")")));
      end
    
      % Write column explanations:
      N=length(readingfields); % Number of columns
      fprintf(fid,'%s\n','% Content of columns:');
      for j=1:N
	fprintf(fid,'%s%2u%s\t%s\n','col ',j,':',replace(readingfields(j),'\\',''));
      end
      
      % Write column numbering (for ease of view):
      fprintf(fid,'%s\n','% Column numbers:');
      fprintf(fid,nform,1:N);
      
      % Write all columns:
      fprintf(fid,'%s\n','% Readings:');
      fprintf(fid,form,readingmatrix');
    
      % Close file:
      fclose(fid);
      
    end % loop instruments
  end % loop operations

end % switch filetype

function file = npc_write_struct(mission,filetype,filename)
% NPC_WRITE_STRUCT	Writes NPC struct to file
% 
% file = npc_write_struct(mission,filetype,filename)
% 
% mission  = A valid NPC-struct.
% filetype = char extension, indicating type of file to write:
%	     'npc' : The default ASCII format for NMDphyschem.
%	 	     Takes one operation and one instrument only. 
%	     'mat' (n/a) : Matlab binary object collection.
%	     'nc' (n/a) : IMR generic NetCDF format.
% filename = char name to be used as filename for output file. This
%	     can be the name of the original source file of the data,
%	     or if not given, will be buildt based on mission keys
%	     and other mandatory fields, depending on wanted
%	     filetype. 
%
% file	   = base name of output file (default is buildt on mission
%	     keys). 
%
% It is recommended to run NPC_VALIDATE_STRUCT on struct before writing
% to file that is to be imported to NMDphyschem, and in general
% NPC_STRIP_STRUCT as well to limit empty fields.
% 
% Empty reading fields will not be written to file, even if they are
% mandatory for NMDphyschem, assuming they will be filled by the
% NMDphyschem file-import system (e.g. sampleid).
%
% The pairs of code and value for instrumentproperty and
% parameterproperty are written to one line with the code as fieldname
% and value as content.
%
% Parameters of type DATE or DATETIME are translated to OceanSITES
% recommended units of days since 1950-01-01T00:00:00Z.
%
% Uses NPC_MERGE_READINGS NPC_STRIP_STRUCT
% See also NPC EFIELDNAMES VALUETYPE FPRINTF

% Last updated: Wed Dec 13 16:03:16 2023 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,3,nargin));
if nargin < 3 | isempty(filename), filename='';		end
if nargin < 2 | isempty(filetype), filetype='npc';	end
if isempty(mission), disp('NPC_WRITE_STRUCT : Empty input!'); file=''; return; end

% Define fillvalues:
fillvalue.STR='';
fillvalue.DEC=-999999.0;
fillvalue.INT=-999999;
fillvalue.FLT=-999999.0;

% Define base of filename:
if isempty(filename)
  filename=['npcfile' ...
	    '_',mission.missiontype ...
	    '_',int2str(mission.startyear) ...
	    '_',mission.platform ...
	    '_',int2str(mission.missionnumber)];
end

% MERGE THE READINGS IN THE MISSION FIRST:
mission = npc_merge_readings(mission);

% Code below for the different output formats:
switch filetype
 case 'npc'
  
  % --- Prepare contents of file: ---
  
  % REDUCE MISSION TO ONLY THE FIRST OPERATION AND INSTRUMENT:
  
  % [] Later Accomodate for several operations and instruments when
  % filetypes mat and nc are implemented. Cruise 2023007020 is a perfect
  % example to use for two instruments.
  mission.operation={mission.operation{1}};
  mission.operation{1}.instrument={mission.operation{1}.instrument{1}};

  % Build filename (following rules):
   filename=[filename ...
	     '_',mission.operation{1}.operationtype ...
	     '_',replace(mission.operation{1}.timestart,':','') ...
	     '_',mission.operation{1}.instrument{1}.instrumenttype ];
   file=[filename,'.',filetype];
   
   % Strip hard here, since this is file intended for input to NMDphyschem:
   mission=npc_strip_struct(mission,'hard'); % Removes only empty fields 
   
   % Get all field names in input struct (used to call struct):
   names=efieldnames(mission);
   % Strip header field names of superfluous higher level struct field names:
   headerfields=replace(names,'mission.operation{1}.instrument{1}.','\\');
   headerfields=replace(headerfields,'mission.operation{1}.','\\');
   headerfields=replace(headerfields,'mission.','\\');
   % Add numbering to properties, even when there is only one property:
   headerfields=replace(headerfields,'instrumentproperty.','instrumentproperty(1).');
   headerfields=replace(headerfields,'parameterproperty.','parameterproperty(1).');
   % Separate into header and column information:
   I=contains(headerfields,'.reading.');
   readingnames=names(I); readingfields=headerfields(I);
   headernames=names(~I); headerfields=headerfields(~I);
   % Sort \\parameter{...}. lines by number:
   A=find(contains(headerfields,'\\parameter{'));
   %split(headerfields(A),'}.'); [~,IA]=sort(ans(:,1));
   split(headerfields(A),{'{','}.'}); [~,IA]=sort(str2num(char(ans(:,2))));
   headerfields(A)=headerfields(A(IA));
   headernames(A)=headernames(A(IA));
   
   % Rearrange properties into fieldname and content:
   property={'instrumentproperty' 'parameterproperty'};
   for j=1:length(property)
     I=find(contains(headerfields,property{j})); I=I(1:2:end);
     for i=1:length(I)
       headerfields(I(i)+1)=replace(headerfields(I(i)),[property{j},'(',int2str(i),').code'],eval(headernames(I(i)))); % Put the code as fieldname for the value
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
       % then they should have sampleid running in first dimension like
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
   nform='';			% Format for the top numbering
   form='';			% Format for the columns
   readingmatrix=nan(D(1),N);	% Preallocate matrix
   for j=1:N
     y=eval(readingnames(j));	% The j-th column 
     type=valuetype(y);	% Its valuetype (handles non-scalar input now) 
     switch type
      case {'DEC','FLT'}		% Most parameters are DEC
       y(isnan(y)) = fillvalue.DEC;
       form = [form,'%9.4f\t'];
       nform = [nform,'%9u\t'];
       readingmatrix(:,j) = y(:); 
      case 'INT'			% Such as PHASE, PROFILE, SAMPLE, SAMPLESIZE
       y(isnan(y)) = fillvalue.INT;
       form = [form,'%6d\t'];
       nform = [nform,'%6u\t'];
       readingmatrix(:,j) = y(:); 
      case 'STR'			% DIRECTION
       form = [form,'%1d\t'];
       nform=[nform,'%u\t'];
       readingmatrix(:,j) = str2num(y(:)); 
      case {'DATETIME','DATE'}		% DATETIME
       form = [form,'%17.10f\t'];
       nform=[nform,'%17u\t'];
       readingmatrix(:,j) = isofix8601(y)-datenum(1950,1,1); % units = days since 1950-01-01T00:00:00Z
       % Alter the units in the struct, accordingly, and it will be stamped in the file's metadata:
       split(readingnames(j),'.reading.value')
       eval(strcat(headernames(find(contains(headernames,strcat(ans(1),".units"))))," = 'Days since 1950-01-01T00:00:00Z'"));
      otherwise
       error(strcat("Undefined format in ",readingnames(j),"!"))
     end
   end
   form=[form,'\n']; nform=[nform,'\n'];
   if any(isnan(readingmatrix),'all'), error('Readings are not of uniform length!'); end

   % --- Write to file: ---
   
   % Open file:
   fid=fopen(file,'w');
   
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
end

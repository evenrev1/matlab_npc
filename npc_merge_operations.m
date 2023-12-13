function mission = npc_merge_operations(mission)
% NPC_MERGE_OPERATIONS	Makes matrices of data from NPC struct
% 
% mission = npc_merge_operations(mission)
% 
% mission	= input struct with NPC format.
%
% mission	= output is an altered struct with matrices for
%		  readings and the most relevant metadata gathered as
%		  fields at the mission level.
%
% This makes for easier access, search and analysis in Matlab.
%
% Currently for operations of featuretype 'profile' only.  
%
% All readings are organised into MxN matrices where M is the number of
% sampleids (i.e. depths) and N is the number of operations. The
% sampleid is used as index in the first dimension in order to match
% data in the rows of the matrices.  Numeric metadata are put into 1xN
% vectors, while 'STR' and 'DATETIME' metadata are transposed to
% charecter column vectors and collected into mxN matrices.
%
% All matrices are put as fields at the mission level, and the original
% fields they are produced from are removed.
%
% NAMING CONVENTION:
% operation metadata  : mission.FIELDNAME
% instrument metadata : mission.INSTRUMENTTYPE_FIELDNAME
% reading matrices    : mission.INSTRUMENTTYPE_PARAMETERCODE
% parameter metadata  : mission.INSTRUMENTTYPE_PARAMETERCODE_FIELDNAME
%
% For secondary etc. sensors, the number 2 etc. (i.e., the ordinal) is
% appended directly to the PARAMETERCODE (e.g., mission.CTD_TEMP2).
%
% Uses NPC_MERGE_READINGS
% See also NPC GETALLFIELDS EGETFIELD ISOFIX8601 FIELDNAMES

% Last updated: Wed Dec 13 16:03:16 2023 by jan.even.oeie.nilsen@hi.no

% SETTINGS:
% Fields not to be moved up into matrices:
operationfields_to_omit  = {'instrument','featuretype'};
instrumentfields_to_omit = {'instrumenttype','instrumentid','parameter','instrumentproperty'};
parameterfields_to_omit  = {'parametercode','parameterid','ordinal','parameterproperty','reading','suppliedparametername','suppliedunits'};
% Interesting instrument- and parameterproperties:
insprops   = {'profiledirection'};
insproptyp = {'STR'};
parprops   = {'calibrationcoordinate','calibrationoffset','calibrationslope','referenceoffset','comment'};
parproptyp = {'STR'                  ,'DEC'              ,'DEC'             ,'DEC'            ,'STR'    }; 

% STANDARD FUNCTION CHECKS: 
error(nargchk(1,1,nargin));

% FIXED SETTINGS:
load npc_init 

% SIZES AND PREALLOCATING VARIABLES:
ON=length(mission.operation); 
nanvec = nans(1,ON);		% Base row vector to use in order to avoid zeros
				% instead of NaNs as fillvalue.
celvec = repmat({' '},1,ON);	% Base row cell to use in order to avoid double
				% instead of ' ' as fillvalue.
M=max(str2num(getallfields(mission,'sampleid'))); 
nanmat = nans(M,ON);		% Base matrix to use in order to avoid zeros
				% instead of NANs as fillvalue, using the
				% largest sampleid as general size. 

% MERGE THE READINGS IN THE  MISSION FIRST:
mission = npc_merge_readings(mission);



%--------------------------------------------------------------------

for O=1:ON

  % Check that operation is profile:
  if mission.operation{O}.featuretype~='4', continue; end % mandatory field

  % FILL THE OPERATION META:

  nam=fieldnames(mission.operation{O});				% The present fields
  %nam=nam(~contains(nam,operationfields_to_omit));		% Reduce list to those to use
  nam=setdiff(nam,operationfields_to_omit);		% Reduce list to those to use
  [nam,~,i]=intersect(string(nam'),allOperationNam,'stable');	% Indices for valid names present now
  namtyp=allOperationNamTyp(i);					% The types of the valid, now present fields  
  
  % Interesting operationfields:
  for i=1:length(nam)
    fienam = upper(nam(i));
    switch namtyp(i)
     case {'DATETIME','DATE'}, 
      strcat("mission.",fienam,"(O) = isofix8601(mission.operation{O}.",nam(i),");");
      eval(ans)
     case 'STR'
      if ~isfield(mission,fienam), mission.(fienam) = celvec; end % First time definition
      strcat("mission.",fienam,"{O} = mission.operation{O}.",nam(i),";");
      eval(ans)
     case {'INT','DEC'}
      if ~isfield(mission,fienam), mission.(fienam) = nanvec; end % First time definition
      strcat("mission.",fienam,"(O) = mission.operation{O}.",nam(i),";");
      eval(ans)
    end
    strcat("mission.operation{O}=rmfield(mission.operation{O},'",nam(i),"');");
    eval(ans)
  end

  
  
  %--------------------------------------------------------------------

  for I=1:length(mission.operation{O}.instrument)
    
    % First part of matrix names is instrumenttype:
    Iname=mission.operation{O}.instrument{I}.instrumenttype;	% Always uppercase already
    
    % FILL THE OPERATION META:
    
    nam=fieldnames(mission.operation{O}.instrument{I});			% The present fields
    hasproperty=any(contains(nam,'instrumentproperty'));		% Are there instrumentproperties?
    %nam=nam(~contains(nam,instrumentfields_to_omit));			% Reduce list to those to use
    nam=setdiff(nam,instrumentfields_to_omit);			% Reduce list to those to use
    [nam,~,i]=intersect(string(nam'),allInstrumentNam,'stable');	% Indices for valid names present now
    namtyp=allInstrumentNamTyp(i);					% The types of the valid, now present fields  
  
    % Interesting instrumentfields:
    for i=1:length(nam)
      fienam = strcat(Iname,"_",upper(nam(i))); 
      switch namtyp(i)
       case {'DATETIME','DATE'}, 
	strcat("mission.",fienam,"(O) = isofix8601(mission.operation{O}.instrument{I}.",nam(i),");");
	eval(ans)
       case 'STR'
	if ~isfield(mission,fienam), mission.(fienam) = celvec; end % First time definition
	strcat("mission.",fienam,"{O} = mission.operation{O}.instrument{I}.",nam(i),";");
	eval(ans)
       case {'INT','DEC'}
	if ~isfield(mission,fienam), mission.(fienam) = nanvec; end % First time definition
	strcat("mission.",fienam,"(O) = mission.operation{O}.instrument{I}.",nam(i),";");
	eval(ans)
      end
      strcat("mission.operation{O}.instrument{I}=rmfield(mission.operation{O}.instrument{I},'",nam(i),"');");
      eval(ans)
    end

    % Interesting instrumentproperties:
    if hasproperty
      tmp=mission.operation{O}.instrument{I}.instrumentproperty;
      for i=1:length(insprops)
	egetfield(tmp,'code',insprops{i},'value');
	if ~isempty(ans)
	  fienam = [Iname,'_',upper(insprops{i})];
	  switch insproptyp{i}
	   case {'INT','DEC'}
	    if ~isfield(mission,fienam), mission.(fienam) = nanvec; end % First time definition
	    eval(['mission.',fienam,'(O) = ans;']);
	   otherwise
	    eval(['mission.',fienam,'(O) = ans'';']); % Just add char column vector
	  end	    
	end
      end
    end
    
    
    %--------------------------------------------------------------------
    
    for P=1:length(mission.operation{O}.instrument{I}.parameter)

      % Second part of matrix name is parametercode (with ordinal if > 1):
      try
	ordinal=num2str(getfield(mission.operation{O}.instrument{I}.parameter{P},'ordinal'));
      catch
	ordinal='';
      end
      Pname = [mission.operation{O}.instrument{I}.parameter{P}.parametercode,ordinal];

      % FILL THE OPERATION META:
      
      nam=fieldnames(mission.operation{O}.instrument{I}.parameter{P});		% The present fields
      hasproperty=any(contains(nam,'parameterproperty'));			% Are there parameterproperties?
      %nam=nam(~contains(nam,parameterfields_to_omit));				% Reduce list to those to use
      nam=setdiff(nam,parameterfields_to_omit);				% Reduce list to those to use
      [nam,~,i]=intersect(string(nam'),allParameterNam,'stable');		% Indices for valid names present now and reduce to valid field names present
      namtyp=allParameterNamTyp(i);						% The types of the valid, now present fields  

      % Interesting parameterfields:
      for i=1:length(nam)
	fienam = strcat(Iname,"_",Pname,"_",upper(nam(i))); 
	switch namtyp(i)
	 case {'DATETIME','DATE'}, 
	  strcat("mission.",fienam,"(O) = isofix8601(mission.operation{O}.instrument{I}.parameter{P}.",nam(i),");");
	  eval(ans)
	 case 'STR'
	  if ~isfield(mission,fienam), mission.(fienam) = celvec; end % First time definition
	  strcat("mission.",fienam,"{O} = mission.operation{O}.instrument{I}.parameter{P}.",nam(i),";");
	  eval(ans)
	 case {'INT','DEC'}
	  if ~isfield(mission,fienam), mission.(fienam) = nanvec; end % First time definition
	  strcat("mission.",fienam,"(O) = mission.operation{O}.instrument{I}.parameter{P}.",nam(i),";");
	  eval(ans)
	end
	strcat("mission.operation{O}.instrument{I}.parameter{P}=rmfield(mission.operation{O}.instrument{I}.parameter{P},'",nam(i),"');");
	eval(ans)
      end

      % Interesting parameterproperties:
      if hasproperty
	tmp=mission.operation{O}.instrument{I}.parameter{P}.parameterproperty;
	for i=1:length(parprops)
	  egetfield(tmp,'code',parprops{i},'value');
	  if ~isempty(ans)
	    fienam = [Iname,'_',Pname,'_',upper(parprops{i})];
	    switch parproptyp{i}
	     case {'INT','DEC'}
	      if ~isfield(mission,fienam), mission.(fienam) = nanvec; end % First time definition
	      eval(['mission.',fienam,'(O) = ans;']);
	     otherwise
	      eval(['mission.',fienam,'(O) = ans'';']); % Just add char column vector
	    end	    
	  end
	end
      end
      
      
      % FILL THE READING MATRICES:
      
      % Make the single reading fields into one collumn vector each:
      %r = npc_localmerge_readings(mission.operation{O}.instrument{I}.parameter{P});
      % Get the already merged reading done above by NPC_MERGE_READINGS:
      r = mission.operation{O}.instrument{I}.parameter{P}.reading;
      
      % Change type of some parameters to fit in a matrix column:
      %%r.sampleid = str2num(r.sampleid);					% sampleid is going to be used as indices  
      %% [FIXED by forcing proper valuetype INT in NPC_VALIDATE_STRUCT]
      if  strcmp(Pname,'DATETIME'), r.value=isofix8601(r.value); end	% Need numeric column, using serial day
      
      % At first time use the full size NaN matrix as base, to avoid zero as fillvalue:
      if ~isfield(mission,[Iname,'_',Pname]), mission.([Iname,'_',Pname]) = nanmat; end % First time definition
      
      % Expand the matrix with the operation and fill at the correct places with sampleid:
      eval(['mission.',Iname,'_',Pname,'(r.sampleid,O)=r.value;'])
      
      % Quality is always 1x1 and char:
      eval(['mission.',Iname,'_',Pname,'_QC(r.sampleid,O)=r.quality;'])
	
      % Remove the moved data:
      mission.operation{O}.instrument{I}.parameter{P}=rmfield(mission.operation{O}.instrument{I}.parameter{P},'reading');
    
    end
    
  end
  
end

% FINAL ADJUSTMENTS:

% List the new fields on the mission level (without old fields):
fienam=setdiff(fieldnames(mission),[allMissionNam,"operation"]);

for i=1:numel(fienam)
  
  x=mission.(fienam(i));
  
  if iscell(x)		% Rearrange the cells to char arrays
    
    %%if i==166, keyboard; end
    %%disp(int2str(i));
    x=pad(x);
    x=x';
    x=cell2mat(x);
    x=x';
   
  elseif isnumeric(x) & false	% Remove the superflous rows at bottom of reading matrices, where needed.
				% NOT NECESSARY when sampleid governs size of all reading fields
				% and removal causes problems when there are actual NaNs in the data.
    [M,N]=size(x);
    if M>1
      x=rinsemat(x,1,'strip');
      % strcat("mission.",fienam(i),"=rinsemat(mission.",fienam(i),",1,'strip');");
      % eval(ans);
    end
  
  end

  mission.(fienam(i))=x;

end

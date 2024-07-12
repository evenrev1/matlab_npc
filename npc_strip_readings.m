function inst = npc_strip_readings(inst)
% NPC_STRIP_READINGS	Strips reading fields from instrument struct
% 
% inst = npc_strip_readings(inst)
% 
% inst	= input single instrument-level struct
%
% inst	= output instrument-level struct without reading fields in
%         any parameter field
% 
% Used by NPC_CHECK_PARAMETERS  
% See also RMFIELD 

% Last updated: Thu Jul 11 19:27:50 2024 by jan.even.oeie.nilsen@hi.no

error(nargchk(1,1,nargin));

for i=1:numel(inst.parameter)
  inst.parameter{i}=rmfield(inst.parameter{i},'reading');
end

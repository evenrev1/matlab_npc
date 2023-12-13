# NMDphysChem (NPC) Matlab toolbox v0.9
 A toolbox to handle data for and from NMDphyschem, by Jan Even Øie Nilsen. 
 Last updated: Wed Dec 13 17:42:36 2023 by jan.even.oeie.nilsen@hi.no

 Info and initialization:

                     contents - Contents file (this file)
                    README.md - This file in Markdown
                     npc_init - Updates all NPC toolbox parameters

 High level functions: 

              npc_get_mission - Reads a mission from NMDphyschem API
          npc_validate_struct - Validates an NPC struct
         npc_merge_operations - Makes matrices of data from NPC struct

             npc_build_struct - Builds a struct with fields for NMDphyschem
             npc_set_property - Sets property value for NMDphyschem
             npc_strip_struct - Strips NPC struct of empty fields
             npc_write_struct - Writes NPC struct to file

 Reference tools: 

           npc_read_reference - Reads info from reference lists
     npc_read_platformcodesys - Reads info from NMDreference:platformcodesys

 Subroutines:

           npc_merge_readings - Merges the reading fields in a mission
         npc_check_parameters - Checks for inconsistencies among parameters
      npc_localmerge_readings - Merges reading fields of a parameter
     npc_squeeze_nmdreference - Reorganizes table from NMDreference
           npc_strip_readings - Strips reading fields from instrument struct

 Metadata storage:

                 npc_init.mat - MAT-File storing NPC_INIT data
        toktnummer_regler.txt - couples platformcodes to IMR ship numbers

 Required toolboxes: 

	[https://github.com/evenrev1/evenmat.git](https://github.com/evenrev1/evenmat.git) (e.g. for GETALLFIELDS,
	EFIELDNAMES, EGETFIELD, VALUETYPE, ISOFIX8601).

 NMDphyschem documentation: 
 
	[https://confluence.imr.no/x/jgD4C](https://confluence.imr.no/x/jgD4C)

 Notes:

	The fields operation, instrument, and parameter are always
	cell, while instrumentproperty, parameterproperty, and
	reading are arrays since they are always the same
	structure within their parent field. 

	In the NMDphyschem API/DB data values have fields of
	different names based on their valuetype (valueint, valuedec,
	valuedatetime, valuestr). In the NPC toolbox and its structs
	the common field name is 'value' (NPC_GET_MISSION changes all
	these upon fetching the data.) 





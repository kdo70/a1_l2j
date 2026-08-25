class MacroAPI extends Object
	native;

native static function RequestMacroList();
native static function RequestUseMacro(int MacroID);
native static function RequestDeleteMacro(int MacroID);
native static function bool RequestMakeMacro(int MacroID, string Name, string IconName, int IconNum, string Description, array<string> CommandList);

// (cpptext)
// (cpptext)
// (cpptext)
// (cpptext)
// (cpptext)

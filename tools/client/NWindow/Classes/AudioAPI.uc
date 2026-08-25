class AudioAPI extends Object
	native;

native static function PlaySound( String a_SoundName );
native static function PlayMusic( String a_MusicName, FLOAT a_FadeInTime, optional bool a_bLooping, optional bool a_bVoice );	//solasys
native static function StopMusic();	//solasys
native static function StopVoice(); //solasys

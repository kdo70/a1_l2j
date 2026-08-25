class PetitionAPI extends Object
	native;

native static function RequestPetitionCancel();
native static function RequestPetition( String a_Message, int a_PetitionType );
native static function RequestPetitionFeedBack( int a_Rate, String a_Message );

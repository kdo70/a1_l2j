class PartyMatchWndCommon extends UIScript;


function String GetAmbiguousLevelString( int a_Level, bool a_HasSpace )
{
	local String AmbiguousLevelString;

	if( 10 > a_Level )
	{
		if( a_HasSpace )
			AmbiguousLevelString = "1 ~ 9";
		else
			AmbiguousLevelString = "1~9";
	}
	else if( 70 > a_Level )
	{
		if( a_HasSpace )
			AmbiguousLevelString = (a_Level/10) * 10 $ " ~ " $ (a_Level/10) * 10 + 9;
		else
			AmbiguousLevelString = (a_Level/10) * 10 $ "~" $ (a_Level/10) * 10 + 9;
	}
	else
	{
		if( a_HasSpace )
			AmbiguousLevelString = "70 ~ " $ MAX_Level;
		else
			AmbiguousLevelString = "70~" $ MAX_Level;
	}

	return AmbiguousLevelString;
}

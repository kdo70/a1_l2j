class TeaserSlideWnd extends UICommonAPI;

const TIMER_ID = 0;
const TIMER_DELAY = 5000;

var WindowHandle m_TeaserSlideWnd_Main;
var WindowHandle m_BattleShot;	
var WindowHandle m_BattleShot1;	
var WindowHandle m_BattleShot2; 	
var WindowHandle m_BattleShot3;	
var WindowHandle m_Female;	
var WindowHandle m_Female1;
var WindowHandle m_Island;
var WindowHandle m_Island1;
var WindowHandle m_Island2;
var WindowHandle m_Island3;
var WindowHandle m_Male;
var WindowHandle m_Male1;
var WindowHandle m_Mark;
var WindowHandle m_Meeting1;
var WindowHandle m_Meeting2;
var WindowHandle m_Meeting3;
var WindowHandle m_Meeting4;
var WindowHandle m_Frame;
var WindowHandle m_OutsideFrame;
var WindowHandle m_Subtitle1;
var WindowHandle m_Subtitle2;
var WindowHandle m_Subtitle3;
var WindowHandle m_Subtitle4;
var WindowHandle m_Subtitle5;
var WindowHandle m_Subtitle6;
var WindowHandle m_Subtitle7;
var WindowHandle m_Subtitle8;
var WindowHandle m_blankback;
var WindowHandle m_blankback1;
var WindowHandle m_WhiteOut;
var WindowHandle m_LogoWhite;
var WindowHandle m_blankback2;
var WindowHandle m_FrameWnd;

var string t_Subtitle1;
var string t_Subtitle2;
var string t_Subtitle3;
var string t_Subtitle4;
var string t_Subtitle5;
var string t_Subtitle6;
var string t_Subtitle7;
var string t_Subtitle8;
var string t_voice;


var WindowHandle m_BillBoardLeft;
var WindowHandle m_BillBoardRight;

var float TempSoundVol;
var int CurrentTimer;
var int GlobalWidth;
var int GlobalMove;
var int GlobalLeft1;
var int GlobalRight2;
var int GlobalPixel;
var int GlobalMoveX;
var int totalplaytime;

var bool stat1;
var int stat2;

var bool gEndSlide;

var bool Slide1;
var int Slide2;

var float speedoffset;

// boolean value to check if scene is already playing - Neverdie
var bool m_PlaySceneStarted;


function OnLoad()
{
	
	
	
	
	RegisterEvent(EV_ShowPlaySceneInterface );
	RegisterEvent(EV_ResolutionChanged);	//해상도 바뀔때 발생하는 이벤트
	m_BattleShot = GetHandle( "TeaserSlideWnd.Slide_BattleShot1");
	m_TeaserSlideWnd_Main = GetHandle ("TeaserSlideWnd");
	//m_BattleShot = GetHandle( "TeaserSlideWnd.Slide_BattleShot1");
	m_BattleShot1 = GetHandle( "TeaserSlideWnd.Slide_BattleShot2");
	m_BattleShot2 = GetHandle( "TeaserSlideWnd.Slide_BattleShot3"); 	
	m_BattleShot3 = GetHandle( "TeaserSlideWnd.Slide_BattleShot4");
	m_Female = GetHandle( "TeaserSlideWnd.Slide_Female");
	m_Female1 = GetHandle( "TeaserSlideWnd.Slide_Female1");
	m_Island = GetHandle( "TeaserSlideWnd.Slide_Island");
	m_Island1 = GetHandle( "TeaserSlideWnd.Slide_Island1");
	m_Island2 = GetHandle( "TeaserSlideWnd.Slide_Island2");
	m_Island3 = GetHandle( "TeaserSlideWnd.Slide_Island2");
	m_Male = GetHandle( "TeaserSlideWnd.Slide_Male");
	m_Male1 = GetHandle( "TeaserSlideWnd.Slide_Male1");
	m_Mark = GetHandle( "TeaserSlideWnd.Slide_Mark");
	m_Meeting1 = GetHandle( "Slide_Meeting");
	m_Meeting2 = GetHandle( "TeaserSlideWnd.Slide_Meeting1");
	m_Meeting3 = GetHandle( "TeaserSlideWnd.Slide_Meeting2");
	m_Meeting4 = GetHandle( "TeaserSlideWnd.Slide_Meeting3");
	m_Frame = GetHandle( "TeaserSlideWnd.Slide_TextFrame");
	m_OutsideFrame = GetHandle("TeaserSlideWnd.OutsideFrame");
	m_Subtitle1 = GetHandle( "TeaserSlideWnd.Slide_Subtitle1");
	m_Subtitle2 = GetHandle( "TeaserSlideWnd.Slide_Subtitle2");
	m_Subtitle3 = GetHandle( "TeaserSlideWnd.Slide_Subtitle3");
	m_Subtitle4 = GetHandle( "TeaserSlideWnd.Slide_Subtitle4");
	m_Subtitle5 = GetHandle( "TeaserSlideWnd.Slide_Subtitle5");
	m_Subtitle6 = GetHandle( "TeaserSlideWnd.Slide_Subtitle6");
	m_Subtitle7 = GetHandle( "TeaserSlideWnd.Slide_Subtitle7");
	m_blankback = GetHandle( "TeaserSlideWnd.Main_Frame" );
	m_blankback1 = GetHandle( "TeaserSlideWnd.Main_Frame2" );
	m_blankback2 = GetHandle( "TeaserSlideWnd.Main_Frame3" );
	m_Subtitle8 = GetHandle( "TeaserSlideWnd.Slide_Subtitle8");
	m_FrameWnd = GetHandle("TeaserSlideWnd.OutsideFrame12");

	 
	m_WhiteOut = GetHandle( "TeaserSlideWnd.Slide_WhiteOut");
	m_LogoWhite = GetHandle( "TeaserSlideWnd.Slide_MarkAlpha");
	 
	
	m_BillBoardLeft = GetHandle( "TeaserSlideWnd.billboardleft" );
	m_BillBoardRight = GetHandle( "TeaserSlideWnd.billboardright" );
	
	
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle1.SolasysResult1",t_Subtitle1);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle2.SolasysResult1",t_Subtitle2);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle3.SolasysResult1",t_Subtitle3);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle4.SolasysResult1",t_Subtitle4);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle5.SolasysResult1",t_Subtitle5);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle6.SolasysResult1",t_Subtitle6);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle7.SolasysResult1",t_Subtitle7);
	class'UIAPI_TEXTURECTRL'.static.SetTexture( "TeaserSlideWnd.Slide_Subtitle8.SolasysResult1",t_Subtitle8);


	
}      

// 초기화 
function ResetReady()
{
	
	local OptionWnd script;
	
	// check if scene is already playing - Neverdie
	if( m_PlaySceneStarted )
	{
		Debug( "PlayScene already started!!" );
		return;
	}
	m_PlaySceneStarted = true;
	
	gEndSlide = true;

	script = OptionWnd( GetScript("OptionWnd") );
	
	TempSoundVol = script.gSoundVolume;
	SetSoundVolume( 0.f );
	
	m_BattleShot.HideWindow();	
	m_BattleShot1.HideWindow();	
	m_BattleShot2.HideWindow(); 	
	m_BattleShot3.HideWindow();	
	m_Female.HideWindow();	
	m_Female1.HideWindow();
	m_Island.HideWindow();
	m_Island1.HideWindow();
	m_Island2.HideWindow();
	m_Island3.HideWindow();
	m_Male.HideWindow();
	m_Male1.HideWindow();
	m_Mark.HideWindow();
	m_Meeting1.HideWindow();
	m_Meeting2.HideWindow();
	m_Meeting3.HideWindow();
	m_Meeting4.HideWindow();
	m_Frame.HideWindow();
	m_OutsideFrame.HideWindow();
	m_Subtitle1.HideWindow();
	m_Subtitle2.HideWindow();
	m_Subtitle3.HideWindow();
	m_Subtitle4.HideWindow();
	m_Subtitle5.HideWindow();
	m_Subtitle6.HideWindow();
	m_Subtitle7.HideWindow();
	m_Subtitle8.HideWindow();
	m_blankback.HideWindow();
	m_blankback1.HideWindow();
	m_WhiteOut.HideWindow();
	m_LogoWhite.HideWindow();
	m_blankback2.HideWindow();
	m_FrameWnd.HideWindow();

	totalplaytime = 0;

	class'AudioAPI'.static.PlayMusic( t_voice, 0.f, FALSE, TRUE ); //나오는 배경음악
	debug("몇번들어올까나");
	stat1 = false;
	stat2 = 0;
	speedoffset=1.f;
	
	SetUIState("SlideQuestState");
	
	CheckResolution();
	FixWindow43();
	m_TeaserSlideWnd_Main.ShowWindow();
	//m_ResultAnimation1.HideWindow();
	
	class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 0 , 2000);	
}      

function FixWindow43()//4:3강제 세팅할 함수.
{
	m_Mark.SetWindowSizeRel43(1.f,1.f,0,0);

	m_BattleShot3.SetWindowSizeRel43(1.f,1.f,0,0);	

	m_Island.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Island1.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Island2.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Island3.SetWindowSizeRel43(1.f,1.f,0,0);

	m_Meeting2.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Meeting3.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Meeting4.SetWindowSizeRel43(1.f,1.f,0,0);

	m_FrameWnd.SetWindowSizeRel43(1.f,1.f,0,0);

	m_Subtitle1.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle2.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle3.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle4.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle5.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle6.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle7.SetWindowSizeRel43(1.f,1.f,0,0);
	m_Subtitle8.SetWindowSizeRel43(1.f,1.f,0,0);

	m_blankback.SetWindowSizeRel43(1.f,1.f,0,0);
	m_blankback1.SetWindowSizeRel43(1.f,1.f,0,0);
	m_blankback2.SetWindowSizeRel43(1.f,1.f,0,0);

	m_WhiteOut.SetWindowSizeRel43(1.f,1.f,0,0);
	m_LogoWhite.SetWindowSizeRel43(1.f,1.f,0,0);

	

}

function OnTimer(int TimerID)
{
	if (TimerID==0)	
	//검정화면	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 0);
		//m_TeaserSlideWnd_Main.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 1,3000);
		CurrentTimer =1;
		Debug("현재슬라이드타이머=" @ CurrentTimer @ Self ); 
		totalplaytime = totalplaytime + 3000;
	}	
	if (TimerID==1)	
	//빈화면	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 1);
		//m_TeaserSlideWnd_Main.HideWindow();
	
		if (gEndSlide == true)
		{
		m_FrameWnd.HideWindow();
		m_FrameWnd.ShowWindow();
		m_FrameWnd.SetFocus();
		m_blankback.ShowWindow();
		m_blankback2.ShowWindow();
//		m_FrameWnd.ShowWindow();
	
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 2,2000);
		CurrentTimer =2;
		Debug("현재슬라이드타이머=" @ CurrentTimer @ Self);
		totalplaytime = totalplaytime + 2000;
		}
	}	
	if (TimerID==2)	
	//마크	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 2);
		m_blankback.HideWindow();
		if (gEndSlide == true)
		{
		m_mark.ShowWindow();

		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 3,3500);
		CurrentTimer =3;
		Debug("현재슬라이드타이머=" @ CurrentTimer @ Self);
		totalplaytime = totalplaytime + 3500;
		}
	}	
	if (TimerID==3)	
	//빈화면	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 3);
		m_mark.HideWindow();
		if (gEndSlide == true)
		{
		m_blankback1.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 4,1000);
		CurrentTimer =4;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 1000;
		}
	}	
	if (TimerID==4)	
	//자막1	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 4);
		m_blankback1.HideWindow();
		if (gEndSlide == true)
		{
		m_Subtitle1.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 5,5300);
		CurrentTimer =5;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 5300;
		}
	}	
	if (TimerID==5)	
	//자막2	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 5);
		m_Subtitle1.HideWindow();
		if (gEndSlide == true)
		{
		m_Subtitle2.ShowWindow();
		m_blankback2.HideWindow();
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 6,6000);
		CurrentTimer =6;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 6000;
		}
	}	
	if (TimerID==6)	
	//회의	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 6);
		m_Subtitle2.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.ShowWindow();
		m_FrameWnd.SetFocus();
		m_Meeting1.ShowWindow();
		m_Meeting1.ClearAnchor();
		m_Meeting1.Move( (GlobalMove/4), 0, 14.f*speedoffset );		
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 7,6000);
		CurrentTimer =7;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 6000;
		}
	}	
	if (TimerID==7)	
	//회의클로즈	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 7);
		m_FrameWnd.SetFocus();
		m_Meeting1.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_Meeting2.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 8,3000);
		CurrentTimer =8;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3000;
		}
	}	
	if (TimerID==8)	
	//회의클로즈2	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 8);
		m_Meeting2.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_Meeting3.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 9,3500);
		CurrentTimer =9;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3500;
		}
	}	
	if (TimerID==9)	
	//회의클로즈	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 9);
		m_Meeting3.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_Meeting4.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 10,3000);
		CurrentTimer =10;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3000;
		}
	}	
	if (TimerID==10)	
	//자막3	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 10);
		m_Meeting4.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.HideWindow();
		m_Subtitle3.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 11,3800);
		CurrentTimer =11;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3800;
		}
	}	
	if (TimerID==11)	
	//섬전체	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 11);
		m_Subtitle3.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.ShowWindow();
		m_FrameWnd.SetFocus();
		m_Island.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 12,2500);
		CurrentTimer =12;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2500;
		}
	}	
	if (TimerID==12)	
	//섬확장1	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 12);
		m_Island.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_Island1.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 13,2500);
		CurrentTimer =13;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2500;
		}
	}	
	if (TimerID==13)	
	//자막4	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 13);
		m_Island1.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.HideWindow();
		m_Subtitle4.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 14,4800);
		CurrentTimer =14;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 4800;
		}
	}	
	if (TimerID==14)	
	//카마엘전투1	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 14);
		m_Subtitle4.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.ShowWindow();
		m_FrameWnd.SetFocus();
		m_BattleShot.ShowWindow();
		m_BattleShot.ClearAnchor();
		m_BattleShot.Move(  (GlobalMove/4), 0, 15.f*speedoffset  );
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 15,2500);
		CurrentTimer =15;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2500;
		}
	}	
	if (TimerID==15)	
	//카마엘전투2	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 15);
		m_BattleShot.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_BattleShot1.ShowWindow();
		m_BattleShot1.ClearAnchor();
		m_BattleShot1.Move( -1 *(GlobalMove/5), 0, 15.f*speedoffset );
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 16,2000);
		CurrentTimer =16;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2000;
		}
	}	
	if (TimerID==16)	
	//카마엘전투	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 16);
		m_BattleShot1.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_BattleShot2.ShowWindow();
		m_BattleShot2.ClearAnchor();
		m_BattleShot2.Move( -1 * (GlobalMove/5), 0, 10.f*speedoffset  );
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 17,2000);
		CurrentTimer =17;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2000;
		}
	}	
	if (TimerID==17)	
	//카마엘전투4	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 17);
		m_BattleShot2.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_BattleShot3.ShowWindow();
		m_BattleShot3.ClearAnchor();
		//m_BattleShot3.Move( (GlobalMove/5), 0, 20.f*speedoffset  );
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 18,2300);
		CurrentTimer =18;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2300;
		}
	}	
	if (TimerID==18)	
	//자막5	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 18);
		m_BattleShot3.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.HideWindow();
		m_Subtitle5.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 19,4900);
		CurrentTimer =19;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 4900;
		}
	}	
	if (TimerID==19)	
	//카마엘남자	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 19);
		m_Subtitle5.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.ShowWindow();
		m_FrameWnd.SetFocus();
		m_Male.ShowWindow();
		m_Male.ClearAnchor();
		m_Male.Move( (GlobalMove/5), 0, 14.f*speedoffset  );
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 20,3000);
		CurrentTimer =20;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3000;
		}
	}	
	if (TimerID==20)	
	//카마엘남자2	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 20);
		m_Male.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_Male1.ShowWindow();
		m_Male1.ClearAnchor();
		m_Male1.Move( (GlobalMove/5), 0, 14.f*speedoffset  );
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 21,3300);
		CurrentTimer =21;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3300;
		}
	}	
	if (TimerID==21)	
	//자막6	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 21);
		m_FrameWnd.SetFocus();
		m_Male1.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.HideWindow();
		m_Subtitle6.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 22,3000);
		CurrentTimer =22;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3000;
		}
	}	
	if (TimerID==22)	
	//카마엘여자	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 22);
		m_Subtitle6.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.ShowWindow();
		m_FrameWnd.SetFocus();
		m_Female.ShowWindow();
		m_Female.ClearAnchor();
		m_Female.Move( -1 * (GlobalMove/5), 0, 14.f*speedoffset  );
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 23,3000);
		CurrentTimer =23;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3000;
		}
	}	
	if (TimerID==23)	
	//카마엘여자2	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 23);
		m_Female.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.SetFocus();
		m_Female1.ShowWindow();
		m_Female1.ClearAnchor();
		m_Female1.Move(-1 *(GlobalMove/5), 0, 16.f*speedoffset  );
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 24,3300);
		CurrentTimer =24;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3300;
		}
	}	
	if (TimerID==24)	
	//자막7	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 24);
		m_Female1.HideWindow();
		if (gEndSlide == true)
		{
		m_FrameWnd.HideWindow();
		m_blankback2.ShowWindow();
		m_Subtitle7.ShowWindow();
		
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 25,4400);
		CurrentTimer =25;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 4400;
		}
	}	
	if (TimerID==25)	
	//자막8	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 25);
		m_Subtitle7.HideWindow();
		if (gEndSlide == true)
		{
		m_Subtitle8.ShowWindow();
		m_blankback2.HideWindow();
		m_FrameWnd.HideWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 26,3000);
		CurrentTimer =26;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3000;
		}
	}	
	if (TimerID==26)	
	//화이트	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 26);
		m_Subtitle8.HideWindow();
		
		if (gEndSlide == true)
		{
		m_WhiteOut.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 27,2000);
		CurrentTimer =27;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 2000;
		}
	}	
	if (TimerID==27)	
	//로고	
	{	
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 27);
		m_WhiteOut.HideWindow();
		if (gEndSlide == true)
		{
		m_LogoWhite.ShowWindow();
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 28, 3500);
		CurrentTimer =28;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3500;
		}
	}	
	if (TimerID == 28)
	{
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", 28);
		m_LogoWhite.HideWindow();
		if (gEndSlide == true)
		{
		class'UIAPI_WINDOW'.static.SetUITimer("TeaserSlideWnd", 29, 8000);
		CurrentTimer =29;
		Debug("현재슬라이드타이머=" @ CurrentTimer);
		totalplaytime = totalplaytime + 3500;
		}
	}


	if (TimerID == 29)
	{
		EndShow();
	}

}

//Event
function OnEvent( int a_EventID, String a_Param )
{
	switch( a_EventID )
	{
	// Solasys Window Open
	case EV_ShowPlaySceneInterface:	
		
		ResetReady();

		break;
	case EV_ResolutionChanged:
		FixWindow43();
		CheckResolution();
		break;
	}	
}
/*
function OnKeyUp( EInputKey nKey )
{
	switch( nKey )
	{
	//Stop the Animation
	case IK_Escape:
		EndShow();
		break;
	
	}	
}
*/
function CheckResolution()
{
	local int CurrentMaxWidth; 
	local int CurrentMaxHeight;
	local int a1;
	local int a2;
	
	
	debug("MinimapExpand - Checkresolution");

	GetCurrentResolution (CurrentMaxWidth, CurrentMaxHeight);
	
	GlobalWidth = CurrentMaxWidth;
	GlobalMove = (CurrentMaxHeight*1024)/768;
	GlobalMoveX = 0;
	//GlobalPixel = 
	

	

	if (CurrentMaxWidth*3 <= CurrentMaxHeight*4)
	{
	
		m_Meeting1.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_BattleShot.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_BattleShot1.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_BattleShot2.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		//m_BattleShot3.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_Male.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_Male1.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_Female.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		m_Female1.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		
		//m_ResultAnimation1.SetWindowSize( (((CurrentMaxWidth*768)/1024)*1440)/768 , (CurrentMaxWidth*768)/1024);
		
	}
	
	
	else 
	{
		m_Meeting1.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_BattleShot.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_BattleShot1.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_BattleShot2.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		//m_BattleShot3.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_Male.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_Male1.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_Female.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		m_Female1.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
		
		
		
		//m_ResultAnimation1.SetWindowSize((CurrentMaxHeight*1440)/768, CurrentMaxHeight);
	}
	
	m_Meeting1.GetWindowSize(a1,a2);
	
	speedoffset = 1440 / a1;

	
	//m_ResultAnimation1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_BattleShot.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );	
	m_BattleShot1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );	
	m_BattleShot2.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 ); 	
	m_BattleShot3.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );	
	m_Female.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );	
	m_Female1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Island.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Island1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Island2.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Island3.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Male.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Male1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Mark.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Meeting1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Meeting2.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Meeting3.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Meeting4.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Frame.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_OutsideFrame.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle2.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle3.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle4.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle5.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle6.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle7.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_blankback.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_blankback1.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_blankback2.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_Subtitle8.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_WhiteOut.SetAnchor("TeaserSlideWnd", "CenterCenter", "CenterCenter", 0, 0 );
	m_BillBoardLeft.SetWindowSize((CurrentMaxWidth-((CurrentMaxHeight*1024)/768))/2+2, CurrentMaxHeight);
	m_BillBoardRight.SetWindowSize((CurrentMaxWidth-((CurrentMaxHeight*1024)/768))/2+2, CurrentMaxHeight);

	m_BillBoardLeft.SetAnchor("TeaserSlideWnd", "CenterLeft", "CenterLeft", 0, 0 );
	m_BillBoardRight.SetAnchor("TeaserSlideWnd", "CenterRight", "CenterRight", 0, 0 );
	
}

//function OnShow()
//{
//	ExecuteEvent(EV_ShowPlaySceneInterface);
//}

function EndShow()
{
	local int i;

	gEndSlide = false;

	debug ("end slide실행 되었음");

	for ( i=1 ; i <29; ++i)
	{
		class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", i);
	}

	class'UIAPI_WINDOW'.static.KillUITimer("TeaserSlideWnd", CurrentTimer );
	//m_LogoWhite.HideWindow();
	m_TeaserSlideWnd_Main.HideWindow();
	class'AudioAPI'.static.StopVoice();	//퀘스트가 끝날때 음악 멈추게 하는것.
	SetUIState("GamingState");
	debug("게이밍스테이트이동");
	totalplaytime = totalplaytime + 0;
	totalplaytime = totalplaytime / 1000;
	debug ("최종 플레이타임:" @ totalplaytime @ "초");
	SetSoundVolume( TempSoundVol );

	m_BattleShot.HideWindow();	
	m_BattleShot1.HideWindow();	
	m_BattleShot2.HideWindow(); 	
	m_BattleShot3.HideWindow();	
	m_Female.HideWindow();	
	m_Female1.HideWindow();
	m_Island.HideWindow();
	m_Island1.HideWindow();
	m_Island2.HideWindow();
	m_Island3.HideWindow();
	m_Male.HideWindow();
	m_Male1.HideWindow();
	m_Mark.HideWindow();
	m_Meeting1.HideWindow();
	m_Meeting2.HideWindow();
	m_Meeting3.HideWindow();
	m_Meeting4.HideWindow();
	m_Frame.HideWindow();
	m_OutsideFrame.HideWindow();
	m_Subtitle1.HideWindow();
	m_Subtitle2.HideWindow();
	m_Subtitle3.HideWindow();
	m_Subtitle4.HideWindow();
	m_Subtitle5.HideWindow();
	m_Subtitle6.HideWindow();
	m_Subtitle7.HideWindow();
	m_Subtitle8.HideWindow();
	m_blankback.HideWindow();
	m_blankback1.HideWindow();
	m_WhiteOut.HideWindow();
	m_LogoWhite.HideWindow();
	m_blankback2.HideWindow();
	m_FrameWnd.HideWindow();

	// Mark end of show - Neverdie
	m_PlaySceneStarted = false;	
}

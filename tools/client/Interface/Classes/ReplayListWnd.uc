class ReplayListWnd extends UIScript;


const REPLAY_DIR="..\\REPLAY";
const REPLAY_EXTENSION=".L2R";

var Array<string> m_StrFileList;


function OnLoad()
{
}

function OnShow()
{
	InitReplayList();
}

function InitReplayList()
{
	local Array<string> strReplayFileList;
	local int i;
	local int iLength;
	local string strFileName;

	// 있던 아이템 지워주고
	class'UIAPI_LISTCTRL'.static.DeleteAllItem("ReplayListWnd.ReplayListCtrl");

	// 파일 리스트 얻어와서 넣어준다
	GetFileList(strReplayFileList, REPLAY_DIR, REPLAY_EXTENSION);

	for(i=0; i<strReplayFileList.Length; ++i)
	{
		iLength=Len(strReplayFileList[i])-Len(REPLAY_EXTENSION);
		strFileName=Left(strReplayFileList[i], iLength);
		AddItem(i, strFileName);
	}
}


function OnEvent( int Event_ID, string param )
{
}

function AddItem(int iNum, string strFileName)
{
	local LVDataRecord	record;
	local LVData		data;

	data.szData = string(iNum);
	record.LVDataList[0] = data;
	data.szData = strFileName;
	record.LVDataList[1] = data;
	class'UIAPI_LISTCTRL'.static.InsertRecord("ReplayListWnd.ReplayListCtrl", record );
}

function string GetSelectedFileName()
{
	local int index;
	local LVDataRecord record;
	local string strFileName;

	index = class'UIAPI_LISTCTRL'.static.GetSelectedIndex("ReplayListWnd.ReplayListCtrl");

	if( index >= 0 )
	{
		record = class'UIAPI_LISTCTRL'.static.GetRecord("ReplayListWnd.ReplayListCtrl", index);
		strFileName=record.LVDataList[1].szData;
	}

	return strFileName;
}

function OnDBClickListCtrlRecord( string ListCtrlID)
{
	OnOK();
}


function OnClickButton(string strID)
{
	switch(strID)
	{
	case "btnOK" :
		OnOK();
		break;
	case "btnDel" :
		OnDelete();
		InitReplayList();
		break;
	case "btnCancel" :
		SetUIState("LoginState");
		break;
	}
}

function OnOK()
{
	local string strFileName;
	local bool bLoadCameraInst;
	local bool bLoadChatData;
	
	strFileName=GetSelectedFileName();

	if(strFileName=="")
		return;

	bLoadCameraInst=class'UIAPI_CHECKBOX'.static.IsChecked("ReplayListWnd.chkLoadCamInst");
	bLoadChatData=class'UIAPI_CHECKBOX'.static.IsChecked("ReplayListWnd.chkLoadChatData");

	BeginReplay(strFileName, bLoadCameraInst, bLoadChatData);
}

function OnDelete()
{
	local string strFileName;

	strFileName=GetSelectedFileName();

	if(strFileName=="")
		return;

	EraseReplayFile(REPLAY_DIR$"\\"$strFileName$""$REPLAY_EXTENSION);
}

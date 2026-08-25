class PrivateShopWnd extends UICommonAPI;

const DIALOG_TOP_TO_BOTTOM = 111;
const DIALOG_BOTTOM_TO_TOP = 222;
const DIALOG_ASK_PRICE	= 333;
const DIALOG_CONFIRM_PRICE = 444;
const DIALOG_EDIT_SHOP_MESSAGE = 555;			// 메시지 편집
const DIALOG_CONFIRM_PRICE_FINAL = 666;			// 확인 버튼 눌렀을때 마지막 확인
//const DIALOG_OVER_PRICE = 777;				// 설정 가격이 20억이 넘을경우 에러 메세지	//특별히 아이디를 할당할 필요는 없어보인다. 

enum PrivateShopType
{
	PT_None,			// dummy
	PT_Buy,				// 다른 사람의 개인 상점에서 물건을 구매할 때
	PT_Sell,			// 다른 사람의 개인 상점에서 물건을 판매할 때
	PT_BuyList,			// 자신의 개인 상점 구매 리스트
	PT_SellList,		// 자신의 개인 상점 판매 리스트
};

var int				m_merchantID;
var PrivateShopType m_type;
var int				m_buyMaxCount;
var int				m_sellMaxCount;
var bool			m_bBulk;			// 일괄 구매인지 나타냄. PT_Buy일 경우에만 의미가 있다.

function OnLoad()
{
	registerEvent( EV_PrivateShopOpenWindow );
	registerEvent( EV_PrivateShopAddItem );
	registerEvent( EV_SetMaxCount );
	registerEvent( EV_DialogOK );

	m_merchantID = 0;
	m_buyMaxCount = 0;
	m_sellMaxCount = 0;
}

function OnSendPacketWhenHiding()
{
	RequestQuit();
}

function OnHide()
{
	local DialogBox DialogBox;
	DialogBox = DialogBox(GetScript("DialogBox"));
	if (class'UIAPI_WINDOW'.static.IsShowWindow("DialogBox"))
	{
		DialogBox.HandleCancel();
	}
	Clear();
}

function OnEvent(int Event_ID,string param)
{
	//debug("PrivateShopWnd OnEvent " $ param);
	switch( Event_ID )
	{
	case EV_PrivateShopOpenWindow:
		HandleOpenWindow(param);
		break;
	case EV_PrivateShopAddItem:
		HandleAddItem(param);
		break;
	case EV_SetMaxCount:
		HandleSetMaxCount(param);
		break;
	case EV_DialogOK:
		HandleDialogOK();
		break;
	default:
		break;
	}
}

function OnClickButton( string ControlName )
{
	local int index;
	//debug("OnClickButton " $ ControlName );
	if( ControlName == "UpButton" )
	{
		index = class'UIAPI_ITEMWINDOW'.static.GetSelectedNum( "PrivateShopWnd.BottomList" );
		MoveItemBottomToTop( index, false );
	}
	else if( ControlName == "DownButton" )
	{
		index = class'UIAPI_ITEMWINDOW'.static.GetSelectedNum( "PrivateShopWnd.TopList" );
		MoveItemTopToBottom( index, false );
	}
	else if( ControlName == "OKButton" )
	{
		HandleOKButton( true );
	}
	else if( ControlName == "StopButton" )
	{
		RequestQuit();
		HideWindow("PrivateShopWnd");
	}
	else if( ControlName == "MessageButton" )
	{
		DialogSetEditBoxMaxLength(29);	//글자 25자 제한! 원래 25자 제한이었는데 진정이 폭주하여 29자로 늘림
		DialogSetID( DIALOG_EDIT_SHOP_MESSAGE  );
		if( m_type == PT_SellList )
			DialogSetString( GetPrivateShopMessage("sell") );
		else if( m_type == PT_BuyList )
			DialogSetString( GetPrivateShopMessage("buy") );

		DialogSetDefaultOK();	
		DialogShow( DIALOG_OKCancelInput, GetSystemMessage( 334 ) );
	}
}

function OnDBClickItem( string ControlName, int index )
{
	if(ControlName == "TopList")
	{
		MoveItemTopToBottom( index, false );
	}
	else if(ControlName == "BottomList")
	{
		MoveItemBottomToTop( index, false );
	}

}

// 아이템을 클릭하였을 경우 (더블클릭 아님)
function OnClickItem( string ControlName, int index )
{
	local WindowHandle m_dialogWnd;
	m_dialogWnd = GetHandle( "DialogBox" );		
	if(ControlName == "TopList")
	{
		if( DialogIsMine() && m_dialogWnd.IsShowWindow())
		{
			DialogHide();
			m_dialogWnd.HideWindow();
		}		
	}
}

function OnDropItem( string strID, ItemInfo info, int x, int y)
{
	local int index;
	//debug("OnDropItem strID " $ strID $ ", src=" $ info.DragSrcName);
	index = -1;
	if( strID == "TopList" && info.DragSrcName == "BottomList" )
	{
		if( m_type == PT_Buy || m_type == PT_SellList  )
			index = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", info.ServerID );
		else if( m_type == PT_Sell || m_type == PT_BuyList )
			index = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.BottomList", info.ClassID );
		if( index >= 0 )
			MoveItemBottomToTop( index, info.AllItemCount > 0 );
	}
	else if( strID == "BottomList" && info.DragSrcName == "TopList" )
	{
		if( m_type == PT_Buy || m_type == PT_SellList  )
			index = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", info.ServerID );
		else if( m_type == PT_Sell || m_type == PT_BuyList )
			index = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", info.ClassID );
		if( index >= 0 )
			MoveItemTopToBottom( index, info.AllItemCount > 0 );
	}
}

function Clear()
{
	m_type = PT_None;
	m_merchantID = -1;
	m_bBulk = false;

	class'UIAPI_ITEMWINDOW'.static.Clear("PrivateShopWnd.TopList");
	class'UIAPI_ITEMWINDOW'.static.Clear("PrivateShopWnd.BottomList");

	class'UIAPI_TEXTBOX'.static.SetText("PrivateShopWnd.PriceText", "0");
	class'UIAPI_TEXTBOX'.static.SetTooltipString("PrivateShopWnd.PriceText", "");

	class'UIAPI_TEXTBOX'.static.SetText("PrivateShopWnd.AdenaText", "0");
	class'UIAPI_TEXTBOX'.static.SetTooltipString("PrivateShopWnd.AdenaText", "");
}

function RequestQuit()
{
	if( m_type == PT_BuyList )
	{
		RequestQuitPrivateShop("buy");
	}
	else if( m_type == PT_SellList )
	{
		RequestQuitPrivateShop("sell");
	}
}

function MoveItemTopToBottom( int index, bool bAllItem )
{
	local ItemInfo info, bottomInfo;
	local int		num, i, bottomIndex;

	if( class'UIAPI_ITEMWINDOW'.static.GetItem("PrivateShopWnd.TopList", index, info) )
	{
		//debug( "MoveItemTopToBottom index:" $ index $ ", m_type: " $ m_type $ ", classID:" $ info.ClassID $ ", count:" $info.ItemNum );

		if( m_type == PT_SellList )
		{
			// Ask price
			DialogSetID( DIALOG_ASK_PRICE );
			DialogSetReservedInt( info.ServerID );
			DialogSetReservedInt3( int(bAllItem) );			// 전체이동이면 개수 묻는 단계를 생략한다
			DialogSetEditType("number");
			DialogSetParamInt( -1 );
			DialogSetDefaultOK();
			DialogShow( DIALOG_NumberPad, GetSystemMessage(322) );
		}
		else if( m_type == PT_BuyList )
		{
			// Ask price
			DialogSetID( DIALOG_ASK_PRICE );
			DialogSetReservedInt( info.ClassID );
			//if(IsStackableItem( info.ConsumeType ))
				//DialogSetReservedInt3( int(bAllItem) );			// 전체이동이면 개수 묻는 단계를 생략한다
			DialogSetEditType("number");
			DialogSetParamInt( -1 );
			DialogSetDefaultOK();	
			DialogShow( DIALOG_NumberPad, GetSystemMessage(585) );
		}
		else if( m_type == PT_Sell || m_type == PT_Buy )
		{
			if( m_type == PT_Sell && info.bDisabled )			// 상대방의 개인 구매이고 팔 물건이 없을 때 그냥 리턴
				return;

			if( m_type == PT_Buy && m_bBulk )					// 상대방이 일괄 구매 일 경우. 모든 아이템을 이동시켜야 한다.
			{
				num = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "PrivateShopWnd.TopList" );
				for( i=0 ; i<num ; ++i )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem("PrivateShopWnd.TopList", i, info); 
					class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", info );
				}
				class'UIAPI_ITEMWINDOW'.static.Clear( "PrivateShopWnd.TopList" );
		
				AdjustPrice();
				AdjustCount();
			}
			else
			{
				if( !bAllItem && IsStackableItem( info.ConsumeType ) && info.ItemNum > 1 )		// 개수 물어보기
				{
					DialogSetID( DIALOG_TOP_TO_BOTTOM );
					if( m_type == PT_Sell )
						DialogSetReservedInt( info.ClassID );
					else if( m_type == PT_Buy )
						DialogSetReservedInt( info.ServerID );
					DialogSetParamInt( info.ItemNum );
					DialogSetDefaultOK();	
					DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(72), info.Name, "" ) );
				}
				else
				{
					if( m_type == PT_Buy )
						bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", info.ServerID );
					else if( m_type == PT_Sell )
						bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.BottomList", info.ClassID );

					if( bottomIndex >= 0 && IsStackableItem( info.ConsumeType ) )			// 아래쪽에 이미 있는 아이템이고 수량성 아이템이라면 개수만 더해준다.
					{
						class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
						bottomInfo.ItemNum += info.ItemNum;
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					}
					else
					{
						class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", info );
					}
					class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.TopList", index );

					AdjustPrice();
					AdjustCount();
				}
			}

			if( m_type == PT_Buy )
				AdjustWeight();
		}
	}
}

function MoveItemBottomToTop( int index, bool bAllItem )
{
	local ItemInfo info, topInfo;
	local int		stringIndex, num, i, topIndex;
	if( class'UIAPI_ITEMWINDOW'.static.GetItem("PrivateShopWnd.BottomList", index, info) )
	{
		if( m_type == PT_Buy && m_bBulk )		// 상대방이 일괄 구매 일 경우. 모든 아이템을 이동시켜야 한다.
		{
			num = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "PrivateShopWnd.BottomList" );
			for( i=0 ; i<num ; ++i )
			{
				class'UIAPI_ITEMWINDOW'.static.GetItem("PrivateShopWnd.BottomList", i, info); 
				class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.TopList", info );
			}
			class'UIAPI_ITEMWINDOW'.static.Clear( "PrivateShopWnd.BottomList" );

			AdjustPrice();
			AdjustCount();
		}
		else	// 개인 구매를 여는 사람일 경우 다른 처리가 필요할 듯 하오
		{
			if( !bAllItem && IsStackableItem( info.ConsumeType ) && info.ItemNum > 1 )		// 몇개 옮길건지 물어본다
			{
				//debug("MoveItemBottomToTop m_type " $ m_type );
				DialogSetID( DIALOG_BOTTOM_TO_TOP );
				if( m_type == PT_Buy || m_type == PT_SellList )
					DialogSetReservedInt( info.ServerID );
				else if( m_type == PT_Sell || m_type == PT_BuyList )
					DialogSetReservedInt( info.ClassID );

				DialogSetParamInt( info.ItemNum );
				switch( m_type )
				{
				case PT_SellList:
					stringIndex = 72;
					break;
				case PT_BuyList:
					stringIndex = 571;
					break;
				case PT_Sell:
					stringIndex = 72;
					break;
				case PT_Buy:
					stringIndex = 72;
					break;
				default:
					break;
				}
				DialogSetDefaultOK();	
				DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(stringIndex), info.Name, "" ) );
			}
			else
			{
				class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.BottomList", index );
				if( m_type != PT_BuyList )
				{
					if( m_type == PT_Buy || m_type == PT_SellList )
						topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", info.ServerID );
					else if( m_type == PT_Sell )
						topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", info.ClassID );

					if( topIndex >=0 && IsStackableItem( info.ConsumeType ) )		// 수량성 아이템이면 개수만 업데이트
					{
						class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
						topInfo.ItemNum += info.ItemNum;
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					}
					else
					{
						class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.TopList", info );
					}
				}
				AdjustPrice();
				AdjustCount();
			}
		}
		if( m_type == PT_Buy )
			AdjustWeight();
	}
}

function HandleDialogOK()
{
	local int id, inputNum, itemID, bottomIndex, topIndex, i, allItem;
	local ItemInfo bottomInfo, topInfo;

	if( DialogIsMine() )
	{
		id = DialogGetID();
	
		inputNum = int( DialogGetString() );
		itemID = DialogGetReservedInt();
		//debug("PrivateShopWnd DialogOK id:" $ id $ ", string:" $ inputNum $ ", reservedInt:" $ classID $ ", reservedInt2:" $ DialogGetReservedInt2() );

		// 다이얼로그는 차례대로 가격 결정(DIALOG_ASK_PRICE)->가격이 기본 가격과 차이가 날 경우 가격 확인(DIALOG_CONFIRM_PRICE)->아이템이동(DIALOG_TOP_TO_BOTTOM)의 순서대로 사용된다
		// PT_SellList와 PT_BuyList는 기본적으로 동일하다.
		if( m_type == PT_SellList )
		{
			if( id == DIALOG_TOP_TO_BOTTOM && inputNum > 0 )					// 개수대로 아이템을 옮긴다.
			{
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", itemID );
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					if( bottomIndex >= 0 && IsStackableItem( bottomInfo.ConsumeType ) )			// 아래쪽에 이미 있는 아이템이고 수량성 아이템이라면 가격을 엎어쓰고 개수는 더해준다.
					{
						bottomInfo.Price = DialogGetReservedInt2();
						bottomInfo.ItemNum += Min( inputNum, topInfo.ItemNum );
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					}
					else					// 새로운 아이템을 넣는다
					{
						bottomInfo = topInfo;
						bottomInfo.ItemNum = Min( inputNum, topInfo.ItemNum );
						bottomInfo.Price = DialogGetReservedInt2();
						class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", bottomInfo );
					}

					// 위쪽 아이템의 처리
					topInfo.ItemNum -= inputNum;
					if( topInfo.ItemNum <= 0 )
						class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.TopList", topIndex );
					else
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
				}
				AdjustPrice();
				AdjustCount();
			}
			else if( id == DIALOG_BOTTOM_TO_TOP && inputNum > 0 )		// 아래쪽 것을 빼서 위로 옮겨준다.
			{
				bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", itemID );
				//debug("DIALOG_BOTTOM_TO_TOP bottomIndex " $ bottomIndex $ ", itemID " $ itemID );
				if( bottomIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );

					topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
					if( topIndex >=0 && IsStackableItem( bottomInfo.ConsumeType ) )
					{
						class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
						topInfo.ItemNum += Min( inputNum, bottomInfo.ItemNum );
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					}
					else
					{
						topInfo = bottomInfo;
						topInfo.ItemNum = Min( inputNum, bottomInfo.ItemNum );
						class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.TopList", topInfo );
					}

					bottomInfo.ItemNum -= inputNum;
					if( bottomInfo.ItemNum > 0 )
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					else 
						class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.BottomList", bottomIndex );
				}
				AdjustPrice();
				AdjustCount();
			}
			else if( ID == DIALOG_CONFIRM_PRICE )
			{
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					allItem = DialogGetReservedInt3();

					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					if( allItem == 0 && IsStackableItem( topInfo.ConsumeType ) && topInfo.ItemNum != 1)		// stackable?	1개일때는 갯수를 묻지 않습니다. -innowind
					{
						DialogSetID( DIALOG_TOP_TO_BOTTOM );
						//DialogSetReservedInt( topInfo.ClassID );
						//DialogSetReservedInt2( inputNum );				// price
						if(topInfo.ItemNum  == 0) topInfo.ItemNum  = 1;	//갯수를 입력하지 않았다면 1을 셋팅해준다. 
						DialogSetParamInt( topInfo.ItemNum );
						DialogSetDefaultOK();	
						DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(72), topInfo.Name, "" ) );
					}
					else
					{
						if( allItem == 0 )
							topInfo.ItemNum = 1;
						topInfo.Price = DialogGetReservedInt2();
						bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", topInfo.ServerID );
						if( bottomIndex >= 0 && IsStackableItem( topInfo.ConsumeType ) )
						{
							class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );		// 합체!-_-
							topInfo.ItemNum += bottomInfo.ItemNum;
							class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, topInfo );
						}
						else
						{
							class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", topInfo );
						}
						class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.TopList", topIndex );

						AdjustPrice();
						AdjustCount();
					}
				}
			}
			else if( id == DIALOG_ASK_PRICE && inputNum > 0 )
			{
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					//debug("DIALOG_ASK_PRICE defaultPrice : " $ topInfo.DefaultPrice $ ", entered price: " $ inputNum );
					// if specified price is unconventional, ask confirm
					if( inputNum >= 2000000000 )	//20억이 넘으면 수량 초과 에러를 뿌려준다. 
					{
						//DialogSetID( DIALOG_OVER_PRICE );
						DialogShow( DIALOG_Notice, GetSystemMessage(1369) );					
					}
					else if( !IsProperPrice( topInfo, inputNum ) )
					{
						//debug("strange price warning");
						DialogSetID( DIALOG_CONFIRM_PRICE );
						DialogSetReservedInt( topInfo.ServerID );
						DialogSetReservedInt2( inputNum );				// price
						DialogSetDefaultOK();	
						DialogShow( DIALOG_Warning, GetSystemMessage(569) );
					}
					else
					{
						allItem = DialogGetReservedInt3();

						if( allItem == 0 && IsStackableItem( topInfo.ConsumeType ) )		// stackable?
						{
							//debug("stackable item");
							DialogSetID( DIALOG_TOP_TO_BOTTOM );
							DialogSetReservedInt( topInfo.ServerID );
							DialogSetReservedInt2( inputNum );				// price
							DialogSetReservedInt3( allItem );
							DialogSetParamInt( topInfo.ItemNum );
							DialogSetDefaultOK();	
							DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(72), topInfo.Name, "" ) );
						}
						else
						{
							//debug("nonstackable item");
							if( allItem == 0 )
								topInfo.ItemNum = 1;
							topInfo.Price = inputNum;
							bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", topInfo.ServerID );
							if( bottomIndex >= 0 && IsStackableItem( topInfo.ConsumeType ) )
							{
								class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );		// 합체!-_-
								topInfo.ItemNum += bottomInfo.ItemNum;
								class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, topInfo );
							}
							else
							{
								class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", topInfo );
							}
							class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.TopList", topIndex );

							AdjustPrice();
							AdjustCount();
						}
					}
				}
			}
			else if( id == DIALOG_EDIT_SHOP_MESSAGE )
			{
				SetPrivateShopMessage( "sell", DialogGetString() );
			}
		}
		// PT_BuyList
		else if( m_type == PT_BuyList )
		{
			if( id == DIALOG_TOP_TO_BOTTOM && inputNum > 0 )					// 개수대로 아이템을 옮긴다.
			{
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.BottomList", itemID );
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					if( bottomIndex >= 0 && IsStackableItem( bottomInfo.ConsumeType ) )			// 아래쪽에 이미 있는 아이템이고 수량성 아이템이라면 가격을 엎어쓰고 개수는 더해준다.
					{
						//debug("BuyList StackableItem addnum:" $ inputNum $ ", set price to : " $ DialogGetReservedInt2());
						bottomInfo.Price = DialogGetReservedInt2();
						bottomInfo.ItemNum += inputNum;
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );

						return;		// 이걸로 끝.
					}

					if( bottomIndex >= 0 )					
					{	// 중복되는 아이템을 모두 지운다.
						i = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "PrivateShopWnd.BottomList" );
						//debug("BuyList Removing Items");
						while( i >= 0 )
						{
							class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", i, bottomInfo );
							if( bottomInfo.ClassID == itemID )
								class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.BottomList", i );
							--i;
						};
					}

					if( IsStackableItem( topInfo.ConsumeType ) )
					{
						//debug("BuyList Add stackable Item");
						bottomInfo = topInfo;
						bottomInfo.ItemNum = inputNum;
						bottomInfo.Price = DialogGetReservedInt2();
						class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", bottomInfo );
					}
					else
					{
						//debug("BuyList Add non-stackable Item");
						// 새로운 아이템을 개수만큼 넣는다
						bottomInfo = topInfo;
						bottomInfo.ItemNum = 1;
						bottomInfo.Price = DialogGetReservedInt2();
						for( i=0 ; i < inputNum ; ++i )
						{
							class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", bottomInfo );
						}
					}
				}
				AdjustPrice();
				AdjustCount();
			}
			else if( id == DIALOG_BOTTOM_TO_TOP && inputNum > 0 )		// 아래쪽 것을 빼버린다.
			{
				bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.BottomList", itemID );
				if( bottomIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					bottomInfo.ItemNum -= inputNum;
					if( bottomInfo.ItemNum > 0 )
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					else 
						class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.BottomList", bottomIndex );
				}
			}
			else if( ID == DIALOG_CONFIRM_PRICE )			// 몇개 구입할 것인지 묻는다.
			{
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );

					DialogSetID( DIALOG_TOP_TO_BOTTOM );
					DialogSetReservedInt( topInfo.ClassID );
					//DialogSetReservedInt2( inputNum );				// price
					DialogSetParamInt( topInfo.ItemNum );
					DialogSetDefaultOK();	
					DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(570), topInfo.Name, "" ) );
				}
				AdjustPrice();
				AdjustCount();
				
				
				//개인구매에도 개인판매에 있는것을 긁어왔사옵니다. -_-;;
				/*
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					allItem = DialogGetReservedInt3();

					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					if( allItem == 0 && IsStackableItem( topInfo.ConsumeType ) )		// stackable?
					{
						DialogSetID( DIALOG_TOP_TO_BOTTOM );
						if(topInfo.ItemNum  == 0) topInfo.ItemNum  = 1;	//갯수를 입력하지 않았다면 1을 셋팅해준다. 
						DialogSetParamInt( topInfo.ItemNum );
						DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(570), topInfo.Name, "" ) );
					}
					else
					{
						if( allItem == 0 )
							topInfo.ItemNum = 1;
						topInfo.Price = DialogGetReservedInt2();
						bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", topInfo.ServerID );
						if( bottomIndex >= 0 && IsStackableItem( topInfo.ConsumeType ) )
						{
							class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );		// 합체!-_-
							topInfo.ItemNum += bottomInfo.ItemNum;
							class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, topInfo );
						}
						else
						{
							class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", topInfo );
						}
						//class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.TopList", topIndex ); //구매에서는 위에것을 삭제할 필요가 없다. 

						AdjustPrice();
						AdjustCount();
					}
				}
				*/
			}
			else if( id == DIALOG_ASK_PRICE && inputNum > 0 )
			{
				topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", itemID );
				if( topIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					// if specified price is unconventional, ask confirm
					if( inputNum >= 2000000000 )	//20억이 넘으면 수량 초과 에러를 뿌려준다. 
					{
						//DialogSetID( DIALOG_OVER_PRICE );
						DialogShow( DIALOG_Notice, GetSystemMessage(1369) );					
					}
					else if( !IsProperPrice( topInfo, inputNum ) )
					{
						DialogSetID( DIALOG_CONFIRM_PRICE );
						DialogSetReservedInt( topInfo.ClassID );
						DialogSetReservedInt2( inputNum );				// price
						DialogSetDefaultOK();	
						DialogShow( DIALOG_Warning, GetSystemMessage(569) );
					}
					else
					{
						DialogSetID( DIALOG_TOP_TO_BOTTOM );
						DialogSetReservedInt( topInfo.ClassID );
						DialogSetReservedInt2( inputNum );				// price
						DialogSetParamInt( topInfo.ItemNum );
						DialogSetDefaultOK();	
						DialogShow( DIALOG_NumberPad, MakeFullSystemMsg( GetSystemMessage(570), topInfo.Name, "" ) );
					}
				}
			}
			else if( id == DIALOG_EDIT_SHOP_MESSAGE )
			{
				SetPrivateShopMessage( "buy", DialogGetString() );
			}
		}
		// PT_Buy and PT_Buy
		else if( m_type == PT_Buy || m_type == PT_Sell )
		{
			if( id == DIALOG_TOP_TO_BOTTOM && inputNum > 0 )		// 이 다이얼로그가 불렸다는 것은 수량성 아이템이라는 것을 의미한다.(아니었으면 MoveItemTopToBottom() 함수에서 이미 아이템 이동을 처리했을 것이다)
			{
				topIndex = -1;
				if( m_type == PT_Buy )
					topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
				else if( m_type == PT_Sell )
					topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", itemID );

				if( topIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					
					if(m_type == PT_Sell  && topInfo.Reserved < inputNum)	//사려는 양보다 입력한 수가 많다면 팝업을 띄우고 만다. 
					{
						DialogShow( DIALOG_Notice, GetSystemMessage(1036) );
					}
					else
					{
						if( m_type == PT_Buy )
							bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", itemID );
						else if( m_type == PT_Sell )
							bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.BottomList", itemID );

						class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
						if( bottomIndex >= 0  )			// 수량성 아이템 중복
						{
							bottomInfo.ItemNum += Min( inputNum, topInfo.ItemNum );		// 개수만 더해준다
							class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
						}
						else					// 새로운 아이템을 넣는다
						{
							bottomInfo = topInfo;
							bottomInfo.ItemNum = Min( inputNum, topInfo.ItemNum );
							class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", bottomInfo );
						}
	
						// 위쪽 아이템의 처리
						topInfo.ItemNum -= inputNum;
						if( topInfo.ItemNum <= 0 )
							class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.TopList", topIndex );
						else
							class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					}
				}
				AdjustPrice();
				AdjustCount();
			}
			else if( id == DIALOG_BOTTOM_TO_TOP && inputNum > 0 )		// 아래쪽 것을 빼서 위로 옮겨준다. 마찬가지로 이 다이얼로그가 불렸다는 것은 수량성 아이템임을 의미.
			{
				bottomIndex = -1;
				if( m_type == PT_Buy )
					bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.BottomList", itemID );
				else if( m_type == PT_Sell )
					bottomIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.BottomList", itemID );

				if( bottomIndex >= 0 )
				{
					class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );

					topIndex = -1;
					// 위쪽에 더해지는 수량
					if( m_type == PT_Buy )
						topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithServerID( "PrivateShopWnd.TopList", itemID );
					else if( m_type == PT_Sell )
						topIndex = class'UIAPI_ITEMWINDOW'.static.FindItemWithClassID( "PrivateShopWnd.TopList", itemID );

					if( topIndex >=0 )
					{
						class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
						topInfo.ItemNum += Min( inputNum, bottomInfo.ItemNum );
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.TopList", topIndex, topInfo );
					}
					else
					{
						topInfo = bottomInfo;
						topInfo.ItemNum = Min( inputNum, bottomInfo.ItemNum );
						class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.TopList", topInfo );
					}

					// 아래쪽의 수량을 조절해 준다.
					bottomInfo.ItemNum -= inputNum;
					if( bottomInfo.ItemNum > 0 )
						class'UIAPI_ITEMWINDOW'.static.SetItem( "PrivateShopWnd.BottomList", bottomIndex, bottomInfo );
					else 
						class'UIAPI_ITEMWINDOW'.static.DeleteItem( "PrivateShopWnd.BottomList", bottomIndex );
				}
				AdjustPrice();
				AdjustCount();
			}
			else if( id == DIALOG_CONFIRM_PRICE_FINAL)
			{
				HandleOKButton( false );
			}

			if( m_type == PT_Buy )
				AdjustWeight();
		}
	}
}
//
function HandleOpenWindow( string param )
{
	local string type;
	local int adena,bulk;
	local string adenaString;
	local UserInfo	user;
	local WindowHandle m_inventoryWnd;
	
	m_inventoryWnd = GetHandle( "InventoryWnd" );	//인벤토리의 윈도우 핸들을 얻어온다.

	Clear();

	ParseString( param, "type", type );
	ParseInt( param, "adena", adena );
	ParseInt( param, "userID", m_merchantID );
	ParseInt( param, "bulk", bulk );			// 일괄 판매(구매)?
	if( bulk > 0 )
		m_bBulk = true;
	else
		m_bBulk = false;

	switch( type )
	{
	case "buy":
		m_type = PT_Buy;
		//class'UIAPI_WINDOW'.static.SetWindowTitle("PrivateShopWnd", 1216);
		break;
	case "sell":
		m_type = PT_Sell;
		//class'UIAPI_WINDOW'.static.SetWindowTitle("PrivateShopWnd", 1217);
		break;
	case "buyList":
		m_type = PT_BuyList;
		//class'UIAPI_WINDOW'.static.SetWindowTitle("PrivateShopWnd", 1218);
		break;
	case "sellList":
		m_type = PT_SellList;
		//class'UIAPI_WINDOW'.static.SetWindowTitle("PrivateShopWnd", 131);
		break;
	default:
		break;
	};

	adenaString = MakeCostString( string(adena) );
	class'UIAPI_TEXTBOX'.static.SetText("PrivateShopWnd.AdenaText", adenaString);
	class'UIAPI_TEXTBOX'.static.SetTooltipString("PrivateShopWnd.AdenaText", ConvertNumToText(string(adena)) );

	if( m_inventoryWnd.IsShowWindow() )			//인벤토리 창이 열려있으면 닫아준다. 
	{
		m_inventoryWnd.HideWindow();
	}
	ShowWindow( "PrivateShopWnd" );
	class'UIAPI_WINDOW'.static.SetFocus("PrivateShopWnd");

	if( m_type == PT_BuyList )
	{
		// set tooltip
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.TopList", "Inventory" );
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.BottomList", "InventoryPrice1" );

		// Set strings
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.TopText", GetSystemString(1) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.BottomText", GetSystemString(502) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.PriceConstText", GetSystemString(142) );
		class'UIAPI_BUTTON'.static.SetButtonName( "PrivateShopWnd.OKButton", 428 );

		ShowWindow( "PrivateShopWnd.BottomCountText" );
		ShowWindow( "PrivateShopWnd.StopButton" );
		Showwindow( "PrivateShopWnd.MessageButton" );
		ShowWindow( "PrivateShopWnd.OKButton" );
		HideWindow( "PrivateShopWnd.CheckBulk" );

		class'UIAPI_WINDOW'.static.SetWindowTitleByText( "PrivateShopWnd", GetSystemString(498) $ "(" $ GetSystemString(1434) $ ")" );
	}
	else if( m_type == PT_SellList )
	{
		// set tooltip
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.TopList", "Inventory" );
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.BottomList", "InventoryPrice1" );

		if( bulk > 0 )
			class'UIAPI_CHECKBOX'.static.SetCheck( "PrivateShopWnd.CheckBulk", true );
		else
			class'UIAPI_CHECKBOX'.static.SetCheck( "PrivateShopWnd.CheckBulk", false );

		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.TopText", GetSystemString(1) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.BottomText", GetSystemString(137) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.PriceConstText", GetSystemString(143) );
		class'UIAPI_BUTTON'.static.SetButtonName( "PrivateShopWnd.OKButton", 428 );

		ShowWindow( "PrivateShopWnd.BottomCountText" );
		ShowWindow( "PrivateShopWnd.StopButton" );
		Showwindow( "PrivateShopWnd.MessageButton" );
		ShowWindow( "PrivateShopWnd.OKButton" );
		ShowWindow( "PrivateShopWnd.CheckBulk" );

		class'UIAPI_WINDOW'.static.SetWindowTitleByText( "PrivateShopWnd", GetSystemString(498) $ "(" $ GetSystemString(1157) $ ")" );
	}
	else if( m_type == PT_Buy )
	{
		// set tooltip
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.TopList", "InventoryPrice1" );
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.BottomList", "Inventory" );

		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.TopText", GetSystemString(137) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.BottomText", GetSystemString(139) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.PriceConstText", GetSystemString(142) );
		class'UIAPI_BUTTON'.static.SetButtonName( "PrivateShopWnd.OKButton", 140 );

		HideWindow( "PrivateShopWnd.BottomCountText" );
		HideWindow( "PrivateShopWnd.StopButton" );
		HideWindow( "PrivateShopWnd.MessageButton" );
		ShowWindow( "PrivateShopWnd.OKButton" );
		HideWindow( "PrivateShopWnd.CheckBulk" );

		GetUserInfo( m_merchantID, user );
		if( bulk > 0 )
			class'UIAPI_WINDOW'.static.SetWindowTitleByText( "PrivateShopWnd", GetSystemString(498) $ "(" $ GetSystemString(1198) $ ") - " $ user.Name );
		else
			class'UIAPI_WINDOW'.static.SetWindowTitleByText( "PrivateShopWnd", GetSystemString(498) $ "(" $ GetSystemString(1157) $ ") - " $ user.Name );
	}
	else if( m_type == PT_Sell )
	{
		// set tooltip
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.TopList", "InventoryPrice2PrivateShop" );	// TTS_INVENTORY|TTS_PRIVATE_BUY(2050),TTES_SHOW_PRICE2(8)
		class'UIAPI_WINDOW'.static.SetTooltipType( "PrivateShopWnd.BottomList", "Inventory" );

		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.TopText", GetSystemString(503) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.BottomText", GetSystemString(137) );
		class'UIAPI_TEXTBOX'.static.SetText( "PrivateShopWnd.PriceConstText", GetSystemString(143) );
		class'UIAPI_BUTTON'.static.SetButtonName( "PrivateShopWnd.OKButton", 140 );

		HideWindow( "PrivateShopWnd.BottomCountText" );
		HideWindow( "PrivateShopWnd.StopButton" );
		HideWindow( "PrivateShopWnd.MessageButton" );
		ShowWindow( "PrivateShopWnd.OKButton" );
		HideWindow( "PrivateShopWnd.CheckBulk" );

		GetUserInfo( m_merchantID, user );
		class'UIAPI_WINDOW'.static.SetWindowTitleByText( "PrivateShopWnd", GetSystemString(498) $ "(" $ GetSystemString(1434) $ ") - " $ user.Name );
	}
}

function HandleAddItem( string param )
{
	local ItemInfo info;
	local string target;
	ParseString( param, "target", target );
	ParamToItemInfo( param, info );
	if( target == "topList" )
	{
		if( m_type == PT_Sell && info.ItemNum == 0 )
			info.bDisabled = true;
		class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.TopList", info );
	}
	else if( target == "bottomList" )
	{
		class'UIAPI_ITEMWINDOW'.static.AddItem( "PrivateShopWnd.BottomList", info );
	}
	AdjustPrice();
	AdjustCount();
}
//
function AdjustPrice()
{
	local string adena;
	local int count;
	//local int addPrice;
	local int64 price;		//오버플로우시 음수값을 없애주기 위해 수정하였습니다. - innowind
	local int64 addPrice64;		
	local ItemInfo info;

	count = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "PrivateShopWnd.BottomList" );
	price = Int2Int64(0);	
	addPrice64 = Int2Int64(0);	
	
	while( count > 0 )
	{		// 아래쪽에 있는 물건들의 가격을 다 더해준다.
		class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", count - 1, info );
		//addPrice = info.Price * info.ItemNum;	//여기서 오버플로우가 나면 마찬가지다. 곱하는 함수 필
		addPrice64 = Int64Mul(info.Price, info.ItemNum );
		price = Int64Add( price , addPrice64 );	// Int64Add( price ,  Int64Add( price , addPrice64 ));  바로 집어넣으면 심각한 오류가 ;;
		//price += info.Price * info.ItemNum;

		--count;
	}
	
	if(price.nLeft <0 || price.nRight <0)	//기본적으로 음수가 될 일이 없기때문에, 음수가 되면 걍 0을 뿌려줍니다.
	{
		price = Int2Int64(0);	
	}
	adena = MakeCostStringInt64( price );
	class'UIAPI_TEXTBOX'.static.SetText("PrivateShopWnd.PriceText", adena);
	class'UIAPI_TEXTBOX'.static.SetTooltipString("PrivateShopWnd.PriceText", ConvertNumToText(MakeCostStringInt64( price )) );
}

function AdjustCount()
{
	local int num, maxNum;

	if( m_type == PT_SellList )
	{
		maxNum = m_sellMaxCount;
		num = class'UIAPI_ITEMWINDOW'.static.GetItemNum("PrivateShopWnd.BottomList");
		class'UIAPI_TEXTBOX'.static.SetText("PrivateShopWnd.BottomCountText", "(" $ string(num) $ "/" $ string(maxNum) $ ")");
		//debug("AdjustCount SellList num " $ num $ ", maxCount " $ maxNum );
	}
	else if( m_type == PT_BuyList )
	{
		maxNum = m_buyMaxCount;
		num = class'UIAPI_ITEMWINDOW'.static.GetItemNum("PrivateShopWnd.BottomList");
		class'UIAPI_TEXTBOX'.static.SetText("PrivateShopWnd.BottomCountText", "(" $ string(num) $ "/" $ string(maxNum) $ ")");
		//debug("AdjustCount BuyList num " $ num $ ", maxCount " $ maxNum );
	}
}

// 아래 리스트에 있는 물건들의 무게를 모두 합해서 InvenWeight 에 더해준다
function AdjustWeight()
{
	local int count, weight;
	local ItemInfo info;
	class'UIAPI_INVENWEIGHT'.static.ZeroWeight( "PrivateShopWnd.InvenWeight" );

	count = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "PrivateShopWnd.BottomList" );
	weight = 0;
	while( count > 0 )
	{		// 아래쪽에 있는 물건들의 무게를 다 더해준다.
		class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", count - 1, info );
		weight += info.Weight * info.ItemNum;

		--count;
	}

	class'UIAPI_INVENWEIGHT'.static.AddWeight( "PrivateShopWnd.InvenWeight", weight );
}

function HandleOKButton( bool bPriceCheck )		// bPriceCheck :check abnormal price before sending packet if bPriceCheck is true.
{
	local string	param;
	local int		itemCount, itemIndex;
	local ItemInfo	itemInfo;

	//debug("HandleOKButton m_type : " $ m_type );
	itemCount = class'UIAPI_ITEMWINDOW'.static.GetItemNum( "PrivateShopWnd.BottomList" );
	if( m_type == PT_SellList )
	{
		// push bulk mode
		if( class'UIAPI_CHECKBOX'.static.IsChecked( "PrivateShopWnd.CheckBulk" ) )
			ParamAdd( param, "bulk", "1" );
		else 
			ParamAdd( param, "bulk", "0" );

		// pack every item in BottomList
		ParamAdd( param, "num", string(itemCount) );
		for( itemIndex=0 ; itemIndex < itemCount; ++itemIndex )
		{
			class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", itemIndex, itemInfo );
			ParamAdd( param, "serverID" $ itemIndex, string(itemInfo.ServerID) );
			ParamAdd( param, "count" $ itemIndex, string(itemInfo.ItemNum) );
			ParamAdd( param, "price" $ itemIndex, string(itemInfo.Price) );
		}

		// Send packet
		SendPrivateShopList("sellList", param);
	}
	else if( m_type == PT_Buy )
	{
		// push merchantID(other user)
		ParamAdd( param, "merchantID", string(m_merchantID) );

		// pack every item in BottomList
		ParamAdd( param, "num", string(itemCount) );
		for( itemIndex=0 ; itemIndex < itemCount; ++itemIndex )
		{
			class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", itemIndex, itemInfo );
			if( bPriceCheck && !IsProperPrice( itemInfo, itemInfo.Price ) )
				break;
			ParamAdd( param, "serverID" $ itemIndex, string(itemInfo.ServerID) );
			ParamAdd( param, "count" $ itemIndex, string(itemInfo.ItemNum) );
			ParamAdd( param, "price" $ itemIndex, string(itemInfo.Price) );
		}

		if( bPriceCheck && ( itemIndex < itemCount ) )		// there's some problem about price...
		{
			DialogSetID( DIALOG_CONFIRM_PRICE_FINAL );
			DialogShow( DIALOG_Warning, GetSystemMessage(569) );
			return;
		}
		else					// send packet
		{
			SendPrivateShopList("buy", param);
		}
	}
	else if( m_type == PT_BuyList )
	{
		// pack every item in BottomList
		ParamAdd( param, "num", string(itemCount) );
		for( itemIndex=0 ; itemIndex < itemCount; ++itemIndex )
		{
			class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", itemIndex, itemInfo );
			ParamAdd( param, "classID" $ itemIndex, string(itemInfo.ClassID) );
			ParamAdd( param, "enchanted" $ itemIndex, string(itemInfo.Enchanted) );
			ParamAdd( param, "damaged" $ itemIndex, string(itemInfo.Damaged) );
			ParamAdd( param, "count" $ itemIndex, string(itemInfo.ItemNum) );
			ParamAdd( param, "price" $ itemIndex, string(itemInfo.Price) );
		}

		// Send packet
		SendPrivateShopList("buyList", param);
	}
	else if( m_type == PT_Sell )
	{
		// pack every item in BottomList
		ParamAdd( param, "merchantID", string(m_merchantID) );
		ParamAdd( param, "num", string(itemCount) );
		for( itemIndex=0 ; itemIndex < itemCount; ++itemIndex )
		{
			class'UIAPI_ITEMWINDOW'.static.GetItem( "PrivateShopWnd.BottomList", itemIndex, itemInfo );
			if( bPriceCheck && !IsProperPrice( itemInfo, itemInfo.Price ) )
				break;
			ParamAdd( param, "serverID" $ itemIndex, string(itemInfo.ServerID) );
			ParamAdd( param, "classID" $ itemIndex, string(itemInfo.ClassID) );
			ParamAdd( param, "enchanted" $ itemIndex, string(itemInfo.Enchanted) );
			ParamAdd( param, "damaged" $ itemIndex, string(itemInfo.Damaged) );
			ParamAdd( param, "count" $ itemIndex, string(itemInfo.ItemNum) );
			ParamAdd( param, "price" $ itemIndex, string(itemInfo.Price) );
		}

		if( bPriceCheck && ( itemIndex < itemCount ) )		// there's some problem about price...
		{
			DialogSetID( DIALOG_CONFIRM_PRICE_FINAL );
			DialogShow( DIALOG_Warning, GetSystemMessage(569) );
			return;
		}
		else					// send packet
		{
			SendPrivateShopList("sell", param);
		}
	}

	HideWindow("PrivateShopWnd");
	Clear();
}

function HandleSetMaxCount( string param )
{
	ParseInt( param, "privateShopSell", m_sellMaxCount );
	ParseInt( param, "privateShopBuy", m_buyMaxCount );
}

function bool IsProperPrice( out ItemInfo info, int price )
{
	if( info.DefaultPrice > 0 && ( price <= info.DefaultPrice / 5 || price >= info.DefaultPrice * 5 )  )
		return false;

	return true;
}

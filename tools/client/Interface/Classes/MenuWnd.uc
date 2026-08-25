class MenuWnd extends UICommonAPI;

function OnLoad()
{
}

function OnClickButton(string strID)
{
	switch(strID)
	{
	case "BtnCharInfo" :
		ToggleOpenCharInfoWnd();
		break;
	case "BtnInventory" :
		ToggleOpenInventoryWnd();
		break;
	case "BtnMap" :
		ToggleOpenMinimapWnd();
		break;
	case "BtnSystemMenu" :
		ToggleOpenSystemMenuWnd();
		break;
	}
}

function ToggleOpenCharInfoWnd()
{
	if(IsShowWindow("MainWnd"))
	{
		HideWindow("MainWnd");
		PlaySound("InterfaceSound.charstat_close_01");
	}
	else
	{
		ShowWindowWithFocus("MainWnd");
		PlaySound("InterfaceSound.charstat_open_01");			
	}
}

function ToggleOpenInventoryWnd()
{
	if(IsShowWindow("InventoryWnd"))
	{
		HideWindow("InventoryWnd");
		PlaySound("InterfaceSound.inventory_close_01");
	}
	else
	{
		ShowWindowWithFocus("InventoryWnd");
		PlaySound("InterfaceSound.inventory_open_01");
	}
}

function ToggleOpenMinimapWnd()
{
	RequestOpenMinimap();
}


function ToggleOpenSystemMenuWnd()
{
	if(IsShowWindow("SystemMenuWnd"))
	{
		HideWindow("SystemMenuWnd");
		PlaySound("InterfaceSound.system_close_01");
	}
	else
	{
		ShowWindowWithFocus("SystemMenuWnd");
		PlaySound("InterfaceSound.system_open_01");
	}
}

class UIAPI_TREECTRL extends UIAPI_WINDOW
	native;
	
native static function string InsertNode(string ControlName, string strParentName, XMLTreeNodeInfo infNode);
native static function InsertNodeItem(string ControlName, string NodeName, XMLTreeNodeItemInfo infNodeItem);
native static function Clear(string ControlName);
native static function SetExpandedNode(string ControlName, string NodeName, bool bExpanded);
native static function string GetExpandedNode(string ControlName, string NodeName);
native static function bool DeleteNode(string ControlName, string NodeName);
native static function bool IsNodeNameExist(string ControlName, string NodeName);
native static function bool IsExpandedNode(string ControlName, string NodeName);
native static function string GetChildNode(string ControlName, string NodeName);
native static function string GetParentNode(string ControlName, string NodeName);
native static function ShowScrollBar(string ControlName, bool bShow);
 
//For Text Item
native static function SetNodeItemText(string ControlName, string NodeName, int nTextID, string strText);

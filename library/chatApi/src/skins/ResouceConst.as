package skins
{
	import com.mui.core.GlobalClass;
	import com.mui.display.ScaleBitmap;
	
	import flash.display.BitmapData;
	import flash.geom.Rectangle;

	/**
	 * 静态资源 
	 * @author jianglang
	 * 
	 */	
	public class ResouceConst
	{
		
		public static var _scaleMap:Object = {
			WindowBg:new Rectangle(114,35,1,15),
			WindowCenterA:new Rectangle(7,7,45,64),
			WindowCenterB:new Rectangle(10,10,21,23),
			WindowCenterC:new Rectangle(10,10,21,23),
			DisabledBg:new Rectangle(12,12,21,16),
			InputBg:new Rectangle(10,8,29,9),
			ToolTipBg:new Rectangle(10,10,20,9),
			WindowPattern:new Rectangle(),
			PopUpMenuBg_pack:new Rectangle(20,25,40,70),
			PreperenBg:new Rectangle(54,50,8,20),
			Friend_over:new Rectangle(70,8,30,10),
			SplitLine:new Rectangle(63,0,1,2),
			KillUserLine:new Rectangle(150,1,5,0),
			VSpliteLine:new Rectangle(0,50,1,50),
			ProgressBarBg:new Rectangle(16,4,30,6),
			Shengmingtiao:new Rectangle(8,2,16,4),
			Mofatiao:new Rectangle(8,2,16,4),
			EnergyBar:new Rectangle(8,2,16,4),
			SelectedLineBox:new Rectangle(6,3,10,6),
			RbListHeader:new Rectangle(60,15,80,3),
			equipment_boarder:new Rectangle(25,24,1,1),
			WindowSelectedBg:new Rectangle(15,15,5,5),
			PackItemBg:new Rectangle(15,10,10,10),
			TileBg:new Rectangle(105,5,10,5),
			WindowBg2:new Rectangle(40,28,1,1),
			PackRightBg:new Rectangle(0,80,97,120),
			PopUpMenuOverSkin:new Rectangle(47,9,1,1),
			PetIlluNewBg:new Rectangle(40,42,20,5),
			SelectedBg:new Rectangle(40,10,32,23),
			FightingStrgBg:new Rectangle(30,8,2,2),
			KillUserBg:new Rectangle(100,50,150,50),
			QiangGouBg:new Rectangle(62,52,4,4),
			RechargeBottom:new Rectangle(10,10,46,65),
			ProgressBottomBg:new Rectangle(100,17,9,2),
			ProgressInner:new Rectangle(250,5,15,1),
			RemainningTimeBg:new Rectangle(100,9,2,1),
			BarBg12:new Rectangle(20,5,12,2),
			RedBar10:new Rectangle(10,4,8,1),
			PurpleBar10:new Rectangle(10,4,8,1),
			YellowBar10:new Rectangle(10,4,8,1),
			BlueBar10:new Rectangle(10,4,8,1),
			GreenBar10:new Rectangle(10,4,8,1),
			titleSelectedBg:new Rectangle(37,17,2,1),
			RechargeIntroBg:new Rectangle(30,30,21,7),
			shortcutItemBg:new Rectangle(6, 6, 20, 20)
		};
		/*public static const windowBg:BitmapData = GlobalClass.getBitmapData("WindowBg");
		public static const windowCenterA:BitmapData =GlobalClass.getBitmapData("WindowCenterA");
		public static const windowCenterB:BitmapData = GlobalClass.getBitmapData("WindowCenterB");
		public static const windowPattern:BitmapData = GlobalClass.getBitmapData("WindowPattern");*/
		
		public function ResouceConst()
		{
			
		}
		
		public static function getScaleBitmap( bmd:BitmapData ,scale9Grid:Rectangle):ScaleBitmap
		{
			var sb:ScaleBitmap = new ScaleBitmap(bmd.clone());
			sb.scale9Grid = scale9Grid;
			return sb;
		}
	}
}
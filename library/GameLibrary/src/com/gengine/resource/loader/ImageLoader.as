package com.gengine.resource.loader
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;

	/**
	 * 加载图片 
	 * @author jianglang
	 * 
	 */	
	public class ImageLoader extends BaseLoader
	{
//		private var _bitmapData:BitmapData;
		
		public function ImageLoader()
		{
			super();
		}
		
		override public function getClass():Class
		{
			return ImageLoader;
		}
		
//		public function get bitmapData():BitmapData
//		{
//			return _bitmapData;
//		}

		override protected function onContentReady(content:*):Boolean
		{
//			_bitmapData = Bitmap(content).bitmapData;
			
			if( resourceInfo && loaderInfo)
			{
				resourceInfo.data = loaderInfo;//Bitmap(content).bitmapData;
			}
			return true;
		}
	}
}
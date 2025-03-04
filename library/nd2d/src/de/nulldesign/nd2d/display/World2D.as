/*
 * ND2D - A Flash Molehill GPU accelerated 2D engine
 *
 * Author: Lars Gerckens
 * Copyright (c) nulldesign 2011
 * Repository URL: http://github.com/nulldesign/nd2d
 * Getting started: https://github.com/nulldesign/nd2d/wiki
 *
 *
 * Licence Agreement
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package de.nulldesign.nd2d.display {

	import flash.display.Sprite;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DRenderMode;
	import flash.display3D.Context3DTriangleFace;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TouchEvent;
	import flash.geom.Rectangle;
	import flash.geom.Vector3D;
	import flash.ui.Multitouch;
	import flash.ui.MultitouchInputMode;
	import flash.utils.getTimer;
	
	import de.nulldesign.nd2d.materials.shader.ShaderCache;
	import de.nulldesign.nd2d.utils.StatsObject;

	/**
	 * Dispatched when the World2D is initialized and the context3D is available. The flag 'isHardwareAccelerated' is available then
	 * @eventType flash.events.Event.INIT
	 */
	[Event(name="init", type="flash.events.Event")]

	/**
	 * <p>Baseclass for ND2D</p>
	 * Extend this class and add your own scenes and sprites
	 *
	 * Set up your project like this:
	 * <ul>
	 * <li>MyGameWorld2D</li>
	 * <li>- MyStartScene2D</li>
	 * <li>-- StartButtonSprite2D</li>
	 * <li>-- ...</li>
	 * <li>- MyGameScene2D</li>
	 * <li>-- GameSprites2D</li>
	 * <li>-- ...</li>
	 * </ul>
	 * <p>Put your game logic in the step() method of each scene / node</p>
	 *
	 * You can switch between scenes with the setActiveScene method of World2D.
	 * There can be only one active scene.
	 *
	 */ public class World2D extends Sprite {

		protected var camera:Camera2D = new Camera2D(1, 1);
		protected var context3D:Context3D;
		protected var stageID:uint;
		protected var scene:Scene2D;

		protected var isPaused:Boolean = false;
		protected var bounds:Rectangle;
		protected var lastFramesTime:Number = 0.0;
		protected var enableErrorChecking:Boolean = true;

		protected var renderMode:String;
		protected var renderProfile:String;
		protected var mousePosition:Vector3D = new Vector3D(0.0, 0.0, 0.0);
		protected var antialiasing:uint = 2;
		protected var deviceInitialized:Boolean = false;
		protected var deviceWasLost:Boolean = false;

		public var statsObject:StatsObject = new StatsObject();

		internal var topMostMouseNode:Node2D;

		public static var isHardwareAccelerated:Boolean;

		/**
		 * Constructor of class world
		 * @param renderMode Context3DRenderMode (auto, software)
		 * @param frameRate timer and the swf will be set to this framerate
		 * @param bounds the worlds boundaries
		 * @param stageID
		 * @param renderProfile Context3DProfile that should be used. If you target < FP 11.4 just use the default "baselineConstrained"
		 */
		public function World2D(renderMode:String = Context3DRenderMode.AUTO, bounds:Rectangle = null, stageID:uint = 0, renderProfile:String = "baselineConstrained") {
			this.renderMode = renderMode;
			this.renderProfile = renderProfile;

			this.bounds = bounds;
			this.stageID = stageID;
			addEventListener(Event.ADDED_TO_STAGE, addedToStage);
		}

		protected function addedToStage(event:Event):void {

			removeEventListener(Event.ADDED_TO_STAGE, addedToStage);

			if(stage.stage3Ds[stageID].context3D) {
				context3DCreated(null);
			} else {
				stage.stage3Ds[stageID].addEventListener(Event.CONTEXT3D_CREATE, context3DCreated);
				stage.stage3Ds[stageID].addEventListener(ErrorEvent.ERROR, context3DError);

				var requestContextFunc:Function = stage.stage3Ds[stageID].requestContext3D;

				if(requestContextFunc.length == 1) {
					requestContextFunc(renderMode);
				} else {
					requestContextFunc(renderMode, renderProfile);
				}
			}

			stage.addEventListener(MouseEvent.CLICK, mouseEventHandler);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, mouseEventHandler);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseEventHandler);
			stage.addEventListener(MouseEvent.MOUSE_UP, mouseEventHandler);

			Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
			stage.addEventListener(TouchEvent.TOUCH_TAP, touchEventHandler);
			stage.addEventListener(TouchEvent.TOUCH_BEGIN, touchEventHandler);
			stage.addEventListener(TouchEvent.TOUCH_MOVE, touchEventHandler);
			stage.addEventListener(TouchEvent.TOUCH_END, touchEventHandler);
		}

		protected function context3DError(e:ErrorEvent):void {
			throw new Error("The SWF is not embedded properly. The 3D context can't be created. Wrong WMODE? Set it to 'direct'. For AIR it's renderMode = direct in the application descriptor");
		}

		protected function context3DCreated(e:Event):void {

			context3D = stage.stage3Ds[stageID].context3D;
			context3D.enableErrorChecking = enableErrorChecking;
			context3D.setCulling(Context3DTriangleFace.NONE);
			context3D.setDepthTest(false, Context3DCompareMode.ALWAYS);
			isHardwareAccelerated = context3D.driverInfo.toLowerCase().indexOf("software") == -1;

			resizeStage();

			// means we got the Event.CONTEXT3D_CREATE for the second time, the device was lost. reinit everything
			if(deviceInitialized) {
				deviceWasLost = true;
			}

			deviceInitialized = true;

			if(scene) {
				scene.setStageAndCamRef(stage, camera);
			}

			dispatchEvent(new Event(Event.INIT));
		}

		protected function touchEventHandler(event:TouchEvent):void {
			if(scene && scene.mouseEnabled && stage && camera) {
				var mouseEventType:String = event.type;

				// transformation of normalized coordinates between -1 and 1
				mousePosition.x = (event.stageX - (bounds ? bounds.x : 0.0)) / camera.sceneWidth * 2.0 - 1.0;
				mousePosition.y = -((event.stageY - (bounds ? bounds.y : 0.0)) / camera.sceneHeight * 2.0 - 1.0);
				mousePosition.z = 0.0;
				mousePosition.w = 1.0;

				var newTopMostMouseNode:Node2D = scene.processMouseEvent(mousePosition, mouseEventType, camera.getViewProjectionMatrix(), true, event.touchPointID);
				if(newTopMostMouseNode) {

					for each(var mouseEvent:Event in newTopMostMouseNode.mouseEvents) {

						if(topMostMouseNode && mouseEvent.type == TouchEvent.TOUCH_OVER) {
							topMostMouseNode.mouseInNode = false;
							topMostMouseNode.dispatchEvent(new TouchEvent(TouchEvent.TOUCH_OUT, false, false, -1 /* TODO */, false, topMostMouseNode.mouseX, topMostMouseNode.mouseY));
							newTopMostMouseNode.mouseInNode = true;
						}

						newTopMostMouseNode.dispatchEvent(mouseEvent);
					}

					topMostMouseNode = newTopMostMouseNode;
				}
			}
		}

		protected function mouseEventHandler(event:MouseEvent):void 
		{
			if(event.target!=stage)
			{
				return;
			}
			if(scene && scene.mouseEnabled && stage && camera) {
				var mouseEventType:String = event.type;
				// transformation of normalized coordinates between -1 and 1
				mousePosition.x = (stage.mouseX - (bounds ? bounds.x : 0.0)) / camera.sceneWidth * 2.0 - 1.0;
				mousePosition.y = -((stage.mouseY - (bounds ? bounds.y : 0.0)) / camera.sceneHeight * 2.0 - 1.0);
				mousePosition.z = 0.0;
				mousePosition.w = 1.0;

				var newTopMostMouseNode:Node2D = scene.processMouseEvent(mousePosition, mouseEventType, camera.getViewProjectionMatrix(), false, 0);
				if(newTopMostMouseNode) {

					for each(var mouseEvent:Event in newTopMostMouseNode.mouseEvents) {

						if(topMostMouseNode && mouseEvent.type == MouseEvent.MOUSE_OVER) {
							topMostMouseNode.mouseInNode = false;
							topMostMouseNode.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_OUT, false, false, topMostMouseNode.mouseX, topMostMouseNode.mouseY));
							newTopMostMouseNode.mouseInNode = true;
						}

						newTopMostMouseNode.dispatchEvent(mouseEvent);
					}

					topMostMouseNode = newTopMostMouseNode;
				}
			}
		}

		public function resizeStage(e:Event = null):void 
		{
			if(!context3D || context3D.driverInfo == "Disposed") return;

			var rect:Rectangle = bounds ? bounds : new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
			stage.stage3Ds[stageID].x = rect.x;
			stage.stage3Ds[stageID].y = rect.y;

			context3D.configureBackBuffer(rect.width, rect.height, antialiasing, true);
			camera.resizeCameraStage(rect.width, rect.height);
		}
		public function toUpdate():void
		{
			var t:Number = getTimer() * 0.001;
			var elapsed:Number = t - lastFramesTime;
			if(scene && context3D) 
			{
				if(!isPaused) {
					scene.stepNode(elapsed, t);
				}
				
				if(deviceWasLost) {
					ShaderCache.getInstance().handleDeviceLoss();
					scene.handleDeviceLoss();
					deviceWasLost = false;
				}
				
				statsObject.totalDrawCalls = 0;
				statsObject.totalTris = 0;
			}
			lastFramesTime = t;
		}
		
		public function toDraw():void 
		{
			if(scene && context3D)
			{
				context3D.clear(scene.br, scene.bg, scene.bb, 1.0);
				scene.drawNode(context3D, camera, false, statsObject);
			}
		}

		public function setActiveScene(value:Scene2D):void {

			if(scene) {
				scene.setStageAndCamRef(null, null);
			}

			this.scene = value;

			if(scene) {
				scene.setStageAndCamRef(stage, camera);
			}
		}

		public function start():void {
			wakeUp();
		}

		/**
		 * Pause all movement in your game. The drawing loop will still fire
		 */
		public function pause():void {
			isPaused = true;
		}

		/**
		 * Resume movement in your game.
		 */
		public function resume():void {
			isPaused = false;
		}

		/**
		 * Put everything to sleep, no drawing and step loop will be fired
		 */
		public function sleep():void {

			//removeEventListener(Event.ENTER_FRAME, mainLoop);

			if(context3D) {
				context3D.clear(scene.br, scene.bg, scene.bb, 1.0);
				context3D.present();
			}
		}

		/**
		 * wake up from sleep. draw / step loops will start to fire again
		 */
		public function wakeUp():void {
			//removeEventListener(Event.ENTER_FRAME, mainLoop);
			//addEventListener(Event.ENTER_FRAME, mainLoop);
		}

		public function dispose():void {
			pause();
			sleep();
			ShaderCache.getInstance().dispose();

			for(var i:int = 0; i < stage.stage3Ds.length; i++) {
				stage.stage3Ds[i].removeEventListener(Event.CONTEXT3D_CREATE, context3DCreated);
				stage.stage3Ds[i].removeEventListener(ErrorEvent.ERROR, context3DError);
			}

			stage.removeEventListener(MouseEvent.CLICK, mouseEventHandler);
			stage.removeEventListener(MouseEvent.MOUSE_DOWN, mouseEventHandler);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseEventHandler);
			stage.removeEventListener(MouseEvent.MOUSE_UP, mouseEventHandler);

			stage.removeEventListener(TouchEvent.TOUCH_TAP, touchEventHandler);
			stage.removeEventListener(TouchEvent.TOUCH_BEGIN, touchEventHandler);
			stage.removeEventListener(TouchEvent.TOUCH_MOVE, touchEventHandler);
			stage.removeEventListener(TouchEvent.TOUCH_END, touchEventHandler);

			if(context3D) {
				context3D.dispose();
				context3D = null;
			}

			if(scene) {
				scene.dispose();
				scene = null;
			}
		}
	}
}
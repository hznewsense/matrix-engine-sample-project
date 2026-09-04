/*
 * Copyright (c) 2026 Hangzhou Xinzhi IOT Technology Co., Ltd. All rights reserved.
 */
package com.ns.matrix.sample.aar;

import android.os.Bundle;
import android.util.Log;
import android.view.SurfaceView;

import androidx.appcompat.app.AppCompatActivity;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;

import com.ns.matrixengine.IEngineSuperClient;
import com.ns.matrixengine.ISurface;
import com.ns.sdkclient.MatrixSurface;

public class MainActivity extends AppCompatActivity {

	private static final String TAG = "MainActivity";
	// backbuffer 固定缓冲尺寸，兼作触摸坐标缩放的目标空间
	private static final int BACKBUFFER_WIDTH = 1920;
	private static final int BACKBUFFER_HEIGHT = 1200;

	private ISurface surface;
	private IEngineSuperClient engineClient;
	private int cameraId = 0; // 可根据实际需要赋值或通过其他方式传入
	private SurfaceView surfaceView;
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		Log.i(TAG, "onCreate");
		super.onCreate(savedInstanceState);
		
		// 设置全屏，隐藏状态栏和导航栏
		WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
		
		setContentView(R.layout.activity_main);
		hideSystemUI();
		initMatrixSurface();
	}


	@Override
	protected void onStart() {
		Log.i(TAG, "onStart");
		super.onStart();
	}

	@Override
	protected void onResume() {
		Log.i(TAG, "onResume");
		super.onResume();
		hideSystemUI();
		if (surface == null || engineClient == null) {
			return;
		}
		Log.i(TAG, "Attaching surface");
		engineClient.attachSurface(surface);
	}


	@Override
	protected void onPause() {
		super.onPause();
		Log.i(TAG, "onPause");
	}

	@Override
	protected void onStop() {
		Log.i(TAG, "onStop");
		super.onStop();
	}

	@Override
	protected void onDestroy() {
		Log.i(TAG, "onDestroy");
		super.onDestroy();
	}
	@Override
	public void onWindowFocusChanged(boolean hasFocus) {
		super.onWindowFocusChanged(hasFocus);
		if (hasFocus) {
			hideSystemUI();
		}
	}

	// 把触摸坐标从视图空间缩放到 backbuffer 空间，令按钮命中与Matrix渲染分辨率对齐
//	@Override
//	public boolean dispatchTouchEvent(MotionEvent ev) {
//		int viewWidth = surfaceView == null ? 0 : surfaceView.getWidth();
//		int viewHeight = surfaceView == null ? 0 : surfaceView.getHeight();
//		if (viewWidth > 0 && viewHeight > 0) {
//			Matrix transform = new Matrix();
//			transform.setScale(BACKBUFFER_WIDTH / (float) viewWidth, BACKBUFFER_HEIGHT / (float) viewHeight);
//			ev.transform(transform);
//		}
//		return super.dispatchTouchEvent(ev);
//	}

	private void hideSystemUI() {
		WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
		if (controller == null) {
			return;
		}
		controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
		controller.hide(WindowInsetsCompat.Type.systemBars());
	}

	private  void initMatrixSurface() {
		engineClient = MatrixServiceApp.getInstance().getEngineClient();
		surfaceView = findViewById(R.id.surfaceView);
		// 固定 backbuffer 缓冲为 1920×1200，由硬件合成器放大到面板
	//	surfaceView.getHolder().setFixedSize(BACKBUFFER_WIDTH, BACKBUFFER_HEIGHT);
		surface = MatrixSurface.newBuilder(MainActivity.this, surfaceView)
			.withCameraId(cameraId)
			.withTouchSupport(true)
			.withAlphaValue(1.0f)
			.build();
		Log.i(TAG, "initMatrixSurface");
	}

}

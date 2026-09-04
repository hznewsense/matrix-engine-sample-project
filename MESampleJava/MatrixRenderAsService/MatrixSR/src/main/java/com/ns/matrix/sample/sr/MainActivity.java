/*
 * Copyright (c) 2026 Hangzhou Xinzhi IOT Technology Co., Ltd. All rights reserved.
 */
package com.ns.matrix.sample.sr;

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

	private ISurface surface;
	private IEngineSuperClient engineClient;
	private int cameraId = 1; // 可根据实际需要赋值或通过其他方式传入
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
		engineClient.resume();
		Log.i(TAG, "Attaching surface");
		engineClient.attachSurface(surface);
	}


	@Override
	protected void onPause() {
		Log.i(TAG, "onPause");
		super.onPause();
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
	
	private void hideSystemUI() {
		WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
		if (controller == null) {
			return;
		}
		controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
		controller.hide(WindowInsetsCompat.Type.systemBars());
	}

	private  void initMatrixSurface() {
		engineClient = MatrixClientApp.getInstance().getEngineClient();
		surfaceView = findViewById(R.id.surfaceView);
		surface = MatrixSurface.newBuilder(MainActivity.this, surfaceView)
			.withCameraId(cameraId)
			.withTouchSupport(true)
			.withAlphaValue(1.0f)
			.build();
		Log.i(TAG, "initMatrixSurface");
	}

}

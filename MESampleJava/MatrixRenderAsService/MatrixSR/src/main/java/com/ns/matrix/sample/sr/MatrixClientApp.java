/*
 * Copyright (c) 2026 Hangzhou Xinzhi IOT Technology Co., Ltd. All rights reserved.
 */
package com.ns.matrix.sample.sr;

import android.app.Application;
import android.util.Log;

import com.ns.matrixengine.IEngineSuperClient;
import com.ns.matrixengine.IEngineSuperClientListener;
import com.ns.sdkclient.MatrixEngineSuperClient;

public class MatrixClientApp extends Application  {
	private static final String TAG = "MatrixClientApp";
	private static MatrixClientApp instance;
	private static final int BASE_CONNECTION_ID = 8000001;
	final int index = 0;
	final int connectionId = BASE_CONNECTION_ID;
	private IEngineSuperClient engine;


	@Override
	public void onCreate() {
		Log.i(TAG, "onCreate");
		super.onCreate();
		instance = this;
		initEngine();
	}

	public static MatrixClientApp getInstance() {
		return instance;
	}

	public IEngineSuperClient getEngineClient() {
		initEngine();
		return engine;
	}
	public void initEngine() {
		if (engine != null) {
			return;
		}

		engine = MatrixEngineSuperClient.newBuilder(this)
			.withServicePackageName("com.ns.matrix.sample.service")
			.withServiceConnectionId(connectionId)
			.withEngineClientListener(new IEngineSuperClientListener() {
				@Override
				public void onStarted(boolean b) {

				}

				@Override
				public void onBoundToService(boolean isSuccess) {
					Log.i(TAG, "onBoundToService index=" + index + " id=" + connectionId + " success=" + isSuccess);
				}
				@Override
				public void onUnboundToService() {
					Log.i(TAG, "onUnboundToService index=" + index + " id=" + connectionId);
				}
			})
			.build();
		engine.bindToService();
	}
}

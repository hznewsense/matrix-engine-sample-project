/*
 * Copyright (c) 2026 Hangzhou Xinzhi IOT Technology Co., Ltd. All rights reserved.
 */
package com.ns.matrix.sample.aar;

import android.app.Application;
import android.content.Intent;
import android.util.Log;

import com.ns.matrixengine.IEngineSuperClient;
import com.ns.matrixengine.IEngineSuperClientListener;
import com.ns.sdkclient.MatrixEngineSuperClient;

import com.ns.matrix.MatrixService;
import com.ns.matrix.PCKManager;

import java.io.File;

public class MatrixServiceApp extends Application {
    private static MatrixServiceApp instance;
    private static final String TAG = "MatrixServiceApp";
    private IEngineSuperClient engineSuperClient;
    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "MatrixServiceApp created");
        instance = this;
        initializePckWithSmartLoading();
        startMatrixServiceFromForeground();
        initEngine();
    }
    // 负责从外部存储路径加载并部署Matrix资产（PCK/OBB）
    private void initializePckWithSmartLoading() {
        File externalDir = getExternalFilesDir(null);
        if (externalDir == null) {
            return;
        }
        String externalPath = new File(externalDir, "game.obb").getAbsolutePath();
        PCKManager.INSTANCE.smartInstallPckFromAssets(this, externalPath);
    }
    // 以前台服务形式启动 MatrixService
    private void startMatrixServiceFromForeground() {
        try {
            Intent intent = new Intent(this, MatrixService.class);
            startForegroundService(intent);
            Log.i(TAG, "Requested MatrixService start");
        } catch (Exception e) {
            Log.w(TAG, "Failed to start MatrixService", e);
        }
    }

    public static MatrixServiceApp getInstance() {
        return instance;
    }

    public IEngineSuperClient getEngineClient() {
        initEngine();
        return engineSuperClient;
    }
    public void initEngine() {
        if (engineSuperClient != null) {
            return;
        }

        engineSuperClient = MatrixEngineSuperClient.newBuilder(this)
                .withServicePackageName("com.ns.matrix.sample.aar")
                .withServiceConnectionId(1000001)
                .withEngineClientListener(new IEngineSuperClientListener() {
                    @Override
                    public void onStarted(boolean b) {

                    }

                    @Override
                    public void onStopped() {
                        IEngineSuperClientListener.super.onStopped();
                    }

                    @Override
                    public void onPaused() {
                        IEngineSuperClientListener.super.onPaused();
                    }

                    @Override
                    public void onResume() {
                        IEngineSuperClientListener.super.onResume();
                    }

                    @Override
                    public void onSleep() {
                        IEngineSuperClientListener.super.onSleep();
                    }

                    @Override
                    public void onWakeup() {
                        IEngineSuperClientListener.super.onWakeup();
                    }

                    @Override
                    public void onBoundToService(boolean isSuccess) {
                    }
                    @Override
                    public void onUnboundToService() {
                    }
                })
                .build();
        engineSuperClient.bindToService();
    }
}

/*
 * Copyright (c) 2026 Hangzhou Xinzhi IOT Technology Co., Ltd. All rights reserved.
 */
package com.ns.matrix.sample.service;

import android.app.Application;
import android.util.Log;

import com.ns.matrix.PCKManager;

import java.io.File;

public class MatrixServiceApp extends Application {
    private static final String TAG = "MatrixServiceApp";
    private static MatrixServiceApp instance;
    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        Log.i(TAG, "MatrixServiceApp created");
        initializePckWithSmartLoading();
    }
    public static MatrixServiceApp getInstance() {
        return instance;
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
}

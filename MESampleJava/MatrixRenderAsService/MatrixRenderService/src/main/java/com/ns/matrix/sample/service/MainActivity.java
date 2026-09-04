/*
 * Copyright (c) 2026 Hangzhou Xinzhi IOT Technology Co., Ltd. All rights reserved.
 */
package com.ns.matrix.sample.service;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;

import com.ns.matrix.MatrixService;

public class MainActivity extends Activity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        ensureNotificationPermission();
        startMatrixServiceFromForeground();
    }
    private void ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return;
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1001);
        }
    }

    public void startMatrixServiceFromForeground() {
        try {
            Intent intent = new Intent(this, MatrixService.class);
            startForegroundService(intent);
            Log.i("MainActivity", "Requested MatrixService start");
        } catch (Exception e) {
            Log.w("MainActivity", "Failed to start MatrixService", e);
        }
    }
}
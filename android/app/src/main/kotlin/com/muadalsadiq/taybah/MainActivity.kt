package com.muadalsadiq.taybah

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity بدل FlutterActivity حتى تعمل التلاوة في الخلفية وعلى شاشة القفل
class MainActivity : AudioServiceActivity()

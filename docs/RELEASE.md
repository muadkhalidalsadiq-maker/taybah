# نشر تطبيق طيبة

## 1) مفتاح توقيع أندرويد (مرة واحدة فقط)

أنشئ المفتاح على جهازك واحفظه في مكان آمن (إذا ضاع لا يمكن تحديث التطبيق على Google Play):

```bash
keytool -genkey -v -keystore taybah-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias taybah
```

**محلياً:** أنشئ الملف `android/key.properties` (لا يُرفع على GitHub):

```properties
storeFile=/المسار/الكامل/taybah-upload.jks
storePassword=كلمة_سر_المخزن
keyAlias=taybah
keyPassword=كلمة_سر_المفتاح
```

**في Codemagic:** ارفع الملف من Team settings → Code signing identities → Android keystores،
ثم فعّل «Android code signing» في الـ workflow. Codemagic يضبط تلقائياً المتغيرات
`CM_KEYSTORE_PATH`, `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS`, `CM_KEY_PASSWORD`
التي يقرأها `android/app/build.gradle.kts`.

بدون مفتاح تُوقَّع النسخة بمفتاح التجربة (debug) — صالحة للتجربة فقط وليس لـ Google Play.

## 2) حجم التطبيق

- **Google Play:** ارفع ملف AAB وليس APK — كل هاتف ينزّل الجزء الخاص بمعالجه فقط:
  `flutter build appbundle --release`
- **للمشاركة المباشرة:** نسخة لكل معالج بدل نسخة واحدة كبيرة:
  `flutter build apk --release --split-per-abi`
  (أغلب الهواتف الحديثة: `app-arm64-v8a-release.apk`)

## 3) سياسة الخصوصية

المتاجر تطلب رابطاً لسياسة الخصوصية. الصفحة جاهزة في `docs/privacy-policy.html`.
لنشرها مجاناً: GitHub → Settings → Pages → Source: «Deploy from a branch» → Branch: `main` / المجلد `/docs`.
سيكون الرابط:
`https://muadkhalidalsadiq-maker.github.io/taybah/privacy-policy.html`

## 4) iOS

- يجب على صاحب حساب Apple Developer الموافقة على أي اتفاقية جديدة في developer.apple.com قبل البناء.
- أصوات الأذان للآيفون في `ios/Runner/Sounds` (مقاطع أقل من 30 ثانية، حد Apple لأصوات الإشعارات).
- في Codemagic استعمل معرّف التطبيق: `com.muadalsadiq.taybah`.

## 5) قبل كل إصدار

```bash
flutter analyze
flutter test
```
وارفع رقم `version` في `pubspec.yaml`.

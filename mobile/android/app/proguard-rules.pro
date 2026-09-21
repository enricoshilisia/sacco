# ML Kit text recognition ships optional script packs (Chinese, Devanagari,
# Japanese, Korean). The app only reads Latin-script ID cards and doesn't
# include those packs, so tell R8 their classes are intentionally absent.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

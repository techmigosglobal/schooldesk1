-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
# Keep Stripe classes
-keep class com.stripe.** { *; }

# image_cropper passes local file paths to uCrop. uCrop still contains optional
# HTTP downloader code, but the Flutter plugin does not package or invoke it.
# Suppress R8 warnings for that unreachable optional integration; do not add a
# network client merely to satisfy classes that are not part of this app's flow.
-dontwarn okhttp3.**

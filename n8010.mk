#
# Copyright (C) 2012 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

LOCAL_PATH := device/samsung/n8010

DEVICE_PACKAGE_OVERLAYS += $(LOCAL_PATH)/overlay

# Disable VINTF manifest enforcement for legacy non-Treble device
# Prevents crashes when apps query unavailable HIDL HAL services
PRODUCT_ENFORCE_VINTF_MANIFEST := false

# Rootdir
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/rootdir/init.target.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/hw/init.target.rc

# HIDL
DEVICE_MANIFEST_FILE := $(LOCAL_PATH)/manifest.xml

$(call inherit-product-if-exists, vendor/samsung/n8010/n8010-vendor.mk)

# Software KeyMint service (AIDL KeyMint 3.0, software-only)
# Required for Android 14: odsign creates keys with TAG_MAX_BOOT_LEVEL=30 which
# Samsung's legacy Keymaster 3.0 HIDL HAL does not support. Without this service,
# odsign silently crashes and wait_for_prop odsign.key.done 1 blocks forever.
PRODUCT_PACKAGES += android.hardware.security.keymint-service

# Vendor properties
-include $(LOCAL_PATH)/vendor_prop.mk
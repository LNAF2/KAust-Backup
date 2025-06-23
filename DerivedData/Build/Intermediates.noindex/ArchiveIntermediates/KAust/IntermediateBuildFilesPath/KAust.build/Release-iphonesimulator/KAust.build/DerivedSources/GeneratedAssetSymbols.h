#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.erlingbreaden.KAust";

/// The "AppBackground" asset catalog color resource.
static NSString * const ACColorNameAppBackground AC_SWIFT_PRIVATE = @"AppBackground";

/// The "LeftPanelAccent" asset catalog color resource.
static NSString * const ACColorNameLeftPanelAccent AC_SWIFT_PRIVATE = @"LeftPanelAccent";

/// The "LeftPanelBg" asset catalog color resource.
static NSString * const ACColorNameLeftPanelBg AC_SWIFT_PRIVATE = @"LeftPanelBg";

/// The "LeftPanelItemBg" asset catalog color resource.
static NSString * const ACColorNameLeftPanelItemBg AC_SWIFT_PRIVATE = @"LeftPanelItemBg";

/// The "LeftPanelListBg" asset catalog color resource.
static NSString * const ACColorNameLeftPanelListBg AC_SWIFT_PRIVATE = @"LeftPanelListBg";

/// The "LeftPanelTextPrimary" asset catalog color resource.
static NSString * const ACColorNameLeftPanelTextPrimary AC_SWIFT_PRIVATE = @"LeftPanelTextPrimary";

/// The "LeftPanelTextSecondary" asset catalog color resource.
static NSString * const ACColorNameLeftPanelTextSecondary AC_SWIFT_PRIVATE = @"LeftPanelTextSecondary";

/// The "RightPanelAccent" asset catalog color resource.
static NSString * const ACColorNameRightPanelAccent AC_SWIFT_PRIVATE = @"RightPanelAccent";

/// The "RightPanelBg" asset catalog color resource.
static NSString * const ACColorNameRightPanelBg AC_SWIFT_PRIVATE = @"RightPanelBg";

/// The "RightPanelItemBg" asset catalog color resource.
static NSString * const ACColorNameRightPanelItemBg AC_SWIFT_PRIVATE = @"RightPanelItemBg";

/// The "RightPanelListBg" asset catalog color resource.
static NSString * const ACColorNameRightPanelListBg AC_SWIFT_PRIVATE = @"RightPanelListBg";

/// The "RightPanelTextPrimary" asset catalog color resource.
static NSString * const ACColorNameRightPanelTextPrimary AC_SWIFT_PRIVATE = @"RightPanelTextPrimary";

/// The "RightPanelTextSecondary" asset catalog color resource.
static NSString * const ACColorNameRightPanelTextSecondary AC_SWIFT_PRIVATE = @"RightPanelTextSecondary";

/// The "SettingResetBlue" asset catalog color resource.
static NSString * const ACColorNameSettingResetBlue AC_SWIFT_PRIVATE = @"SettingResetBlue";

#undef AC_SWIFT_PRIVATE

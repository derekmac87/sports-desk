#!/usr/bin/env python3
"""Generate SportsDesk.xcodeproj/project.pbxproj for iOS + tvOS + local package."""
from pathlib import Path

ROOT = Path("/workspace")
SOURCES = [
    "Apps/SportsDesk/SportsDeskApp.swift",
    "Apps/SportsDesk/AppModel.swift",
    "Apps/SportsDesk/Theme.swift",
    "Apps/SportsDesk/Views/RootView.swift",
    "Apps/SportsDesk/Views/DashboardView.swift",
    "Apps/SportsDesk/Views/TeamDashboardView.swift",
    "Apps/SportsDesk/Views/Cards/DashboardCards.swift",
    "Apps/SportsDesk/Views/Details/DetailViews.swift",
    "Apps/SportsDesk/Views/Settings/SettingsView.swift",
]


def uid(seed: str) -> str:
    return f"{abs(hash(seed)):024x}"[:24].upper()


# Stable IDs (don't use hash — not stable across runs)
IDS = {
    "project": "A10000000000000000000001",
    "ios_target": "A10000000000000000000010",
    "tv_target": "A10000000000000000000011",
    "ios_sources": "A10000000000000000000020",
    "tv_sources": "A10000000000000000000021",
    "ios_frameworks": "A10000000000000000000022",
    "tv_frameworks": "A10000000000000000000023",
    "ios_resources": "A10000000000000000000024",
    "tv_resources": "A10000000000000000000025",
    "main_group": "A10000000000000000000030",
    "products": "A10000000000000000000031",
    "app_group": "A10000000000000000000032",
    "views_group": "A10000000000000000000033",
    "cards_group": "A10000000000000000000034",
    "details_group": "A10000000000000000000035",
    "settings_group": "A10000000000000000000036",
    "resources_group": "A10000000000000000000037",
    "ios_product": "A10000000000000000000040",
    "tv_product": "A10000000000000000000041",
    "assets": "A10000000000000000000050",
    "info_ios": "A10000000000000000000051",
    "info_tv": "A10000000000000000000052",
    "entitlements": "A10000000000000000000053",
    "package": "A10000000000000000000060",
    "ios_product_dep": "A10000000000000000000061",
    "tv_product_dep": "A10000000000000000000062",
    "ios_pkg_build": "A10000000000000000000063",
    "tv_pkg_build": "A10000000000000000000064",
    "project_debug": "A10000000000000000000070",
    "project_release": "A10000000000000000000071",
    "ios_debug": "A10000000000000000000072",
    "ios_release": "A10000000000000000000073",
    "tv_debug": "A10000000000000000000074",
    "tv_release": "A10000000000000000000075",
    "project_configs": "A10000000000000000000080",
    "ios_configs": "A10000000000000000000081",
    "tv_configs": "A10000000000000000000082",
}

file_ids = {}
build_ios = {}
build_tv = {}
for i, path in enumerate(SOURCES, start=1):
    file_ids[path] = f"A2000000000000000000{i:04d}"
    build_ios[path] = f"A2100000000000000000{i:04d}"
    build_tv[path] = f"A2200000000000000000{i:04d}"

assets_ios = "A23000000000000000000001"
assets_tv = "A23000000000000000000002"

def fileref(path: str) -> str:
    name = Path(path).name
    return f'\t\t{file_ids[path]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};'


source_build_ios = "\n".join(
    f"\t\t{build_ios[p]} /* {Path(p).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[p]} /* {Path(p).name} */; }};"
    for p in SOURCES
)
source_build_tv = "\n".join(
    f"\t\t{build_tv[p]} /* {Path(p).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[p]} /* {Path(p).name} */; }};"
    for p in SOURCES
)

ios_source_list = "\n".join(f"\t\t\t\t{build_ios[p]} /* {Path(p).name} in Sources */," for p in SOURCES)
tv_source_list = "\n".join(f"\t\t\t\t{build_tv[p]} /* {Path(p).name} in Sources */," for p in SOURCES)

file_refs = "\n".join(fileref(p) for p in SOURCES)

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{source_build_ios}
{source_build_tv}
		{assets_ios} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {IDS['assets']} /* Assets.xcassets */; }};
		{assets_tv} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {IDS['assets']} /* Assets.xcassets */; }};
		{IDS['ios_pkg_build']} /* SportsDeskCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {IDS['ios_product_dep']} /* SportsDeskCore */; }};
		{IDS['tv_pkg_build']} /* SportsDeskCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {IDS['tv_product_dep']} /* SportsDeskCore */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		{IDS['ios_product']} /* SportsDesk.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SportsDesk.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{IDS['tv_product']} /* SportsDeskTV.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SportsDeskTV.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{file_refs}
		{IDS['assets']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{IDS['info_ios']} /* Info-iOS.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info-iOS.plist"; sourceTree = "<group>"; }};
		{IDS['info_tv']} /* Info-tvOS.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info-tvOS.plist"; sourceTree = "<group>"; }};
		{IDS['entitlements']} /* SportsDesk.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = SportsDesk.entitlements; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{IDS['ios_frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{IDS['ios_pkg_build']} /* SportsDeskCore in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['tv_frameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{IDS['tv_pkg_build']} /* SportsDeskCore in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{IDS['main_group']} = {{
			isa = PBXGroup;
			children = (
				{IDS['app_group']} /* SportsDesk */,
				{IDS['products']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{IDS['products']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{IDS['ios_product']} /* SportsDesk.app */,
				{IDS['tv_product']} /* SportsDeskTV.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{IDS['app_group']} /* SportsDesk */ = {{
			isa = PBXGroup;
			children = (
				{file_ids['Apps/SportsDesk/SportsDeskApp.swift']} /* SportsDeskApp.swift */,
				{file_ids['Apps/SportsDesk/AppModel.swift']} /* AppModel.swift */,
				{file_ids['Apps/SportsDesk/Theme.swift']} /* Theme.swift */,
				{IDS['views_group']} /* Views */,
				{IDS['resources_group']} /* Resources */,
			);
			name = SportsDesk;
			path = Apps/SportsDesk;
			sourceTree = "<group>";
		}};
		{IDS['views_group']} /* Views */ = {{
			isa = PBXGroup;
			children = (
				{file_ids['Apps/SportsDesk/Views/RootView.swift']} /* RootView.swift */,
				{file_ids['Apps/SportsDesk/Views/DashboardView.swift']} /* DashboardView.swift */,
				{file_ids['Apps/SportsDesk/Views/TeamDashboardView.swift']} /* TeamDashboardView.swift */,
				{IDS['cards_group']} /* Cards */,
				{IDS['details_group']} /* Details */,
				{IDS['settings_group']} /* Settings */,
			);
			path = Views;
			sourceTree = "<group>";
		}};
		{IDS['cards_group']} /* Cards */ = {{
			isa = PBXGroup;
			children = (
				{file_ids['Apps/SportsDesk/Views/Cards/DashboardCards.swift']} /* DashboardCards.swift */,
			);
			path = Cards;
			sourceTree = "<group>";
		}};
		{IDS['details_group']} /* Details */ = {{
			isa = PBXGroup;
			children = (
				{file_ids['Apps/SportsDesk/Views/Details/DetailViews.swift']} /* DetailViews.swift */,
			);
			path = Details;
			sourceTree = "<group>";
		}};
		{IDS['settings_group']} /* Settings */ = {{
			isa = PBXGroup;
			children = (
				{file_ids['Apps/SportsDesk/Views/Settings/SettingsView.swift']} /* SettingsView.swift */,
			);
			path = Settings;
			sourceTree = "<group>";
		}};
		{IDS['resources_group']} /* Resources */ = {{
			isa = PBXGroup;
			children = (
				{IDS['assets']} /* Assets.xcassets */,
				{IDS['info_ios']} /* Info-iOS.plist */,
				{IDS['info_tv']} /* Info-tvOS.plist */,
				{IDS['entitlements']} /* SportsDesk.entitlements */,
			);
			path = Resources;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{IDS['ios_target']} /* SportsDesk */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {IDS['ios_configs']} /* Build configuration list for PBXNativeTarget "SportsDesk" */;
			buildPhases = (
				{IDS['ios_sources']} /* Sources */,
				{IDS['ios_frameworks']} /* Frameworks */,
				{IDS['ios_resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = SportsDesk;
			packageProductDependencies = (
				{IDS['ios_product_dep']} /* SportsDeskCore */,
			);
			productName = SportsDesk;
			productReference = {IDS['ios_product']} /* SportsDesk.app */;
			productType = "com.apple.product-type.application";
		}};
		{IDS['tv_target']} /* SportsDeskTV */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {IDS['tv_configs']} /* Build configuration list for PBXNativeTarget "SportsDeskTV" */;
			buildPhases = (
				{IDS['tv_sources']} /* Sources */,
				{IDS['tv_frameworks']} /* Frameworks */,
				{IDS['tv_resources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = SportsDeskTV;
			packageProductDependencies = (
				{IDS['tv_product_dep']} /* SportsDeskCore */,
			);
			productName = SportsDeskTV;
			productReference = {IDS['tv_product']} /* SportsDeskTV.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{IDS['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {IDS['project_configs']} /* Build configuration list for PBXProject "SportsDesk" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {IDS['main_group']};
			packageReferences = (
				{IDS['package']} /* XCLocalSwiftPackageReference */,
			);
			productRefGroup = {IDS['products']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{IDS['ios_target']} /* SportsDesk */,
				{IDS['tv_target']} /* SportsDeskTV */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{IDS['ios_resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_ios} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['tv_resources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_tv} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{IDS['ios_sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{ios_source_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{IDS['tv_sources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{tv_source_list}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{IDS['project_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 6.0;
			}};
			name = Debug;
		}};
		{IDS['project_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 6.0;
			}};
			name = Release;
		}};
		{IDS['ios_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Apps/SportsDesk/Resources/SportsDesk.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "Apps/SportsDesk/Resources/Info-iOS.plist";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sportsdesk.SportsDesk;
				PRODUCT_NAME = SportsDesk;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{IDS['ios_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Apps/SportsDesk/Resources/SportsDesk.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "Apps/SportsDesk/Resources/Info-iOS.plist";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sportsdesk.SportsDesk;
				PRODUCT_NAME = SportsDesk;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
		{IDS['tv_debug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Apps/SportsDesk/Resources/SportsDesk.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "Apps/SportsDesk/Resources/Info-tvOS.plist";
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sportsdesk.SportsDesk.tvos;
				PRODUCT_NAME = SportsDesk;
				SDKROOT = appletvos;
				SUPPORTED_PLATFORMS = "appletvos appletvsimulator";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 3;
				TVOS_DEPLOYMENT_TARGET = 17.0;
			}};
			name = Debug;
		}};
		{IDS['tv_release']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Apps/SportsDesk/Resources/SportsDesk.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = "Apps/SportsDesk/Resources/Info-tvOS.plist";
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.sportsdesk.SportsDesk.tvos;
				PRODUCT_NAME = SportsDesk;
				SDKROOT = appletvos;
				SUPPORTED_PLATFORMS = "appletvos appletvsimulator";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 6.0;
				TARGETED_DEVICE_FAMILY = 3;
				TVOS_DEPLOYMENT_TARGET = 17.0;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{IDS['project_configs']} /* Build configuration list for PBXProject "SportsDesk" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{IDS['project_debug']} /* Debug */,
				{IDS['project_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{IDS['ios_configs']} /* Build configuration list for PBXNativeTarget "SportsDesk" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{IDS['ios_debug']} /* Debug */,
				{IDS['ios_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{IDS['tv_configs']} /* Build configuration list for PBXNativeTarget "SportsDeskTV" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{IDS['tv_debug']} /* Debug */,
				{IDS['tv_release']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{IDS['package']} /* XCLocalSwiftPackageReference */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = .;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{IDS['ios_product_dep']} /* SportsDeskCore */ = {{
			isa = XCSwiftPackageProductDependency;
			productName = SportsDeskCore;
		}};
		{IDS['tv_product_dep']} /* SportsDeskCore */ = {{
			isa = XCSwiftPackageProductDependency;
			productName = SportsDeskCore;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {IDS['project']} /* Project object */;
}}
"""

out = ROOT / "SportsDesk.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(pbx)
print(f"Wrote {out} ({out.stat().st_size} bytes)")

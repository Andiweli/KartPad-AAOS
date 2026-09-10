#import "../mobile/KartPadPrivateServerSettings.h"
#import "kartpad_mobile_runtime_host.h"

#import "KartPadClassicInput.h"
#import "KartPadDiscExtractor.h"
#import "KartPadMenuButton.h"
#import "KartPadFloatingStick.h"
#import "KartPadMotionSteering.h"
#import "KartPadPhysicalControllers.h"
#import "KartPadRetroRewindInstaller.h"
#import "KartPadMiiManager.h"
#import "SunPadDiagnostics.h"
#import "SunPadGameOverlay.h"
#import "SunPadInputMixer.h"
#import "SunPadSettings.h"
#include "audio_backend.h"

#import <SDL3/SDL_properties.h>
#import <SDL3/SDL_video.h>
#import <CommonCrypto/CommonDigest.h>
#import <QuartzCore/QuartzCore.h>
#import <TargetConditionals.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <algorithm>
#include <cmath>

extern "C" int g_gxFrameCount;

@interface KartPadRuntimeOverlayHost : NSObject <SunPadGameOverlayDelegate,
                                                 UIDocumentPickerDelegate>
- (instancetype)initWithSDLWindow:(SDL_Window *)window;
- (void)uninstall;
- (void)reattachOverlayIfNeeded;
- (void)runMainMenu;
@end

@interface KartPadGameOverlay : SunPadGameOverlay
@property(nonatomic, strong) KartPadFloatingStickView *kartPadMoveStick;
@property(nonatomic, copy) void (^multiplayerRequested)(void);
@property(nonatomic, copy) void (^mainMenuRequested)(void);
@property(nonatomic, copy) void (^motionSteeringRequested)(void);
@property(nonatomic, copy) void (^miiManagerRequested)(void);
@property(nonatomic, copy) void (^wiimoteRequested)(void);
@property(nonatomic, weak) UIButton *kartPadGasButton;
@property(nonatomic, strong) UIColor *kartPadGasRestColor;
@property(nonatomic, assign) NSUInteger kartPadGasHoldGeneration;
@property(nonatomic, assign) BOOL kartPadGasPressed;
@property(nonatomic, assign) BOOL kartPadGasLocked;
@property(nonatomic, assign) BOOL kartPadGasHoldSelfTestStarted;
@property(nonatomic, assign) BOOL kartPadGasInputSelfTestStarted;
@property(nonatomic, assign) BOOL kartPadModalInputSelfTestStarted;
@property(nonatomic, assign) BOOL kartPadEditorUITestStarted;
@property(nonatomic, weak) UIButton *kartPadVisibilityButton;
@property(nonatomic, copy) NSString *kartPadSelectedControlIdentifier;
- (void)resetKartPadControlAppearance;
@end

// KartPad keeps SunPad's pinned implementation byte-identical. This narrow
// declaration lets the owning subclass replace Sunshine's analog FLUDD
// pressure semantics with Mario Kart Wii's ordinary digital Classic R button.
@interface SunPadGameOverlay (KartPadControlHooks)
- (SunPadStickView *)makeStick;
- (void)stickChanged:(SunPadStickView *)stick x:(float)x y:(float)y;
- (void)rPressureChanged:(uint8_t)pressure fullPress:(BOOL)fullPress;
- (void)clearTouchInput;
- (void)buttonDown:(UIButton *)button;
- (void)endLayoutEditing;
- (void)finishLayoutEditing;
- (void)refreshMenuButton;
- (void)resetLayout;
- (void)toggleSettingsPanel;
- (void)selectControlForEditing:(UIView *)control;
- (void)reportProblem;
- (void)createDiagnosticReportFromPrompt:(UIAlertController *)prompt
                              openGitHub:(BOOL)openGitHub;
- (void)openGitHubReportWithID:(NSString *)reportID
                       answers:(NSDictionary<NSString *, NSString *> *)answers;
@end

namespace {

KartPadRuntimeOverlayHost *gRuntimeOverlayHost = nil;
BOOL gKartPadRetroRewindSelected = NO;
BOOL gKartPadMainMenuRequested = NO;
NSString *const kKartPadRequestedRuntimeProfileKey =
    @"KartPadRequestedRuntimeProfile";
NSString *const kKartPadHiddenTouchControlsKey =
    @"KartPadHiddenTouchControls";

void KartPadSeedTouchLayoutDefaults(BOOL force) {
  BOOL tablet = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  BOOL changed = NO;
  if (force || [defaults dictionaryForKey:@"SunPadControlOrigins"] == nil) {
    // iPad layout accepted by the maintainer on the physical iPad, 2026-09-07.
    NSDictionary *origins = tablet ? @{
      @"move": NSStringFromCGPoint(CGPointMake(0.14756954612005857, 0.91391391391391397)),
      @"c": NSStringFromCGPoint(CGPointMake(0.90377745241581253, 0.87147147147147153)),
      @"X": NSStringFromCGPoint(CGPointMake(0.1290190336749634, 0.66706706706706709)),
      @"Y": NSStringFromCGPoint(CGPointMake(0.062562225475841865, 0.6820520520520521)),
      @"A": NSStringFromCGPoint(CGPointMake(0.90181551976573948, 0.74799799799799804)),
      @"B": NSStringFromCGPoint(CGPointMake(0.82915080527086371, 0.81399399399399397)),
      @"R": NSStringFromCGPoint(CGPointMake(0.80767935578330885, 0.72758758758758757)),
      @"L": NSStringFromCGPoint(CGPointMake(0.91096632503660335, 0.64904904904904903)),
      @"Z": NSStringFromCGPoint(CGPointMake(0.83304538799414352, 0.65063063063063065)),
      @"Start": NSStringFromCGPoint(CGPointMake(0.95537335285505121, 0.57607607607607603)),
    } : @{
      @"L" : NSStringFromCGPoint(CGPointMake(0.93580568318565682,
                                               0.42246621616846858)),
      @"R" : NSStringFromCGPoint(CGPointMake(0.8208055524263117,
                                               0.5224662162495497)),
      @"X" : NSStringFromCGPoint(CGPointMake(0.12563888892222205,
                                               0.53485360360900902)),
      @"Y" : NSStringFromCGPoint(CGPointMake(0.055472222222222207,
                                               0.56739864864054057)),
      @"Z" : NSStringFromCGPoint(CGPointMake(0.84591666666666665,
                                               0.3783220720432432)),
    };
    [defaults setObject:origins forKey:@"SunPadControlOrigins"];
    changed = YES;
  }
  if (force || [defaults objectForKey:kKartPadHiddenTouchControlsKey] == nil) {
    [defaults setObject:@[@"ExperimentalDPad"] forKey:kKartPadHiddenTouchControlsKey];
    changed = YES;
  }
  if (force || [defaults dictionaryForKey:@"SunPadControlSizeScales"] == nil) {
    NSDictionary<NSString *, NSNumber *> *scales = tablet ? @{
      @"A": @1.2150695323944092,
      @"B": @1.2253857851028442,
      @"L": @0.9791940450668335,
      @"R": @0.6000000238418579,
      @"X": @1.257727861404419,
      @"Y": @1.3797838687896729,
      @"Z": @1.2058641910552979,
    } : @{@"L": @0.9791940450668335, @"R": @0.6000000238418579};
    [defaults setObject:scales forKey:@"SunPadControlSizeScales"];
    SunPadSettings *settings = SunPadSettings.sharedSettings;
    for (NSString *identifier in scales) {
      [settings setSizeScale:scales[identifier].doubleValue forControl:identifier];
    }
    changed = YES;
  }
  if (force || [defaults objectForKey:@"SunPadExperimentalDPadOrigin"] == nil) {
    [defaults setObject:NSStringFromCGPoint(
        CGPointMake(0.084500001609325415, 0.34521396397747761))
                 forKey:@"SunPadExperimentalDPadOrigin"];
    changed = YES;
  }
  if (force || [defaults objectForKey:@"SunPadExperimentalDPadScale"] == nil) {
    [defaults setDouble:0.7827200293540955
                 forKey:@"SunPadExperimentalDPadScale"];
    changed = YES;
  }
  if (changed) [defaults synchronize];
}

NSSet<NSString *> *KartPadHiddenTouchControls() {
  NSArray<NSString *> *saved = [NSUserDefaults.standardUserDefaults
      stringArrayForKey:kKartPadHiddenTouchControlsKey];
  return [NSSet setWithArray:saved ?: @[]];
}

NSString *KartPadVisibilityIdentifier(UIView *control) {
  NSString *identifier = control.accessibilityIdentifier;
  if ([identifier hasPrefix:@"D_"]) return @"ExperimentalDPad";
  return identifier;
}

BOOL KartPadViewIsEffectivelyHidden(UIView *view) {
  for (UIView *candidate = view; candidate != nil;
       candidate = candidate.superview) {
    if (candidate.hidden || candidate.alpha < 0.01) return YES;
  }
  return NO;
}

UIViewController *KartPadVisibleViewController(UIWindow *window) {
  UIViewController *controller = window.rootViewController;
  while (controller.presentedViewController != nil) {
    controller = controller.presentedViewController;
  }
  return controller;
}

UIScrollView *KartPadScrollableSettingsView(UIView *root) {
  if ([root isKindOfClass:UIScrollView.class]) {
    UIScrollView *scroll = (UIScrollView *)root;
    if (scroll.contentSize.height > CGRectGetHeight(scroll.bounds) + 1.0) {
      return scroll;
    }
  }
  for (UIView *child in root.subviews) {
    UIScrollView *found = KartPadScrollableSettingsView(child);
    if (found != nil) return found;
  }
  return nil;
}

UIView *KartPadSubviewWithAccessibilityLabel(UIView *root, NSString *label,
                                              Class viewClass) {
  if ([root isKindOfClass:viewClass] &&
      [root.accessibilityLabel isEqualToString:label]) {
    return root;
  }
  for (UIView *child in root.subviews) {
    UIView *found = KartPadSubviewWithAccessibilityLabel(child, label,
                                                          viewClass);
    if (found != nil) return found;
  }
  return nil;
}

NSString *KartPadSupportRoot() {
  return [[NSHomeDirectory() stringByAppendingPathComponent:
      @"Library/Application Support"] stringByAppendingPathComponent:@"KartPad"];
}

NSURL *KartPadDocumentsRoot(NSError **error) {
  NSURL *documents = [NSFileManager.defaultManager
      URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
  if (documents == nil) return nil;
  if (![NSFileManager.defaultManager createDirectoryAtURL:documents
                              withIntermediateDirectories:YES attributes:nil
                                                   error:error]) {
    return nil;
  }
  return documents;
}

NSString *KartPadDocumentsFolderScanDetail(NSError *error) {
  NSString *device = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
      ? @"iPad" : @"iPhone";
  NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
  if (bundleIdentifier.length == 0) bundleIdentifier = @"unknown";
  NSString *reason = error == nil
      ? @"No compatible WBFS, ISO, or extracted DATA folder was found."
      : [NSString stringWithFormat:@"KartPad could not read this folder: %@",
                                   error.localizedDescription];
  return [NSString stringWithFormat:
      @"%@\n\nKartPad can scan only this signed app's own On My %@ folder. "
       "If a signer changes the bundle identifier or its protection suffix, "
       "iOS creates a different folder. Move the game into the newly installed "
       "KartPad folder or choose it directly from Files.\n\nSigned app ID: %@",
      reason, device, bundleIdentifier];
}

NSString *KartPadRemovalMarkerPath() {
  return [KartPadSupportRoot() stringByAppendingPathComponent:
      @"RemoveGameDataOnNextLaunch"];
}

BOOL KartPadRetroVersionIsValid(NSString *version) {
  NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
  if (parts.count < 2 || parts.count > 4) return NO;
  NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
  for (NSString *part in parts) {
    if (part.length == 0 || [part rangeOfCharacterFromSet:nonDigits].location !=
                                NSNotFound) {
      return NO;
    }
  }
  return YES;
}

NSString *KartPadLatestRetroVersionFromManifest(NSData *data) {
  if (data.length == 0 || data.length > 512 * 1024) return nil;
  NSString *text = [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding];
  if (text == nil) return nil;
  NSString *latest = nil;
  NSCharacterSet *whitespace = NSCharacterSet.whitespaceCharacterSet;
  for (NSString *line in
       [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
    NSString *trimmed = [line
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) continue;
    NSString *version = nil;
    for (NSString *token in
         [trimmed componentsSeparatedByCharactersInSet:whitespace]) {
      if (token.length > 0) {
        version = token;
        break;
      }
    }
    if (!KartPadRetroVersionIsValid(version)) return nil;
    if (latest == nil ||
        [latest compare:version options:NSNumericSearch] == NSOrderedAscending) {
      latest = version;
    }
  }
  return latest;
}

NSString *KartPadSHA256ForFile(NSString *path, NSError **error) {
  NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe
                                         error:error];
  if (data == nil || data.length > UINT32_MAX) {
    return nil;
  }
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) {
    [result appendFormat:@"%02x", digest[index]];
  }
  return result;
}

NSString *KartPadResolvedExtractedRoot(NSURL *selectedURL) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSArray<NSString *> *candidates = @[
    selectedURL.path,
    [selectedURL.path stringByAppendingPathComponent:@"DATA"],
    [selectedURL.path stringByAppendingPathComponent:@"GameData"],
  ];
  for (NSString *candidate in candidates) {
    BOOL directory = NO;
    if ([files fileExistsAtPath:[candidate stringByAppendingPathComponent:@"files"]
                    isDirectory:&directory] && directory &&
        [files fileExistsAtPath:[candidate stringByAppendingPathComponent:@"sys/fst.bin"]]) {
      return candidate;
    }
  }
  return nil;
}

BOOL KartPadURLIsSupportedDiscImage(NSURL *url) {
  if (url == nil || !url.isFileURL) return NO;
  NSString *extension = url.pathExtension.lowercaseString;
  return [extension isEqualToString:@"wbfs"] ||
         [extension isEqualToString:@"iso"];
}

NSArray<UTType *> *KartPadGameDataContentTypes() {
  // File providers disagree about ISO/WBFS identifiers. Include both broad
  // bases and the system disk-image/folder types, then rely on KartPad's
  // extension, disc-header, revision, and extracted-tree validation.
  return @[UTTypeItem, UTTypeData, UTTypeDiskImage, UTTypeFolder];
}

NSArray<NSURL *> *KartPadGameDataRootsInDocuments(NSError **error) {
  NSURL *documents = KartPadDocumentsRoot(error);
  if (documents == nil) return @[];
  NSArray<NSURL *> *entries = [NSFileManager.defaultManager
      contentsOfDirectoryAtURL:documents
    includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                       options:NSDirectoryEnumerationSkipsHiddenFiles error:error];
  if (entries == nil) return @[];
  NSMutableArray<NSURL *> *roots = [NSMutableArray array];
  for (NSURL *entry in entries) {
    // Check the user-visible extension first. Some Files providers report disc
    // images as packages/directories even though their bytes are readable as a
    // normal file. The extractor remains the authority after selection.
    if (KartPadURLIsSupportedDiscImage(entry)) {
      [roots addObject:entry];
      continue;
    }
    NSNumber *directory = nil;
    [entry getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
    if (directory.boolValue && KartPadResolvedExtractedRoot(entry) != nil) {
      [roots addObject:entry];
    }
  }
  [roots sortUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
    return [left.lastPathComponent localizedStandardCompare:right.lastPathComponent];
  }];
  return roots;
}

NSString *KartPadValidateExtractedRoot(NSString *root, NSError **error) {
  if (root.length == 0) {
    return @"Choose an extracted Mario Kart Wii DATA folder containing files/ and sys/.";
  }
  NSArray<NSString *> *required = @[
    @"sys/boot.bin", @"sys/bi2.bin", @"sys/apploader.img", @"sys/fst.bin",
    @"sys/main.dol", @"files/rel/StaticR.rel",
  ];
  NSFileManager *files = NSFileManager.defaultManager;
  for (NSString *relative in required) {
    if (![files fileExistsAtPath:[root stringByAppendingPathComponent:relative]]) {
      return [NSString stringWithFormat:@"The extracted game data is incomplete (missing %@).",
                                        relative];
    }
  }

  NSData *boot = [NSData dataWithContentsOfFile:
      [root stringByAppendingPathComponent:@"sys/boot.bin"] options:0 error:error];
  if (boot == nil) {
    return @"KartPad could not read sys/boot.bin.";
  }
  if (boot.length < 0x20) {
    return @"The selected sys/boot.bin is truncated.";
  }
  const uint8_t *bytes = static_cast<const uint8_t *>(boot.bytes);
  if (memcmp(bytes, "RMCP01", 6) != 0 || bytes[6] != 0 || bytes[7] != 0) {
    return @"KartPad currently supports RMCP01 (PAL), disc 0, revision 0 only.";
  }
  const uint32_t magic = (static_cast<uint32_t>(bytes[0x18]) << 24) |
                         (static_cast<uint32_t>(bytes[0x19]) << 16) |
                         (static_cast<uint32_t>(bytes[0x1A]) << 8) |
                         static_cast<uint32_t>(bytes[0x1B]);
  if (magic != 0x5D1C9EA3u) {
    return @"The selected folder does not contain a valid extracted Wii disc header.";
  }

  NSString *dolHash = KartPadSHA256ForFile(
      [root stringByAppendingPathComponent:@"sys/main.dol"], error);
  if (dolHash == nil) {
    return @"KartPad could not hash sys/main.dol.";
  }
  if (![dolHash isEqualToString:
      @"80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"]) {
    return @"sys/main.dol does not match the supported RMCP01 revision 0 profile.";
  }
  return nil;
}

BOOL KartPadEnsureRelativeRuntimePath(NSString *key, NSString *value,
                                     NSError **error) {
  NSString *configPath = [KartPadSupportRoot() stringByAppendingPathComponent:@"Config.toml"];
  NSError *readError = nil;
  NSString *config = [NSString stringWithContentsOfFile:configPath
                                               encoding:NSUTF8StringEncoding
                                                  error:&readError];
  if (config == nil) {
    if ([NSFileManager.defaultManager fileExistsAtPath:configPath]) {
      if (error != nullptr) {
        *error = readError;
      }
      return NO;
    }
    config = @"";
  }
  NSString *linePattern = [NSString stringWithFormat:
      @"(?m)^\\s*#?\\s*%@\\s*=.*$",
      [NSRegularExpression escapedPatternForString:key]];
  NSRegularExpression *pathLine = [NSRegularExpression
      regularExpressionWithPattern:linePattern
                           options:0 error:error];
  if (pathLine == nil) {
    return NO;
  }
  NSRange whole = NSMakeRange(0, config.length);
  config = [pathLine stringByReplacingMatchesInString:config options:0 range:whole
                                          withTemplate:@""];
  NSRegularExpression *paths = [NSRegularExpression
      regularExpressionWithPattern:@"(?m)^\\s*\\[paths\\]\\s*$"
                           options:0 error:error];
  if (paths == nil) {
    return NO;
  }
  NSTextCheckingResult *match =
      [paths firstMatchInString:config options:0 range:NSMakeRange(0, config.length)];
  if (match != nil) {
    NSUInteger insertion = NSMaxRange(match.range);
    config = [config stringByReplacingCharactersInRange:NSMakeRange(insertion, 0)
                                              withString:[NSString stringWithFormat:
                                                  @"\n%@ = \"%@\"", key, value]];
  } else {
    config = [config stringByAppendingFormat:
        @"\n\n[paths]\n%@ = \"%@\"\n", key, value];
  }
  return [config writeToFile:configPath atomically:YES
                    encoding:NSUTF8StringEncoding error:error];
}

BOOL KartPadEnsureRelativeDvdRoot(NSError **error) {
  return KartPadEnsureRelativeRuntimePath(@"dvd_root", @"GameData", error);
}

BOOL KartPadEnsureRelativeRetroRewindRoot(NSError **error) {
  return KartPadEnsureRelativeRuntimePath(
      @"retro_rewind_root", @"RetroRewind/RetroRewind6", error);
}

BOOL KartPadInstalledRetroRewindIsValid() {
  if (![KartPadRetroRewindInstaller isInstalled]) return NO;
  NSError *error = nil;
  return KartPadEnsureRelativeRetroRewindRoot(&error) && error == nil;
}

void KartPadRemoveStaleImportDirectories(NSString *supportRoot) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil];
  for (NSString *entry in entries) {
    if ([entry hasPrefix:@"GameData.import-"]) {
      [files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                        error:nil];
    }
  }
}

NSError *KartPadGameDataError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:@"dev.kartpad.gamedata" code:code userInfo:@{
    NSLocalizedDescriptionKey: message,
  }];
}

NSError *KartPadApplyScheduledGameDataRemoval() {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *marker = KartPadRemovalMarkerPath();
  if (![files fileExistsAtPath:marker]) {
    return nil;
  }

  NSString *supportRoot = KartPadSupportRoot();
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  for (NSString *entry in entries) {
    if ([entry isEqualToString:@"GameData"] ||
        [entry hasPrefix:@"GameData.import-"] ||
        [entry hasPrefix:@"GameData.rollback-"]) {
      NSError *error = nil;
      if (![files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                            error:&error]) {
        return error ?: KartPadGameDataError(4, @"Could not remove stored game data.");
      }
    }
  }
  NSError *markerError = nil;
  if (![files removeItemAtPath:marker error:&markerError]) {
    return markerError ?: KartPadGameDataError(5, @"Could not finish game-data removal.");
  }

  SunPadSettings *settings = SunPadSettings.sharedSettings;
  settings.retainedGameDataPath = nil;
  settings.extractedGameRoot = nil;
  [settings synchronize];
  return nil;
}

void KartPadRecoverInterruptedImport(NSString *supportRoot) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *dataDirectory = [supportRoot stringByAppendingPathComponent:@"GameData"];
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  NSMutableArray<NSString *> *rollbacks = [NSMutableArray array];
  for (NSString *entry in entries) {
    if ([entry hasPrefix:@"GameData.rollback-"]) {
      [rollbacks addObject:entry];
    }
  }
  [rollbacks sortUsingSelector:@selector(compare:)];
  if (![files fileExistsAtPath:dataDirectory] && rollbacks.count == 1) {
    NSString *rollback = [supportRoot stringByAppendingPathComponent:rollbacks.firstObject];
    [files moveItemAtPath:rollback toPath:dataDirectory error:nil];
  }
  KartPadRemoveStaleImportDirectories(supportRoot);
}

void KartPadRemoveRollbackDirectories(NSString *supportRoot) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  for (NSString *entry in entries) {
    if ([entry hasPrefix:@"GameData.rollback-"]) {
      [files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                        error:nil];
    }
  }
}

BOOL KartPadInstalledGameDataIsValid() {
  NSString *supportRoot = KartPadSupportRoot();
  KartPadRecoverInterruptedImport(supportRoot);
  NSString *dataDirectory = [supportRoot stringByAppendingPathComponent:@"GameData"];
  NSError *error = nil;
  if (KartPadValidateExtractedRoot(dataDirectory, &error) != nil || error != nil) {
    return NO;
  }
  if (!KartPadEnsureRelativeDvdRoot(&error) || error != nil) {
    return NO;
  }
  KartPadRemoveRollbackDirectories(supportRoot);
  return YES;
}

NSError *KartPadPerformGameDataImport(NSURL *url,
                                      KartPadDiscExtractionProgress progress) {
  BOOL securityScoped = [url startAccessingSecurityScopedResource];
  NSError *workError = nil;
  NSString *supportRoot = KartPadSupportRoot();
  NSString *staging = [supportRoot stringByAppendingPathComponent:
      [NSString stringWithFormat:@"GameData.import-%@", NSUUID.UUID.UUIDString]];
  NSFileManager *files = NSFileManager.defaultManager;
  [files createDirectoryAtPath:supportRoot withIntermediateDirectories:YES
                     attributes:@{NSFileProtectionKey:
                         NSFileProtectionCompleteUntilFirstUserAuthentication}
                          error:&workError];
  if (workError == nil) {
    KartPadRecoverInterruptedImport(supportRoot);
    if (KartPadURLIsSupportedDiscImage(url)) {
      [KartPadDiscExtractor extractImageAtPath:url.path toDirectory:staging
                                      progress:progress error:&workError];
    } else {
      NSString *sourceRoot = KartPadResolvedExtractedRoot(url);
      NSString *validationError = KartPadValidateExtractedRoot(sourceRoot, &workError);
      if (validationError != nil && workError == nil) {
        workError = KartPadGameDataError(1, validationError);
      }
      if (workError == nil) {
        [files copyItemAtPath:sourceRoot toPath:staging error:&workError];
      }
    }
  }
  if (securityScoped) {
    [url stopAccessingSecurityScopedResource];
  }

  if (workError == nil) {
    NSString *validationError = KartPadValidateExtractedRoot(staging, &workError);
    if (validationError != nil && workError == nil) {
      workError = KartPadGameDataError(1, validationError);
    }
  }

  if (workError == nil && !KartPadEnsureRelativeDvdRoot(&workError)) {
    workError = workError ?: KartPadGameDataError(2, @"Could not update Config.toml.");
  }

  NSString *dataDirectory = [supportRoot stringByAppendingPathComponent:@"GameData"];
  NSString *rollback = [supportRoot stringByAppendingPathComponent:
      [NSString stringWithFormat:@"GameData.rollback-%@", NSUUID.UUID.UUIDString]];
  BOOL movedExisting = NO;
  if (workError == nil && [files fileExistsAtPath:dataDirectory]) {
    movedExisting = [files moveItemAtPath:dataDirectory toPath:rollback error:&workError];
  }
#if TARGET_OS_SIMULATOR
  if (workError == nil &&
      [NSProcessInfo.processInfo.environment[@"KARTPAD_IMPORT_FORCE_SWAP_FAILURE"] boolValue]) {
    workError = KartPadGameDataError(3, @"Injected Simulator swap failure.");
  }
#endif
  if (workError == nil) {
    [files moveItemAtPath:staging toPath:dataDirectory error:&workError];
  }
  if (workError != nil && movedExisting && ![files fileExistsAtPath:dataDirectory]) {
    [files moveItemAtPath:rollback toPath:dataDirectory error:nil];
  } else if (workError == nil && movedExisting) {
    [files removeItemAtPath:rollback error:nil];
  }
  if (workError != nil) {
    [files removeItemAtPath:staging error:nil];
    return workError;
  }

  NSURL *dataURL = [NSURL fileURLWithPath:dataDirectory isDirectory:YES];
  [dataURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
  [files setAttributes:@{NSFileProtectionKey:
      NSFileProtectionCompleteUntilFirstUserAuthentication}
             ofItemAtPath:dataDirectory error:nil];
  KartPadRemoveRollbackDirectories(supportRoot);
  SunPadSettings *settings = SunPadSettings.sharedSettings;
  settings.retainedGameDataPath = nil;
  settings.extractedGameRoot = dataDirectory;
  [settings synchronize];
  return nil;
}

}  // namespace

@interface KartPadFirstLaunchViewController : UIViewController
@property(nonatomic, copy) void (^modeSelected)(BOOL retroRewind);
@property(nonatomic, assign) BOOL resumingGame;
@property(nonatomic, assign) BOOL currentRetroRewind;
@property(nonatomic, strong) CAGradientLayer *backgroundGradient;
@property(nonatomic, strong) NSLayoutConstraint *contentWidthConstraint;
@end

@implementation KartPadFirstLaunchViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.blackColor;
  CAGradientLayer *gradient = [CAGradientLayer layer];
  gradient.colors = @[
    (__bridge id)[UIColor colorWithRed:0.025 green:0.075 blue:0.15 alpha:1.0].CGColor,
    (__bridge id)[UIColor colorWithRed:0.10 green:0.055 blue:0.18 alpha:1.0].CGColor,
    (__bridge id)[UIColor colorWithRed:0.18 green:0.045 blue:0.08 alpha:1.0].CGColor,
  ];
  gradient.startPoint = CGPointMake(0.0, 0.0);
  gradient.endPoint = CGPointMake(1.0, 1.0);
  [self.view.layer insertSublayer:gradient atIndex:0];
  self.backgroundGradient = gradient;

  UIImage *markImage = [UIImage systemImageNamed:@"steeringwheel"] ?:
      [UIImage systemImageNamed:@"flag.checkered"];
  UIImageView *mark = [[UIImageView alloc] initWithImage:markImage];
  mark.translatesAutoresizingMaskIntoConstraints = NO;
  mark.contentMode = UIViewContentModeScaleAspectFit;
  mark.tintColor = [UIColor colorWithRed:1.0 green:0.42 blue:0.18 alpha:1.0];
  mark.accessibilityLabel = @"KartPad";
  [NSLayoutConstraint activateConstraints:@[
    [mark.widthAnchor constraintEqualToConstant:48.0],
    [mark.heightAnchor constraintEqualToConstant:48.0],
  ]];

  UILabel *title = [[UILabel alloc] init];
  title.translatesAutoresizingMaskIntoConstraints = NO;
  title.text = @"KartPad";
  title.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightBold];
  title.textAlignment = NSTextAlignmentCenter;
  title.textColor = UIColor.whiteColor;

  UILabel *tagline = [[UILabel alloc] init];
  tagline.translatesAutoresizingMaskIntoConstraints = NO;
  tagline.text = @"Choose your way to race";
  tagline.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
  tagline.textColor = [UIColor colorWithWhite:1.0 alpha:0.88];
  tagline.textAlignment = NSTextAlignmentCenter;

  UILabel *message = [[UILabel alloc] init];
  message.translatesAutoresizingMaskIntoConstraints = NO;
  message.text = self.resumingGame
      ? @"Your current game is paused. Resume it below. Switching games requires closing and reopening KartPad."
      : @"Your own RMCP01 disc image or extracted game data is required before play.";
  message.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  message.textColor = [UIColor colorWithWhite:1.0 alpha:0.62];
  message.textAlignment = NSTextAlignmentCenter;
  message.numberOfLines = 0;

  UIButtonConfiguration *originalConfiguration =
      [UIButtonConfiguration filledButtonConfiguration];
  originalConfiguration.title = @"Mario Kart Wii";
  originalConfiguration.subtitle = @"Original game";
  if (self.resumingGame) {
    originalConfiguration.title = self.currentRetroRewind ? @"Mario Kart Wii" : @"Resume Mario Kart Wii";
    originalConfiguration.subtitle = self.currentRetroRewind ? @"Switch on next launch" : @"Current game • Paused";
  }
  originalConfiguration.image = [UIImage systemImageNamed:@"flag.checkered"];
  originalConfiguration.imagePadding = 12.0;
  originalConfiguration.baseBackgroundColor =
      [UIColor colorWithRed:0.03 green:0.49 blue:1.0 alpha:1.0];
  originalConfiguration.baseForegroundColor = UIColor.whiteColor;
  originalConfiguration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
  originalConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(24, 28, 24, 28);
  UIButton *original = [UIButton buttonWithConfiguration:originalConfiguration
                                           primaryAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
    (void)action;
    if (self.modeSelected != nil) self.modeSelected(NO);
  }]];
  original.accessibilityIdentifier = @"kartpad.mode.original";

  UIButtonConfiguration *retroConfiguration =
      [UIButtonConfiguration filledButtonConfiguration];
  retroConfiguration.title = @"Retro Rewind";
  NSString *installedVersion = KartPadRetroRewindInstaller.installedVersion;
  retroConfiguration.subtitle = installedVersion.length > 0
      ? [NSString stringWithFormat:@"Installed %@ • Extra content + Retro WFC",
                                   installedVersion]
      : [NSString stringWithFormat:@"Download %@ • Extra content + Retro WFC",
                                   KartPadRetroRewindInstaller.requiredVersion];
  if (self.resumingGame) {
    retroConfiguration.title = self.currentRetroRewind ? @"Resume Retro Rewind" : @"Retro Rewind";
    retroConfiguration.subtitle = self.currentRetroRewind ? @"Current game • Paused" : @"Switch on next launch";
  }
  retroConfiguration.image = [UIImage systemImageNamed:@"gobackward"];
  retroConfiguration.imagePadding = 12.0;
  retroConfiguration.baseBackgroundColor =
      [UIColor colorWithRed:0.96 green:0.22 blue:0.39 alpha:1.0];
  retroConfiguration.baseForegroundColor = UIColor.whiteColor;
  retroConfiguration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
  retroConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(24, 28, 24, 28);
  UIButton *retro = [UIButton buttonWithConfiguration:retroConfiguration
                                        primaryAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
    (void)action;
    if (self.modeSelected != nil) self.modeSelected(YES);
  }]];
  retro.accessibilityIdentifier = @"kartpad.mode.retro-rewind";

  UIStackView *choices = [[UIStackView alloc] initWithArrangedSubviews:@[original, retro]];
  choices.axis = UILayoutConstraintAxisHorizontal;
  choices.spacing = 18.0;
  choices.distribution = UIStackViewDistributionFillEqually;

  UIStackView *stack =
      [[UIStackView alloc] initWithArrangedSubviews:
          @[mark, title, tagline, message, choices]];
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 12.0;
  [stack setCustomSpacing:24.0 afterView:message];
  [self.view addSubview:stack];
  self.contentWidthConstraint =
      [stack.widthAnchor constraintEqualToConstant:320.0];
  [NSLayoutConstraint activateConstraints:@[
    [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [stack.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor
                                        constant:-18.0],
    self.contentWidthConstraint,
  ]];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  self.backgroundGradient.frame = self.view.bounds;
  const UIEdgeInsets insets = self.view.safeAreaInsets;
  const CGFloat availableWidth = CGRectGetWidth(self.view.bounds) -
      insets.left - insets.right - 64.0;
  self.contentWidthConstraint.constant =
      MIN(760.0, MAX(320.0, availableWidth));
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskLandscape;
}

@end

@interface KartPadFirstLaunchHost : NSObject <UIDocumentPickerDelegate,
                                               NSURLSessionDownloadDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) KartPadFirstLaunchViewController *root;
@property(nonatomic, strong) NSURLSession *retroDownloadSession;
@property(nonatomic, strong) NSURLSessionDownloadTask *retroDownloadTask;
@property(nonatomic, strong) NSURLSessionDataTask *retroVersionTask;
@property(nonatomic, strong) UIAlertController *retroProgressAlert;
@property(nonatomic, assign) BOOL finished;
@property(nonatomic, assign) BOOL succeeded;
@property(nonatomic, assign) BOOL selectedRetroRewind;
@property(nonatomic, assign) BOOL choosingRetroArchive;
@property(nonatomic, assign) BOOL choosingGameDataCopy;
@property(nonatomic, assign) BOOL receivedRetroDownload;
@property(nonatomic, assign) BOOL retroVersionChecked;
@property(nonatomic, assign) NSInteger lastRetroDownloadPercent;
- (BOOL)run;
- (void)showOptions;
- (void)presentGameDataPicker;
- (void)showRetroRewindOptions;
- (void)checkRetroRewindVersionAndContinue;
- (void)showRetroVersionCheckFailure:(NSString *)detail;
- (void)showKartPadUpdateRequiredForRetroVersion:(NSString *)latest;
@end

@implementation KartPadFirstLaunchHost

- (UIWindowScene *)availableWindowScene {
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if ([scene isKindOfClass:UIWindowScene.class]) {
      return (UIWindowScene *)scene;
    }
  }
  return nil;
}

- (void)showMessage:(NSString *)title
             detail:(NSString *)detail
         completion:(void (^)(void))completion {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title message:detail
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
    (void)action;
    if (completion != nil) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), completion);
    }
  }]];
  [self.root presentViewController:alert animated:YES completion:nil];
}

- (void)showRetroVersionCheckFailure:(NSString *)detail {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Could Not Check for Updates"
                       message:detail
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Try Again"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self checkRetroRewindVersionAndContinue];
    });
  }]];
  if (KartPadInstalledRetroRewindIsValid()) {
    [alert addAction:[UIAlertAction actionWithTitle:@"Launch Installed Version"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
      (void)action;
      self.retroVersionChecked = YES;
      [self completeSelectedMode];
    }]];
  }
  [alert addAction:[UIAlertAction actionWithTitle:@"Back"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [self.root presentViewController:alert animated:YES completion:nil];
}

- (void)showKartPadUpdateRequiredForRetroVersion:(NSString *)latest {
  NSString *message = [NSString stringWithFormat:
      @"Retro Rewind %@ was released after this KartPad build, which supports %@. Retro Rewind changed executable code that KartPad must translate ahead of time, so a matching KartPad release is required before installing the new pack or playing online. Original Mario Kart Wii remains available.",
      latest, KartPadRetroRewindInstaller.requiredVersion];
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Retro Rewind Update Needed"
                       message:message
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"View KartPad Releases"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSURL *url = [NSURL URLWithString:
        @"https://github.com/chrissotraidis/kartpad/releases"];
    [UIApplication.sharedApplication openURL:url options:@{}
                            completionHandler:nil];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Back"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [self.root presentViewController:alert animated:YES completion:nil];
}

- (void)checkRetroRewindVersionAndContinue {
  UIAlertController *progress = [UIAlertController
      alertControllerWithTitle:@"Checking Retro Rewind"
                       message:@"Checking the official current version…"
                preferredStyle:UIAlertControllerStyleAlert];
  [self.root presentViewController:progress animated:YES completion:nil];

  NSMutableURLRequest *request = [NSMutableURLRequest
      requestWithURL:KartPadRetroRewindInstaller.officialVersionManifestURL
         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
     timeoutInterval:15.0];
  __weak KartPadFirstLaunchHost *weakSelf = self;
  NSURLSessionConfiguration *configuration =
      NSURLSessionConfiguration.ephemeralSessionConfiguration;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  self.retroVersionTask = [session
      dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    [session finishTasksAndInvalidate];
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class]
        ? (NSHTTPURLResponse *)response : nil;
    NSString *latest = error == nil && http.statusCode == 200
        ? KartPadLatestRetroVersionFromManifest(data) : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadFirstLaunchHost *strongSelf = weakSelf;
      if (strongSelf == nil) return;
      strongSelf.retroVersionTask = nil;
      [progress dismissViewControllerAnimated:YES completion:^{
        if (latest == nil) {
          NSString *detail = error.localizedDescription ?:
              @"The official Retro Rewind version feed returned an invalid response. Online play requires the current release.";
          [strongSelf showRetroVersionCheckFailure:detail];
          return;
        }
        NSString *supported = KartPadRetroRewindInstaller.requiredVersion;
        if ([supported compare:latest options:NSNumericSearch] ==
            NSOrderedAscending) {
          [strongSelf showKartPadUpdateRequiredForRetroVersion:latest];
          return;
        }
        strongSelf.retroVersionChecked = YES;
        [strongSelf completeSelectedMode];
      }];
    });
  }];
  [self.retroVersionTask resume];
}

- (void)completeSelectedMode {
  if (!KartPadInstalledGameDataIsValid()) {
    [self showOptions];
    return;
  }
  if (self.selectedRetroRewind && !self.retroVersionChecked) {
    [self checkRetroRewindVersionAndContinue];
    return;
  }
  if (self.selectedRetroRewind && !KartPadInstalledRetroRewindIsValid()) {
    [self showRetroRewindOptions];
    return;
  }
  gKartPadRetroRewindSelected = self.selectedRetroRewind;
  self.succeeded = YES;
  self.finished = YES;
}

- (void)installRetroRewindArchive:(NSURL *)archiveURL
               deletingAfterwards:(BOOL)deleteAfterwards {
  UIAlertController *progress = self.retroProgressAlert;
  if (progress == nil) {
    progress = [UIAlertController
        alertControllerWithTitle:@"Installing Retro Rewind"
                         message:@"Verifying the selected ZIP…"
                  preferredStyle:UIAlertControllerStyleAlert];
    self.retroProgressAlert = progress;
    [self.root presentViewController:progress animated:YES completion:nil];
  }
  __weak KartPadFirstLaunchHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *installError = nil;
    BOOL installed = [KartPadRetroRewindInstaller
        installArchiveAtURL:archiveURL
                   progress:^(NSString *status, double fraction) {
      dispatch_async(dispatch_get_main_queue(), ^{
        KartPadFirstLaunchHost *strongSelf = weakSelf;
        if (strongSelf.retroProgressAlert != nil) {
          strongSelf.retroProgressAlert.message = [NSString stringWithFormat:
              @"%@\n%.0f%%", status, fraction * 100.0];
        }
      });
    }
                      error:&installError];
    if (deleteAfterwards) {
      [NSFileManager.defaultManager removeItemAtURL:archiveURL error:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadFirstLaunchHost *strongSelf = weakSelf;
      if (strongSelf == nil) return;
      [strongSelf.retroProgressAlert dismissViewControllerAnimated:YES completion:^{
        strongSelf.retroProgressAlert = nil;
        if (!installed) {
          [strongSelf showMessage:@"Retro Rewind Install Failed"
                           detail:installError.localizedDescription completion:^{
            [strongSelf showRetroRewindOptions];
          }];
          return;
        }
        [strongSelf completeSelectedMode];
      }];
    });
  });
}

- (void)chooseRetroRewindArchive {
  self.choosingRetroArchive = YES;
  self.choosingGameDataCopy = NO;
  UTType *zip = [UTType typeWithFilenameExtension:@"zip"];
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:zip == nil ? @[UTTypeArchive] : @[zip]
                            asCopy:NO];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self.root presentViewController:picker animated:YES completion:nil];
}

- (void)startOfficialRetroRewindDownload {
  self.receivedRetroDownload = NO;
  self.lastRetroDownloadPercent = -1;
  UIAlertController *progress = [UIAlertController
      alertControllerWithTitle:[NSString stringWithFormat:
          @"Downloading Retro Rewind %@",
          KartPadRetroRewindInstaller.requiredVersion]
                       message:@"Starting the official full download…"
                preferredStyle:UIAlertControllerStyleAlert];
  self.retroProgressAlert = progress;
  __weak KartPadFirstLaunchHost *weakSelf = self;
  [progress addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *action) {
    (void)action;
    KartPadFirstLaunchHost *strongSelf = weakSelf;
    [strongSelf.retroDownloadTask cancel];
    strongSelf.retroProgressAlert = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [strongSelf showRetroRewindOptions];
    });
  }]];
  [self.root presentViewController:progress animated:YES completion:nil];
  NSURLSessionConfiguration *configuration =
      NSURLSessionConfiguration.defaultSessionConfiguration;
  configuration.allowsCellularAccess = YES;
  self.retroDownloadSession =
      [NSURLSession sessionWithConfiguration:configuration delegate:self
                               delegateQueue:NSOperationQueue.mainQueue];
  self.retroDownloadTask = [self.retroDownloadSession
      downloadTaskWithURL:KartPadRetroRewindInstaller.officialArchiveURL];
  [self.retroDownloadTask resume];
}

- (void)showRetroRewindOptions {
  const double gib = (double)KartPadRetroRewindInstaller.officialArchiveBytes /
                     (1024.0 * 1024.0 * 1024.0);
  UIAlertController *options = [UIAlertController
      alertControllerWithTitle:[NSString stringWithFormat:
          @"Retro Rewind %@ Required",
          KartPadRetroRewindInstaller.requiredVersion]
                       message:[NSString stringWithFormat:
          @"Retro Rewind is optional community content used for its extra tracks, characters, and Retro WFC online play. This KartPad build requires the matching official %.2f GiB full download.",
          gib]
                preferredStyle:UIAlertControllerStyleAlert];
  [options addAction:[UIAlertAction actionWithTitle:@"Download Official Pack"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self startOfficialRetroRewindDownload];
    });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Choose Full-Download ZIP…"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self chooseRetroRewindArchive];
    });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Back"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
  [self.root presentViewController:options animated:YES completion:nil];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
 totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  (void)session;
  (void)downloadTask;
  (void)bytesWritten;
  if (self.retroProgressAlert == nil) return;
  const int64_t expected = totalBytesExpectedToWrite > 0
      ? totalBytesExpectedToWrite
      : (int64_t)KartPadRetroRewindInstaller.officialArchiveBytes;
  const double fraction = expected > 0
      ? std::min(1.0, (double)totalBytesWritten / (double)expected) : 0.0;
  const NSInteger percent = (NSInteger)(100.0 * fraction);
  if (percent == self.lastRetroDownloadPercent) return;
  self.lastRetroDownloadPercent = percent;
  self.retroProgressAlert.message = [NSString stringWithFormat:
      @"Downloading the official full pack…\n%.0f%%",
      (double)percent];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didFinishDownloadingToURL:(NSURL *)location {
  (void)session;
  (void)downloadTask;
  NSString *temporaryName = [NSString stringWithFormat:
      @"KartPad-RetroRewind-%@-%@.zip",
      KartPadRetroRewindInstaller.requiredVersion, NSUUID.UUID.UUIDString];
  NSURL *temporaryURL = [NSURL fileURLWithPath:
      [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryName]];
  NSError *moveError = nil;
  [NSFileManager.defaultManager moveItemAtURL:location toURL:temporaryURL
                                        error:&moveError];
  if (moveError != nil) {
    [self.retroProgressAlert dismissViewControllerAnimated:YES completion:^{
      self.retroProgressAlert = nil;
      [self showMessage:@"Retro Rewind Download Failed"
                 detail:moveError.localizedDescription completion:^{
        [self showRetroRewindOptions];
      }];
    }];
    return;
  }
  self.receivedRetroDownload = YES;
  self.retroProgressAlert.title = @"Installing Retro Rewind";
  self.retroProgressAlert.message = @"Verifying the official download…\n0%";
  [self installRetroRewindArchive:temporaryURL deletingAfterwards:YES];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 didCompleteWithError:(NSError *)error {
  (void)task;
  [session finishTasksAndInvalidate];
  self.retroDownloadTask = nil;
  self.retroDownloadSession = nil;
  if (error == nil || self.receivedRetroDownload ||
      error.code == NSURLErrorCancelled) return;
  [self.retroProgressAlert dismissViewControllerAnimated:YES completion:^{
    self.retroProgressAlert = nil;
    [self showMessage:@"Retro Rewind Download Failed"
               detail:error.localizedDescription completion:^{
      [self showRetroRewindOptions];
    }];
  }];
}

- (void)startImport:(NSURL *)url deleteAfterwards:(BOOL)deleteAfterwards {
  UIAlertController *progress =
      [UIAlertController alertControllerWithTitle:@"Importing Game Data"
                                          message:@"Validating your selected game data…"
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self.root presentViewController:progress animated:YES completion:nil];
  __weak KartPadFirstLaunchHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *error = KartPadPerformGameDataImport(
        url, ^(NSString *status, double fraction) {
          progress.message = [NSString stringWithFormat:@"%@\n%.0f%%", status,
                                                       fraction * 100.0];
        });
    if (deleteAfterwards) {
      [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadFirstLaunchHost *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      [progress dismissViewControllerAnimated:YES completion:^{
        if (error != nil) {
          [strongSelf showMessage:@"Game Data Import Failed"
                           detail:error.localizedDescription completion:^{
            [strongSelf showOptions];
          }];
          return;
        }
        [strongSelf completeSelectedMode];
      }];
    });
  });
}

- (void)chooseDocumentsRoot {
  NSError *error = nil;
  NSArray<NSURL *> *roots = KartPadGameDataRootsInDocuments(&error);
  if (roots.count == 0) {
    NSLog(@"[KartPad] %@", KartPadDocumentsFolderScanDetail(error));
    [self presentGameDataPicker];
    return;
  }
  if (roots.count == 1) {
    [self startImport:roots.firstObject deleteAfterwards:NO];
    return;
  }
  UIAlertController *choices =
      [UIAlertController alertControllerWithTitle:@"Choose Game Data"
                                          message:@"Select your RMCP01 WBFS, ISO, or extracted DATA folder."
                                   preferredStyle:UIAlertControllerStyleAlert];
  for (NSURL *root in roots) {
    [choices addAction:[UIAlertAction actionWithTitle:root.lastPathComponent
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action) {
      (void)action;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
      [self startImport:root deleteAfterwards:NO];
    });
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self showOptions]; });
  }]];
  [self.root presentViewController:choices animated:YES completion:nil];
}

- (void)presentGameDataPicker {
  self.choosingGameDataCopy = YES;
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:KartPadGameDataContentTypes() asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self.root presentViewController:picker animated:YES completion:nil];
}

- (void)showOptions {
  self.choosingRetroArchive = NO;
  self.choosingGameDataCopy = NO;
  UIAlertController *options =
      [UIAlertController alertControllerWithTitle:@"Game Data Required"
          message:@"KartPad does not include Mario Kart Wii. Import your own RMCP01 WBFS, ISO, or extracted DATA folder to continue."
          preferredStyle:UIAlertControllerStyleAlert];
  [options addAction:[UIAlertAction actionWithTitle:@"Choose WBFS, ISO, or DATA Folder…"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self presentGameDataPicker];
    });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Import from This Installation's Folder..."
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self chooseDocumentsRoot]; });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Back"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
  [self.root presentViewController:options animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  (void)controller;
  NSURL *url = urls.firstObject;
  if (url != nil) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (self.choosingRetroArchive) {
        self.choosingRetroArchive = NO;
        [self installRetroRewindArchive:url deletingAfterwards:NO];
      } else {
        const BOOL deleteAfterwards = self.choosingGameDataCopy;
        self.choosingGameDataCopy = NO;
        [self startImport:url deleteAfterwards:deleteAfterwards];
      }
    });
  } else {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (self.choosingRetroArchive) {
        self.choosingRetroArchive = NO;
        [self showRetroRewindOptions];
      } else {
        self.choosingGameDataCopy = NO;
        [self showOptions];
      }
    });
  }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  (void)controller;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(0.35 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    if (self.choosingRetroArchive) {
      self.choosingRetroArchive = NO;
      [self showRetroRewindOptions];
    } else {
      self.choosingGameDataCopy = NO;
      [self showOptions];
    }
  });
}

- (BOOL)run {
  // Create the Files-visible app directory before first-launch UI is shown.
  // UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace expose this
  // Documents directory as On My iPhone/iPad -> KartPad.
  NSError *documentsError = nil;
  if (KartPadDocumentsRoot(&documentsError) == nil) {
    NSLog(@"[KartPad] could not prepare Files directory: %@",
          documentsError.localizedDescription);
  }
  NSError *removalError = KartPadApplyScheduledGameDataRemoval();
  if (removalError != nil) {
    NSLog(@"[KartPad] scheduled game-data removal failed: %@",
          removalError.localizedDescription);
  }
  const BOOL gameDataReady = removalError == nil && KartPadInstalledGameDataIsValid();
#if TARGET_OS_SIMULATOR
  NSString *testArchive = NSProcessInfo.processInfo.environment[
      @"KARTPAD_RETRO_REWIND_INSTALL_ARCHIVE"];
  if (testArchive.length > 0 && ![KartPadRetroRewindInstaller isInstalled]) {
    NSError *installError = nil;
    BOOL installed = [KartPadRetroRewindInstaller
        installArchiveAtURL:[NSURL fileURLWithPath:testArchive]
                   progress:^(NSString *status, double fraction) {
      NSLog(@"[KartPad] Simulator Retro Rewind install: %@ %.0f%%",
            status, fraction * 100.0);
    }
                      error:&installError];
    NSLog(@"[KartPad] Simulator Retro Rewind install %@%@",
          installed ? @"passed" : @"FAILED",
          installError == nil ? @"" :
              [NSString stringWithFormat:@": %@", installError.localizedDescription]);
  }
#endif
  UIWindowScene *scene = [self availableWindowScene];
  if (scene == nil) {
    NSLog(@"[KartPad] no UIWindowScene is available for first-launch import");
    return NO;
  }
  self.root = [[KartPadFirstLaunchViewController alloc] init];
  self.window = [[UIWindow alloc] initWithWindowScene:scene];
  self.window.windowLevel = UIWindowLevelAlert + 1.0;
  self.window.rootViewController = self.root;
  [self.window makeKeyAndVisible];
  __weak KartPadFirstLaunchHost *weakSelf = self;
  self.root.modeSelected = ^(BOOL retroRewind) {
    KartPadFirstLaunchHost *strongSelf = weakSelf;
    if (strongSelf == nil || strongSelf.finished) return;
    strongSelf.selectedRetroRewind = retroRewind;
    if (!gameDataReady) {
      [strongSelf showOptions];
      return;
    }
    [strongSelf completeSelectedMode];
  };
  NSString *requestedProfile = [NSUserDefaults.standardUserDefaults
      stringForKey:kKartPadRequestedRuntimeProfileKey];
  if ([requestedProfile isEqualToString:@"retro_rewind"] ||
      [requestedProfile isEqualToString:@"base"]) {
    [NSUserDefaults.standardUserDefaults
        removeObjectForKey:kKartPadRequestedRuntimeProfileKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.root.modeSelected != nil) {
        self.root.modeSelected([requestedProfile isEqualToString:@"retro_rewind"]);
      }
    });
  }
  if (removalError != nil) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self showMessage:@"Game Data Removal Failed"
                 detail:removalError.localizedDescription completion:^{
        self.finished = YES;
        self.succeeded = NO;
      }];
    });
  }
  while (!self.finished) {
    @autoreleasepool {
      [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
  }
  self.window.hidden = YES;
  self.window = nil;
  return self.succeeded;
}

@end

@implementation KartPadGameOverlay

- (instancetype)initWithFrame:(CGRect)frame {
  // Seed untouched layouts only; custom arrangements remain user-owned.
  KartPadSeedTouchLayoutDefaults(NO);
  return [super initWithFrame:frame];
}

- (SunPadStickView *)makeStick {
  if (self.kartPadMoveStick != nil) return [super makeStick];
  KartPadFloatingStickView *stick = [[KartPadFloatingStickView alloc]
      initWithFrame:CGRectMake(0, 0, 128, 128)];
  self.kartPadMoveStick = stick;
  __weak KartPadGameOverlay *weakSelf = self;
  __weak SunPadStickView *weakStick = stick;
  stick.valueChanged = ^(float x, float y) {
    SunPadStickView *strongStick = weakStick;
    if (strongStick != nil) [weakSelf stickChanged:strongStick x:x y:y];
  };
  return stick;
}

- (void)kartPadFinishLayoutEditing {
  [super finishLayoutEditing];
  [self toggleSettingsPanel];
}

- (void)endLayoutEditing {
  [super endLayoutEditing];
  self.kartPadSelectedControlIdentifier = nil;
}

- (void)kartPadToggleSelectedControlVisibility {
  NSString *identifier = self.kartPadSelectedControlIdentifier;
  if (identifier.length == 0) return;

  NSMutableSet<NSString *> *hidden =
      [KartPadHiddenTouchControls() mutableCopy];
  BOOL showing = [hidden containsObject:identifier];
  if (showing) {
    [hidden removeObject:identifier];
  } else {
    [hidden addObject:identifier];
  }
  NSArray<NSString *> *saved =
      [[hidden allObjects] sortedArrayUsingSelector:@selector(compare:)];
  [NSUserDefaults.standardUserDefaults setObject:saved
                                           forKey:kKartPadHiddenTouchControlsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
  if (showing) {
    for (UIView *control in self.subviews) {
      if (![KartPadVisibilityIdentifier(control) isEqualToString:identifier]) {
        continue;
      }
      control.hidden = NO;
      control.userInteractionEnabled = YES;
      control.alpha = 1.0;
    }
  }
  [self setNeedsLayout];
  [self layoutIfNeeded];
}

- (void)kartPadConfigureTouchLayoutEditor {
  UIButton *done = (UIButton *)KartPadSubviewWithAccessibilityLabel(
      self, @"Finish moving touch controls", UIButton.class);
  if (done == nil) return;

  [done setTitle:@"Back" forState:UIControlStateNormal];
  done.accessibilityHint = @"Saves the layout and returns to touch control settings.";
  [done removeTarget:self action:@selector(finishLayoutEditing)
     forControlEvents:UIControlEventTouchUpInside];
  [done removeTarget:self action:@selector(kartPadFinishLayoutEditing)
     forControlEvents:UIControlEventTouchUpInside];
  [done addTarget:self action:@selector(kartPadFinishLayoutEditing)
   forControlEvents:UIControlEventTouchUpInside];

  UIStackView *stack = [done.superview isKindOfClass:UIStackView.class]
      ? (UIStackView *)done.superview : nil;
  if (self.kartPadVisibilityButton == nil && stack != nil) {
    UIButton *visibility = [UIButton buttonWithType:UIButtonTypeSystem];
    [visibility setTitle:@"Hide" forState:UIControlStateNormal];
    [visibility setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    visibility.titleLabel.font =
        [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    visibility.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.96];
    visibility.layer.cornerRadius = 10.0;
    visibility.accessibilityLabel = @"Hide selected touch control";
    visibility.enabled = NO;
    [visibility addTarget:self
                   action:@selector(kartPadToggleSelectedControlVisibility)
         forControlEvents:UIControlEventTouchUpInside];
    [stack insertArrangedSubview:visibility
                         atIndex:MAX((NSInteger)stack.arrangedSubviews.count - 1,
                                     0)];
    [visibility.widthAnchor constraintEqualToConstant:68.0].active = YES;
    [visibility.heightAnchor constraintEqualToConstant:40.0].active = YES;
    self.kartPadVisibilityButton = visibility;
  }

  NSSet<NSString *> *hidden = KartPadHiddenTouchControls();
  BOOL editing = !KartPadViewIsEffectivelyHidden(done);
  for (UIView *control in self.subviews) {
    NSString *identifier = KartPadVisibilityIdentifier(control);
    if (identifier.length == 0 || ![hidden containsObject:identifier]) continue;
    control.hidden = !editing;
    control.userInteractionEnabled = editing;
    if (editing) control.alpha = 0.35;
  }

  NSString *selected = self.kartPadSelectedControlIdentifier;
  BOOL selectedHidden = selected.length > 0 && [hidden containsObject:selected];
  [self.kartPadVisibilityButton
      setTitle:selectedHidden ? @"Show" : @"Hide"
      forState:UIControlStateNormal];
  self.kartPadVisibilityButton.accessibilityLabel = selectedHidden
      ? @"Show selected touch control" : @"Hide selected touch control";
  self.kartPadVisibilityButton.enabled = selected.length > 0;
}

- (void)selectControlForEditing:(UIView *)control {
  [super selectControlForEditing:control];
  self.kartPadSelectedControlIdentifier =
      KartPadVisibilityIdentifier(control);
  [self kartPadConfigureTouchLayoutEditor];
}

- (void)resetLayout {
  [super resetLayout];
  [NSUserDefaults.standardUserDefaults
      removeObjectForKey:kKartPadHiddenTouchControlsKey];
  KartPadSeedTouchLayoutDefaults(YES);
  for (UIView *control in self.subviews) {
    if (KartPadVisibilityIdentifier(control).length == 0) continue;
    control.hidden = NO;
    control.userInteractionEnabled = YES;
    control.alpha = 1.0;
  }
  self.kartPadSelectedControlIdentifier = nil;
  [self setNeedsLayout];
}

- (void)toggleSettingsPanel {
  // Opening or closing a touch-modal must never leave a gameplay control held.
  // Keep this in KartPad's owner layer so the pinned SunPad snapshot remains
  // byte-identical to its upstream reference.
  [self clearTouchInput];
  [self resetKartPadControlAppearance];
  [super toggleSettingsPanel];
}

- (void)setTouchControlsHidden:(BOOL)hidden animated:(BOOL)animated {
  if (hidden) {
    [self clearTouchInput];
    [self resetKartPadControlAppearance];
  }
  [super setTouchControlsHidden:hidden animated:animated];
}

- (void)refreshMenuButton {
  // SunPad rebuilds its source menu after any inherited setting changes. Run
  // the KartPad rewrite immediately so that refreshes cannot expose the
  // Sunshine-specific title or performance switches on either device idiom.
  [super refreshMenuButton];
  [self setNeedsLayout];
  [self layoutIfNeeded];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.kartPadMoveStick.floatingEnabled =
      ![SunPadSettings sharedSettings].editingControlLayout;
  UIButton *menuButton = nil;
  UIButton *leftShoulder = nil;
  UIButton *rightShoulder = nil;
  UIButton *gasButton = nil;
  for (UIView *candidate in self.subviews) {
    if (![candidate isKindOfClass:UIButton.class]) continue;
    UIButton *button = (UIButton *)candidate;
    if ([button.accessibilityLabel isEqualToString:@"Menu"]) menuButton = button;
    if ([button.accessibilityLabel isEqualToString:@"L"]) leftShoulder = button;
    if ([button.accessibilityLabel isEqualToString:@"R"]) rightShoulder = button;
    if ([button.accessibilityLabel isEqualToString:@"A"]) gasButton = button;
  }

  KartPadConfigureMenuButton(menuButton);

  // Mario Kart's Classic R input is a normal digital shoulder button. Match
  // L exactly and suppress SunPad's Sunshine-specific pressure-fill artwork.
  if (leftShoulder != nil && rightShoulder != nil) {
    rightShoulder.bounds = CGRectMake(0.0, 0.0,
                                      CGRectGetWidth(leftShoulder.bounds),
                                      CGRectGetHeight(leftShoulder.bounds));
    rightShoulder.layer.cornerRadius =
        MIN(CGRectGetWidth(rightShoulder.bounds),
            CGRectGetHeight(rightShoulder.bounds)) * 0.5;
    rightShoulder.accessibilityHint = @"Drift, hop, brake, or reverse.";
    rightShoulder.accessibilityValue = @"Not pressed";
    for (CALayer *layer in rightShoulder.layer.sublayers) {
      if ([layer isKindOfClass:CAShapeLayer.class]) layer.hidden = YES;
    }
  }

  if (gasButton != nil && self.kartPadGasButton != gasButton) {
    self.kartPadGasButton = gasButton;
    self.kartPadGasRestColor = gasButton.backgroundColor;
    gasButton.accessibilityHint =
        @"Hold for one second to lock acceleration. Tap again to unlock.";
    [gasButton addTarget:self action:@selector(kartPadGasDown:)
         forControlEvents:UIControlEventTouchDown];
    [gasButton addTarget:self action:@selector(kartPadGasUp:)
         forControlEvents:UIControlEventTouchUpInside |
                          UIControlEventTouchUpOutside |
                          UIControlEventTouchCancel];
#if TARGET_OS_SIMULATOR
    if (!self.kartPadGasHoldSelfTestStarted &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_HOLD_SELF_TEST"] != nil) {
      self.kartPadGasHoldSelfTestStarted = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(30.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
          [gasButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
      });
    }
    if (!self.kartPadGasInputSelfTestStarted &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_INPUT_SELF_TEST"] != nil) {
      self.kartPadGasInputSelfTestStarted = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(1.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
          const SunPadInputState held =
              [[SunPadInputMixer sharedMixer] consumeMergedState];
          const KartPadClassicInputState heldClassic =
              kartpad::mobile::AdaptSunPadInput(held);
          const BOOL heldPassed =
              (heldClassic.buttons & kartpad::mobile::kClassicButtonA) != 0;
          gasButton.accessibilityValue = heldPassed
              ? @"Acceleration held · input verified"
              : @"Acceleration hold input test failed";
          NSLog(@"[KartPad] touch A hold self-test: %@ (classic=%08x)",
                heldPassed ? @"held pass" : @"held FAIL", heldClassic.buttons);
          [gasButton sendActionsForControlEvents:UIControlEventTouchUpInside];
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                       (int64_t)(0.1 * NSEC_PER_SEC)),
                         dispatch_get_main_queue(), ^{
            const SunPadInputState locked =
                [[SunPadInputMixer sharedMixer] consumeMergedState];
            const KartPadClassicInputState lockedClassic =
                kartpad::mobile::AdaptSunPadInput(locked);
            const BOOL lockPassed =
                (lockedClassic.buttons & kartpad::mobile::kClassicButtonA) != 0;
            [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
            [gasButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(0.1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
              const KartPadClassicInputState unlockedClassic =
                  kartpad::mobile::AdaptSunPadInput(
                      [[SunPadInputMixer sharedMixer] consumeMergedState]);
              const BOOL unlockPassed =
                  (unlockedClassic.buttons & kartpad::mobile::kClassicButtonA) == 0;
              gasButton.accessibilityHint = lockPassed && unlockPassed
                  ? @"Hold-to-lock and tap-to-unlock input self-test passed."
                  : @"Acceleration lock input self-test failed.";
              NSLog(@"[KartPad] touch A lock self-test: %@ (locked=%08x unlocked=%08x)",
                    lockPassed && unlockPassed ? @"pass" : @"FAIL",
                    lockedClassic.buttons, unlockedClassic.buttons);
            });
          });
        });
      });
    }
    if (!self.kartPadModalInputSelfTestStarted && menuButton != nil &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_MODAL_SELF_TEST"] != nil) {
      self.kartPadModalInputSelfTestStarted = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
        const KartPadClassicInputState before = kartpad::mobile::AdaptSunPadInput(
            [[SunPadInputMixer sharedMixer] consumeMergedState]);
        [self toggleSettingsPanel];
        const KartPadClassicInputState after = kartpad::mobile::AdaptSunPadInput(
            [[SunPadInputMixer sharedMixer] consumeMergedState]);
        const BOOL passed =
            (before.buttons & kartpad::mobile::kClassicButtonA) != 0 &&
            (after.buttons & kartpad::mobile::kClassicButtonA) == 0;
        menuButton.accessibilityHint = passed
            ? @"Touch settings input-clear self-test passed."
            : @"Touch settings input-clear self-test failed.";
        NSLog(@"[KartPad] touch modal input self-test: %@ (before=%08x after=%08x)",
              passed ? @"pass" : @"FAIL", before.buttons, after.buttons);
        [self toggleSettingsPanel];
      });
    }
    if (!self.kartPadEditorUITestStarted && menuButton != nil &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_EDITOR_UI_TEST"] != nil) {
      self.kartPadEditorUITestStarted = YES;
      NSString *mode =
          NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_EDITOR_UI_TEST"];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self toggleSettingsPanel];
        [self layoutIfNeeded];
        UIScrollView *scroll = KartPadScrollableSettingsView(self);
        if (scroll == nil) {
          menuButton.accessibilityHint =
              @"Touch editor lower-row test failed: settings scroll view missing.";
          NSLog(@"[KartPad] touch editor UI test: FAIL (scroll view missing)");
          return;
        }
        const CGFloat bottom = MAX(-scroll.adjustedContentInset.top,
            scroll.contentSize.height - CGRectGetHeight(scroll.bounds) +
                scroll.adjustedContentInset.bottom);
        [scroll setContentOffset:CGPointMake(scroll.contentOffset.x, bottom)
                       animated:NO];
        menuButton.accessibilityHint = @"Touch editor lower rows exposed.";
        NSLog(@"[KartPad] touch editor UI test: lower rows exposed (offset=%.1f)",
              bottom);
        if ([mode isEqualToString:@"move"]) {
          UISwitch *move = (UISwitch *)KartPadSubviewWithAccessibilityLabel(
              self, @"Move touch controls", UISwitch.class);
          if (move == nil) {
            NSLog(@"[KartPad] touch editor UI test: FAIL (move switch missing)");
            return;
          }
          [move setOn:YES animated:NO];
          [move sendActionsForControlEvents:UIControlEventValueChanged];
          UIButton *aButton = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"A", UIButton.class);
          if (aButton != nil) [self selectControlForEditing:aButton];
          UISlider *aSize = (UISlider *)KartPadSubviewWithAccessibilityLabel(
              self, @"A size", UISlider.class);
          if (aSize != nil) {
            aSize.value = 1.25;
            [aSize sendActionsForControlEvents:UIControlEventValueChanged];
          }
          UIButton *done = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"Finish moving touch controls", UIButton.class);
          const BOOL sizePersisted = std::fabs(
              [[SunPadSettings sharedSettings] sizeScaleForControl:@"A"] -
              1.25) < 0.001;
          const BOOL passed = done != nil && !done.hidden && aSize.enabled &&
                              sizePersisted;
          menuButton.accessibilityHint = passed
              ? @"Touch editor selected and resized A."
              : @"Touch editor move-mode test failed.";
          NSLog(@"[KartPad] touch editor UI test: move/resize %@ (A=%.2f)",
                passed ? @"pass" : @"FAIL",
                [[SunPadSettings sharedSettings] sizeScaleForControl:@"A"]);
        } else if ([mode isEqualToString:@"reset"]) {
          [[NSUserDefaults standardUserDefaults]
              setObject:@{@"A" : NSStringFromCGPoint(CGPointMake(0.5, 0.5))}
                 forKey:@"SunPadControlOrigins"];
          [[NSUserDefaults standardUserDefaults] synchronize];
          UIButton *reset = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"Reset This Device Layout", UIButton.class);
          if (reset == nil) {
            NSLog(@"[KartPad] touch editor UI test: FAIL (reset button missing)");
            return;
          }
          [reset sendActionsForControlEvents:UIControlEventTouchUpInside];
          NSLog(@"[KartPad] touch editor UI test: reset confirmation opened");
        }
      });
    }
#endif
  }

  [self kartPadConfigureTouchLayoutEditor];

  UIMenu *sourceMenu = menuButton.menu;
  if (sourceMenu == nil ||
      [sourceMenu.identifier isEqualToString:@"dev.kartpad.menu"]) {
    return;
  }

  __weak KartPadGameOverlay *weakSelf = self;
  UIAction *multiplayer =
      [UIAction actionWithTitle:@"Multiplayer…"
                          image:[UIImage systemImageNamed:@"person.2.fill"]
                     identifier:@"dev.kartpad.multiplayer"
                        handler:^(__kindof UIAction *action) {
                          (void)action;
                          if (weakSelf.multiplayerRequested != nil) {
                            weakSelf.multiplayerRequested();
                          }
                        }];
  UIAction *motionSteering =
      [UIAction actionWithTitle:@"Motion Steering…"
                          image:[UIImage systemImageNamed:@"gyroscope"]
                     identifier:@"dev.kartpad.motion-steering"
                        handler:^(__kindof UIAction *action) {
                          (void)action;
                          if (weakSelf.motionSteeringRequested != nil) {
                            weakSelf.motionSteeringRequested();
                          }
                        }];
  UIAction *experimentalWiimote =
      [UIAction actionWithTitle:@"Experimental Wii Remote + Nunchuk…"
                          image:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"]
                     identifier:@"dev.kartpad.experimental-wiimote"
                        handler:^(__kindof UIAction *action) {
                          (void)action;
                          if (weakSelf.wiimoteRequested != nil) {
                            weakSelf.wiimoteRequested();
                          }
                        }];
  UIAction *fpsCounter = nil;
  UIAction *controllerMapping = nil;
  UIAction *touchControlSettings = nil;
  UIAction *reportProblem = nil;
  UIMenu *aspectRatio = nil;
  UIMenu *renderResolution = nil;
  UIMenu *gameData = nil;
  for (UIMenuElement *element in sourceMenu.children) {
    if ([element isKindOfClass:UIAction.class]) {
      UIAction *action = (UIAction *)element;
      if ([action.title isEqualToString:@"Show FPS Counter"]) {
        fpsCounter = action;
        continue;
      }
      if ([action.title isEqualToString:@"Controller Button Mapping…"]) {
        controllerMapping = action;
        continue;
      }
      if ([action.title isEqualToString:@"Touch Control Settings…"]) {
        touchControlSettings = action;
        continue;
      }
      if ([action.title isEqualToString:@"Report a Problem…"]) {
        reportProblem = action;
        continue;
      }
      if ([action.title hasPrefix:@"Experimental Performance Mode"] ||
          [action.title hasPrefix:@"Experimental 60 FPS"]) {
        // These are Sunshine-specific experiments inherited from SunPad.
        // Mario Kart Wii already uses its retail 60 FPS cadence, and neither
        // setting changes KartPad's ahead-of-time runtime.
        continue;
      }
    }

    if ([element isKindOfClass:UIMenu.class] &&
        [element.title isEqualToString:@"Render Resolution"]) {
      renderResolution = (UIMenu *)element;
      continue;
    }
    if ([element isKindOfClass:UIMenu.class] &&
        [element.title isEqualToString:@"Aspect Ratio"]) {
      aspectRatio = (UIMenu *)element;
      continue;
    }
    if ([element isKindOfClass:UIMenu.class] &&
        [element.title isEqualToString:@"Game Data & Saves"]) {
      UIMenu *dataMenu = (UIMenu *)element;
      NSMutableArray<UIMenuElement *> *dataItems = [NSMutableArray array];
      for (UIMenuElement *dataElement in dataMenu.children) {
        if ([dataElement isKindOfClass:UIAction.class] &&
            [dataElement.title isEqualToString:@"Import from SunPad Folder"]) {
          UIAction *sourceAction = (UIAction *)dataElement;
          UIAction *replacement =
              [UIAction actionWithTitle:@"Import from This Installation's Folder..."
                                  image:sourceAction.image
                             identifier:sourceAction.identifier
                                handler:^(__kindof UIAction *action) {
            (void)action;
            [weakSelf.delegate gameOverlayRequestsGameDataFolderImport:weakSelf];
          }];
          replacement.attributes = sourceAction.attributes;
          replacement.state = sourceAction.state;
          replacement.discoverabilityTitle = sourceAction.discoverabilityTitle;
          [dataItems addObject:replacement];
        } else {
          [dataItems addObject:dataElement];
        }
      }
      UIAction *miiManager =
          [UIAction actionWithTitle:@"Player Identity…"
                              image:[UIImage systemImageNamed:@"person.crop.circle.badge.plus"]
                         identifier:@"dev.kartpad.manage-miis"
                            handler:^(__kindof UIAction *action) {
        (void)action;
        if (weakSelf.miiManagerRequested != nil) {
          weakSelf.miiManagerRequested();
        }
      }];
      [dataItems insertObject:miiManager atIndex:0];
      gameData = [UIMenu menuWithTitle:dataMenu.title
                                 image:[UIImage systemImageNamed:@"externaldrive"]
                            identifier:dataMenu.identifier
                               options:dataMenu.options
                              children:dataItems];
      continue;
    }
  }

  NSMutableArray<UIMenuElement *> *controlItems = [NSMutableArray array];
  if (controllerMapping != nil) [controlItems addObject:controllerMapping];
  if (touchControlSettings != nil) [controlItems addObject:touchControlSettings];
  [controlItems addObject:motionSteering];
  [controlItems addObject:experimentalWiimote];
  UIMenu *controls =
      [UIMenu menuWithTitle:@"Controls"
                      image:[UIImage systemImageNamed:@"gamecontroller"]
                 identifier:@"dev.kartpad.controls"
                    options:0
                   children:controlItems];

  NSMutableArray<UIMenuElement *> *displayItems = [NSMutableArray array];
  if (aspectRatio != nil) [displayItems addObject:aspectRatio];
  if (renderResolution != nil) [displayItems addObject:renderResolution];
  UIMenu *display =
      [UIMenu menuWithTitle:@"Display"
                      image:[UIImage systemImageNamed:@"display"]
                 identifier:@"dev.kartpad.display"
                    options:0
                   children:displayItems];

  NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];
  [children addObject:[UIAction actionWithTitle:@"Return to KartPad Menu"
      image:[UIImage systemImageNamed:@"house"] identifier:@"dev.kartpad.main-menu"
      handler:^(__kindof UIAction *action) {
    if (weakSelf.mainMenuRequested) weakSelf.mainMenuRequested();
  }]];
  [children addObject:multiplayer];
  if (fpsCounter != nil) [children addObject:fpsCounter];
  [children addObject:controls];
  [children addObject:display];
  if (gameData != nil) [children addObject:gameData];
  if (reportProblem != nil) [children addObject:reportProblem];
  menuButton.menu = [UIMenu menuWithTitle:@"KartPad"
                                    image:sourceMenu.image
                               identifier:@"dev.kartpad.menu"
                                  options:sourceMenu.options
                                 children:children];
}

- (void)reportProblem {
  UIViewController *presenter = KartPadVisibleViewController(self.window);
  if (presenter == nil) return;
  UIAlertController *prompt =
      [UIAlertController alertControllerWithTitle:@"Report a Problem"
                                          message:@"Answer briefly and KartPad will add the technical details. If the problem is visual, take a screenshot first and attach it with the report on GitHub. The report never includes your game image, extracted files, saves, signing material, or controller inputs. GitHub reports and attachments are public."
                                   preferredStyle:UIAlertControllerStyleAlert];
  [prompt addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.placeholder = @"What went wrong?";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];
  [prompt addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.placeholder = @"Area and what you were doing (optional)";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];
  [prompt addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.placeholder = @"Every time, sometimes, once, or not sure?";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];
  [prompt addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  __weak KartPadGameOverlay *weakSelf = self;
  [prompt addAction:[UIAlertAction actionWithTitle:@"Share Report…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    [weakSelf createDiagnosticReportFromPrompt:prompt openGitHub:NO];
  }]];
  [prompt addAction:[UIAlertAction actionWithTitle:@"Report on GitHub"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    [weakSelf createDiagnosticReportFromPrompt:prompt openGitHub:YES];
  }]];
  prompt.preferredAction = prompt.actions.lastObject;
  [presenter presentViewController:prompt animated:YES completion:nil];
}

- (void)createDiagnosticReportFromPrompt:(UIAlertController *)prompt
                              openGitHub:(BOOL)openGitHub {
  NSString *problem = prompt.textFields.count > 0 ? prompt.textFields[0].text : @"";
  NSString *context = prompt.textFields.count > 1 ? prompt.textFields[1].text : @"";
  NSString *frequency = prompt.textFields.count > 2 ? prompt.textFields[2].text : @"";
  NSString *reportID = [NSString stringWithFormat:@"KP-%@",
      [[[NSUUID UUID] UUIDString] substringToIndex:8]];
  NSDictionary<NSString *, NSString *> *answers = @{
    @"problem" : problem ?: @"",
    @"context" : context ?: @"",
    @"frequency" : frequency ?: @"",
  };
  NSString *technicalContext = [self.delegate gameOverlayDiagnosticContext:self];
  SunPadLog(@"diagnostic report requested id=%@ destination=%@",
            reportID, openGitHub ? @"github" : @"share-sheet");
  NSError *error = nil;
  NSURL *reportURL = SunPadDiagnosticsReportURL(
      reportID, answers, technicalContext, &error);
  UIViewController *presenter = KartPadVisibleViewController(self.window);
  if (reportURL == nil) {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Diagnostic Report Unavailable"
                                            message:error.localizedDescription
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
    return;
  }

  NSString *report = [NSString stringWithContentsOfURL:reportURL
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  if (report != nil) {
    report = [report stringByReplacingOccurrencesOfString:
        @"SunPad Diagnostic Report v2" withString:@"KartPad Diagnostic Report v2"];
    report = [report stringByReplacingOccurrencesOfString:
        @"issuesURL=https://github.com/chrissotraidis/sunpad/issues"
                                                 withString:
        @"issuesURL=https://github.com/chrissotraidis/kartpad/issues"];
    [report writeToURL:reportURL atomically:YES
               encoding:NSUTF8StringEncoding error:nil];
  }

  if (openGitHub) {
    [self openGitHubReportWithID:reportID answers:answers];
    return;
  }

  UIActivityViewController *share =
      [[UIActivityViewController alloc] initWithActivityItems:@[reportURL]
                                       applicationActivities:nil];
  UIPopoverPresentationController *popover = share.popoverPresentationController;
  UIButton *menuButton = (UIButton *)KartPadSubviewWithAccessibilityLabel(
      self, @"Menu", UIButton.class);
  popover.sourceView = menuButton ?: self;
  popover.sourceRect = menuButton != nil ? menuButton.bounds : self.bounds;
  [presenter presentViewController:share animated:YES completion:nil];
}

- (void)openGitHubReportWithID:(NSString *)reportID
                       answers:(NSDictionary<NSString *, NSString *> *)answers {
  NSBundle *bundle = NSBundle.mainBundle;
  NSString *version = [bundle objectForInfoDictionaryKey:
      @"CFBundleShortVersionString"] ?: @"unknown";
  NSString *build = [bundle objectForInfoDictionaryKey:
      @"CFBundleVersion"] ?: @"unknown";
  NSString *platform =
      self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad
          ? @"iPad" : @"iPhone";
  NSString *problem = answers[@"problem"].length > 0
      ? answers[@"problem"] : @"KartPad problem";
  if (problem.length > 100) problem = [problem substringToIndex:100];
  NSURLComponents *components = [NSURLComponents componentsWithString:
      @"https://github.com/chrissotraidis/kartpad/issues/new"];
  components.queryItems = @[
    [NSURLQueryItem queryItemWithName:@"template" value:@"bug_report.yml"],
    [NSURLQueryItem queryItemWithName:@"title"
                                value:[NSString stringWithFormat:@"[Bug]: %@", problem]],
    [NSURLQueryItem queryItemWithName:@"report-id" value:reportID],
    [NSURLQueryItem queryItemWithName:@"revision"
                                value:[NSString stringWithFormat:@"%@ (build %@)",
                                                                   version, build]],
    [NSURLQueryItem queryItemWithName:@"platform" value:platform],
    [NSURLQueryItem queryItemWithName:@"performance-profile"
                                value:[self.delegate gameOverlayPerformanceProfile:self]],
    [NSURLQueryItem queryItemWithName:@"summary" value:answers[@"problem"]],
    [NSURLQueryItem queryItemWithName:@"context" value:answers[@"context"]],
    [NSURLQueryItem queryItemWithName:@"frequency" value:answers[@"frequency"]],
  ];
  NSURL *url = components.URL;
  if (url == nil) return;
  [UIApplication.sharedApplication openURL:url options:@{}
                         completionHandler:^(BOOL success) {
    if (!success) SunPadLog(@"diagnostic github open failed id=%@", reportID);
  }];
}

- (void)rPressureChanged:(uint8_t)pressure fullPress:(BOOL)fullPress {
  (void)fullPress;
  const BOOL pressed = pressure > 0;
  [super rPressureChanged:pressed ? 255 : 0 fullPress:pressed];
}

- (void)kartPadGasDown:(UIButton *)button {
  self.kartPadGasPressed = YES;
  const NSUInteger generation = ++self.kartPadGasHoldGeneration;
  if (self.kartPadGasLocked) {
    // The next ordinary tap releases a previously locked accelerator. The
    // inherited touch-up action clears A after this touch ends.
    self.kartPadGasLocked = NO;
    button.backgroundColor = self.kartPadGasRestColor;
    button.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
    button.layer.shadowOpacity = 0.0;
    button.accessibilityValue = @"Unlocking acceleration";
    return;
  }
  __weak KartPadGameOverlay *weakSelf = self;
  __weak UIButton *weakButton = button;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    KartPadGameOverlay *strongSelf = weakSelf;
    UIButton *strongButton = weakButton;
    if (strongSelf == nil || strongButton == nil ||
        !strongSelf.kartPadGasPressed ||
        strongSelf.kartPadGasHoldGeneration != generation) {
      return;
    }
    strongSelf.kartPadGasLocked = YES;
    strongButton.backgroundColor =
        [UIColor colorWithRed:0.06 green:0.78 blue:0.92 alpha:0.98];
    strongButton.layer.borderColor = UIColor.whiteColor.CGColor;
    strongButton.layer.shadowColor =
        [UIColor colorWithRed:0.06 green:0.78 blue:0.92 alpha:1.0].CGColor;
    strongButton.layer.shadowOpacity = 0.9;
    strongButton.layer.shadowRadius = 9.0;
    strongButton.layer.shadowOffset = CGSizeZero;
    strongButton.accessibilityValue = @"Acceleration locked";
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
  });
}

- (void)kartPadGasUp:(UIButton *)button {
  self.kartPadGasPressed = NO;
  ++self.kartPadGasHoldGeneration;
  if (self.kartPadGasLocked) {
    // SunPad's existing touch-up action clears A. Reassert it after all targets
    // for this UIKit event finish so the lock survives the finger lifting.
    __weak KartPadGameOverlay *weakSelf = self;
    __weak UIButton *weakButton = button;
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadGameOverlay *strongSelf = weakSelf;
      UIButton *strongButton = weakButton;
      if (strongSelf == nil || strongButton == nil ||
          !strongSelf.kartPadGasLocked) {
        return;
      }
      [super buttonDown:strongButton];
      strongButton.transform = CGAffineTransformIdentity;
    });
    return;
  }
  button.backgroundColor = self.kartPadGasRestColor;
  button.layer.borderColor =
      [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
  button.layer.shadowOpacity = 0.0;
  button.accessibilityValue = nil;
}

- (void)resetKartPadControlAppearance {
  self.kartPadGasPressed = NO;
  self.kartPadGasLocked = NO;
  ++self.kartPadGasHoldGeneration;
  if (self.kartPadGasButton != nil) {
    self.kartPadGasButton.backgroundColor = self.kartPadGasRestColor;
    self.kartPadGasButton.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
    self.kartPadGasButton.layer.shadowOpacity = 0.0;
    self.kartPadGasButton.accessibilityValue = nil;
  }
}

@end

@implementation KartPadRuntimeOverlayHost {
  __weak UIWindow *_window;
  SDL_Window *_sdlWindow;
  SunPadGameOverlay *_overlay;
  UIAlertController *_gameDataProgressAlert;
  BOOL _choosingMiiImport;
}

- (instancetype)initWithSDLWindow:(SDL_Window *)window {
  self = [super init];
  if (self == nil || window == nullptr) {
    return nil;
  }

  _sdlWindow = window;
  SDL_PropertiesID properties = SDL_GetWindowProperties(window);
  UIWindow *uiWindow = (__bridge UIWindow *)SDL_GetPointerProperty(
      properties, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
  UIView *container = uiWindow.rootViewController.view;
  if (uiWindow == nil || container == nil) {
    NSLog(@"[KartPad] SDL UIKit window is unavailable for the touch overlay");
    return nil;
  }

  _window = uiWindow;
  KartPadGameOverlay *overlay =
      [[KartPadGameOverlay alloc] initWithFrame:container.bounds];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  overlay.multiplayerRequested = ^{
    [weakSelf showMultiplayerAccess];
  };
  overlay.mainMenuRequested = ^{
    gKartPadMainMenuRequested = YES;
  };
  overlay.motionSteeringRequested = ^{
    [weakSelf showMotionSteering];
  };
  overlay.miiManagerRequested = ^{
    [weakSelf showMiiManager];
  };
  overlay.wiimoteRequested = ^{
    [weakSelf showExperimentalWiimoteInfo];
  };
  _overlay = overlay;
  _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleHeight;
  _overlay.backgroundColor = UIColor.clearColor;
  _overlay.delegate = self;
  [container addSubview:_overlay];
  [container bringSubviewToFront:_overlay];
  [[KartPadPhysicalControllers sharedControllers] start];
  [[KartPadMotionSteering sharedSteering] start];

  NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
  [notifications addObserver:self
                     selector:@selector(applicationWillResignActive:)
                         name:UIApplicationWillResignActiveNotification
                       object:nil];
  [notifications addObserver:self
                     selector:@selector(applicationDidBecomeActive:)
                         name:UIApplicationDidBecomeActiveNotification
                       object:nil];
  [notifications addObserver:self
                     selector:@selector(userDidTakeScreenshot:)
                         name:UIApplicationUserDidTakeScreenshotNotification
                       object:nil];
  SunPadDiagnosticsStart();
  NSLog(@"[KartPad] exact SunPad runtime overlay installed");
  return self;
}

- (void)reattachOverlayIfNeeded {
  if (_overlay == nil || _sdlWindow == nullptr) return;
  SDL_PropertiesID properties = SDL_GetWindowProperties(_sdlWindow);
  UIWindow *window = (__bridge UIWindow *)SDL_GetPointerProperty(
      properties, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
  UIView *container = window.rootViewController.view;
  if (window == nil || container == nil) {
    NSLog(@"[KartPad] SDL UIKit window is unavailable during overlay recovery");
    return;
  }
  _window = window;
  if (_overlay.superview != container) {
    [_overlay removeFromSuperview];
    _overlay.frame = container.bounds;
    [container addSubview:_overlay];
    NSLog(@"[KartPad] touch overlay reattached after UIKit surface change");
  }
  _overlay.hidden = NO;
  _overlay.alpha = 1.0;
  [container bringSubviewToFront:_overlay];
  [_overlay setNeedsLayout];
  [_overlay layoutIfNeeded];
  UIButton *menuButton = KartPadFindMenuButton(_overlay);
  KartPadConfigureMenuButton(menuButton);
  menuButton.selected = NO;
  menuButton.highlighted = NO;
  menuButton.hidden = NO;
  menuButton.alpha = 1.0;
}

- (void)userDidTakeScreenshot:(NSNotification *)notification {
  (void)notification;
  // The screenshot notification arrives after capture. Reassert the app-owned
  // overlay immediately and once more on the next run-loop pass so UIKit's
  // transient screenshot/menu state cannot leave the persistent button hidden.
  [self reattachOverlayIfNeeded];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf reattachOverlayIfNeeded];
  });
}

- (void)showMotionSteering {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  KartPadMotionSteering *motion = [KartPadMotionSteering sharedSteering];
  NSString *status = motion.sensorAvailable
      ? [NSString stringWithFormat:
            @"Tilt steering: %@. Shake tricks/wheelies: %@. Sensitivity: %.1fx. Physical controllers take priority.",
            motion.enabled ? @"On" : @"Off",
            motion.shakeTricksEnabled ? @"On" : @"Off", motion.sensitivity]
      : @"Motion data is unavailable on this device or Simulator. Touch and physical-controller steering remain available.";
  UIAlertController *sheet =
      [UIAlertController alertControllerWithTitle:@"Motion Steering"
                                          message:status
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  if (motion.sensorAvailable) {
    [sheet addAction:[UIAlertAction
        actionWithTitle:motion.enabled ? @"Turn Off" : @"Turn On & Recenter"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      motion.enabled = !motion.enabled;
      if (motion.enabled) [motion recenter];
    }]];
    if (motion.enabled) {
      [sheet addAction:[UIAlertAction actionWithTitle:@"Recenter Now"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        (void)action;
        [motion recenter];
      }]];
    }
    [sheet addAction:[UIAlertAction
        actionWithTitle:motion.inverted ? @"Use Standard Direction" : @"Invert Direction"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      motion.inverted = !motion.inverted;
    }]];
    [sheet addAction:[UIAlertAction
        actionWithTitle:motion.shakeTricksEnabled
            ? @"Disable Shake Tricks/Wheelies"
            : @"Enable Shake Tricks/Wheelies"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      motion.shakeTricksEnabled = !motion.shakeTricksEnabled;
    }]];
    [sheet addAction:[UIAlertAction
        actionWithTitle:@"Cycle Sensitivity"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      const float current = motion.sensitivity;
      motion.sensitivity = current < 0.75f ? 1.0f : (current < 1.5f ? 2.0f : 0.5f);
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Continue Playing"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  UIPopoverPresentationController *popover = sheet.popoverPresentationController;
  popover.sourceView = _overlay;
  popover.sourceRect = CGRectMake(CGRectGetMidX(_overlay.bounds),
                                  CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:sheet animated:YES completion:nil];
}

// UIAlertAction handlers run before UIKit finishes dismissing their alert.
// Present the next screen only after that transition completes.
- (void)presentOverlayAlert:(UIAlertController *)alert {
  UIPopoverPresentationController *popover = alert.popoverPresentationController;
  popover.sourceView = _overlay;
  popover.sourceRect = CGRectMake(CGRectGetMidX(_overlay.bounds),
      CGRectGetMidY(_overlay.bounds), 1, 1);
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = KartPadVisibleViewController(self->_window);
    if (presenter == nil) return;
    void (^present)(void) = ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        [KartPadVisibleViewController(self->_window)
            presentViewController:alert animated:YES completion:nil];
      });
    };
    if ([presenter isKindOfClass:UIAlertController.class]) {
      if (presenter.isBeingDismissed && presenter.transitionCoordinator) {
        [presenter.transitionCoordinator animateAlongsideTransition:nil
            completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { present(); }];
      } else {
        [presenter dismissViewControllerAnimated:YES completion:present];
      }
    } else {
      present();
    }
  });
}

- (void)showMultiplayerMessage:(NSString *)title message:(NSString *)message {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
      message:message preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:alert];
}

- (void)runMainMenu {
  // Called by the guest's event pump, after the menu action has returned.
  // This keeps the current guest stack suspended while UIKit stays responsive.
  gKartPadMainMenuRequested = NO;
  [(KartPadGameOverlay *)_overlay resetKartPadControlAppearance];
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  [[KartPadMotionSteering sharedSteering] stop];
  AudioBackend::Instance().SetPausedForHost(true);
  __block BOOL finished = NO;
  KartPadFirstLaunchViewController *root = [[KartPadFirstLaunchViewController alloc] init];
  root.resumingGame = YES;
  root.currentRetroRewind = gKartPadRetroRewindSelected;
  UIWindow *home = [[UIWindow alloc] initWithWindowScene:_window.windowScene];
  home.windowLevel = UIWindowLevelAlert + 1;
  home.rootViewController = root;
  __weak KartPadFirstLaunchViewController *weakRoot = root;
  root.modeSelected = ^(BOOL retroRewind) {
    if (retroRewind == gKartPadRetroRewindSelected) {
      finished = YES;
      return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Switch on Next Launch"
        message:@"Close KartPad from the app switcher and reopen it to start the other game. Your saved progress and control layout are kept. Unsaved race progress is not carried over."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Use on Next Launch"
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [NSUserDefaults.standardUserDefaults setObject:retroRewind ? @"retro_rewind" : @"base"
          forKey:kKartPadRequestedRuntimeProfileKey];
      [NSUserDefaults.standardUserDefaults synchronize];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [weakRoot presentViewController:alert animated:YES completion:nil];
  };
  [home makeKeyAndVisible];
  const int pausedFrame = g_gxFrameCount;
  NSLog(@"[KartPad] main menu opened; current game suspended at frame %d", pausedFrame);
  while (!finished) {
    @autoreleasepool {
      [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
  }
  home.hidden = YES;
  root.modeSelected = nil;
  [_window makeKeyAndVisible];
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  for (NSUInteger player = 0; player < 4; ++player) {
    SunPadInputState ignored{};
    [[KartPadPhysicalControllers sharedControllers] consumePlayer:player state:&ignored];
  }
  [[KartPadMotionSteering sharedSteering] start];
  AudioBackend::Instance().SetPausedForHost(false);
  NSLog(@"[KartPad] current game resumed from main menu; frame %d -> %d", pausedFrame, g_gxFrameCount);
}

- (void)showPrivateServerSettings {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *editor = [UIAlertController alertControllerWithTitle:@"Private Wii Server"
      message:@"Experimental Wii server (unencrypted), not another iPad's address. Restart to apply; blank restores default."
      preferredStyle:UIAlertControllerStyleAlert];
  [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.placeholder = @"Server hostname or IPv4 address";
    field.text = KartPadPrivateServerHost();
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.keyboardType = UIKeyboardTypeURL;
    field.accessibilityLabel = @"Private Wii server address";
  }];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [editor addAction:[UIAlertAction actionWithTitle:@"Save"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *host = [editor.textFields.firstObject.text
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (host.length == 0) {
      [NSUserDefaults.standardUserDefaults removeObjectForKey:@"KartPadPrivateWfcHost"];
      [weakSelf showMultiplayerMessage:@"Default Service Selected"
          message:@"Fully close and reopen KartPad to restore the default online service. Original Mario Kart Wii's original service is closed; Retro Rewind uses Retro WFC."];
      return;
    }
    if (!KartPad::Network::ValidPrivateWfcHost(host.UTF8String ?: "")) {
      [weakSelf showMultiplayerMessage:@"Invalid Server Address"
          message:@"Enter a hostname or IPv4 address only, without a URL scheme, path, port, or spaces."];
      return;
    }
    [NSUserDefaults.standardUserDefaults setObject:host forKey:@"KartPadPrivateWfcHost"];
    [weakSelf showMultiplayerMessage:@"Private Server Saved"
        message:@"Fully close and reopen KartPad to apply this experimental override. A compatible server must already be running. This does not create a room or restore vanilla Nintendo WFC; server login and races remain unverified."];
  }]];
  [editor addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:editor];
}

- (void)showMultiplayerAccess {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  NSString *profile = gKartPadRetroRewindSelected ? @"Retro Rewind" : @"Mario Kart Wii";
  NSString *server = KartPadPrivateServerHost();
  NSString *message = [NSString stringWithFormat:@"%@\n%@", profile,
      !gKartPadRetroRewindSelected
          ? @"Local split-screen available. Original Nintendo WFC is closed; private online rooms are not available in this build."
          : (server.length ? @"Experimental server override configured; restart after changes."
              : @"Online: Retro WFC.")];
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Multiplayer"
      message:message preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [sheet addAction:[UIAlertAction actionWithTitle:@"Local Players & Controllers…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf gameOverlayRequestsControllerMapping:nil];
  }]];
  if (gKartPadRetroRewindSelected) {
    [sheet addAction:[UIAlertAction actionWithTitle:@"Retro WFC Friend Rooms…"
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [weakSelf showMultiplayerMessage:@"Retro WFC Friend Rooms"
          message:@"Retro Rewind uses Retro WFC. Connect there in the game, then open Friends and exchange friend codes with players using the same Retro Rewind version. The host creates a room; friends join from their roster.\n\nThis is Retro Rewind's in-game service. A custom server override may prevent connection. Native KartPad host/join rooms are not implemented yet."];
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Experimental Server Settings…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf showPrivateServerSettings];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)uninstall {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [[KartPadPhysicalControllers sharedControllers] stop];
  [[KartPadMotionSteering sharedSteering] stop];
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  if ([_overlay isKindOfClass:KartPadGameOverlay.class]) {
    [(KartPadGameOverlay *)_overlay resetKartPadControlAppearance];
  }
  _overlay.delegate = nil;
  [_overlay removeFromSuperview];
  _overlay = nil;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
  (void)notification;
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  if ([_overlay isKindOfClass:KartPadGameOverlay.class]) {
    [(KartPadGameOverlay *)_overlay resetKartPadControlAppearance];
  }
  [[KartPadMotionSteering sharedSteering] stop];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
  (void)notification;
  [[KartPadPhysicalControllers sharedControllers] reconcileControllers];
  [[KartPadMotionSteering sharedSteering] start];
  [self reattachOverlayIfNeeded];
  [_overlay refreshControllerVisibility];
  [_overlay applySettings];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf reattachOverlayIfNeeded];
  });
}

- (void)showIntegrationAlert:(NSString *)title message:(NSString *)message {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];
  [self presentOverlayAlert:alert];
}

- (void)showExperimentalWiimoteInfo {
  [self showIntegrationAlert:@"Experimental Wii Remote + Nunchuk"
                     message:@"Direct Wii Remote pairing is currently available only in the macOS build. KartPad for iPhone and iPad keeps this option visible so the control layout remains consistent, but iOS does not expose the Bluetooth HID pairing path required by an original Wii Remote. No DolphinBar is required on macOS."];
}

- (void)presentMiiImportPicker {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  _choosingMiiImport = YES;
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:@[UTTypeData, UTTypeItem] asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [controller presentViewController:picker animated:YES completion:nil];
}

- (void)showMiiCreationHelp {
  [self showIntegrationAlert:@"Mii Appearance"
                     message:@"KartPad can set the online player name for its built-in Mii. To change the face or other appearance details, import a standard 74-byte .mii file made with a compatible tool. Player Identity can then rename it and update every linked Mario Kart Wii license."];
}

- (void)showPlayerNameEditorForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  NSString *currentName = record[@"name"] ?: @"";
  NSUInteger slot = [record[@"slot"] unsignedIntegerValue];
  UIAlertController *editor = [UIAlertController
      alertControllerWithTitle:@"Edit Mii Name"
                       message:@"Use 1–10 characters. Fully close and reopen KartPad to update this Mii and its linked licenses, keeping friend codes and progress. To create a license, choose New inside the game and select this Mii."
                preferredStyle:UIAlertControllerStyleAlert];
  [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.text = currentName;
    field.placeholder = @"Player name";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.returnKeyType = UIReturnKeyDone;
  }];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [editor addAction:[UIAlertAction actionWithTitle:@"Save"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSString *name = editor.textFields.firstObject.text ?: @"";
    NSError *renameError = nil;
    NSUInteger updatedLicenses = 0;
    if (!KartPadStagePlayerName(slot, name, &updatedLicenses, &renameError)) {
      [weakSelf showIntegrationAlert:@"Mii Name Could Not Be Changed"
                             message:renameError.localizedDescription];
      return;
    }
    NSString *trimmed = [name stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *licenseDetail = updatedLicenses == 0
        ? @"To create a license with this name, choose New inside the game and select this Mii."
        : [NSString stringWithFormat:@"%lu linked license%@ will also be updated.",
            (unsigned long)updatedLicenses,
            updatedLicenses == 1 ? @"" : @"s"];
    [weakSelf showIntegrationAlert:@"Mii Name Scheduled"
                           message:[NSString stringWithFormat:
        @"Fully close KartPad from the app switcher and reopen it to apply %@. Returning to the KartPad menu and resuming does not apply pending edits. %@ A backup will be kept automatically.",
        trimmed, licenseDetail]];
  }]];
  [editor addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [controller presentViewController:editor animated:YES completion:nil];
}

- (void)showPlayerNameChoices {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  if (error != nil) {
    [self showIntegrationAlert:@"Player Identity Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  if (records.count == 1) {
    [self showPlayerNameEditorForRecord:records.firstObject];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *choices = [UIAlertController
      alertControllerWithTitle:@"Choose a Mii"
                       message:@"Choose which identity to rename. Every license linked to it will be updated."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *record in records) {
    [choices addAction:[UIAlertAction actionWithTitle:record[@"name"]
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action) {
      (void)action;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [weakSelf showPlayerNameEditorForRecord:record];
      });
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  choices.popoverPresentationController.sourceView = _overlay;
  choices.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:choices animated:YES completion:nil];
}

- (NSString *)licenseTitleForRecord:(NSDictionary<NSString *, id> *)record {
  NSString *pending = record[@"pendingOperation"];
  NSString *suffix = [pending isEqualToString:@"delete"] ? @" · deletion pending" :
      [pending isEqualToString:@"rename"] ? @" · name pending" : @"";
  return [NSString stringWithFormat:@"%@ · Slot %lu · %@%@",
      record[@"profileTitle"] ?: @"Mario Kart Wii",
      (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1),
      record[@"name"] ?: @"Unnamed", suffix];
}

- (void)showLicenseNameEditorForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *editor = [UIAlertController
      alertControllerWithTitle:@"Rename Existing License"
                       message:[NSString stringWithFormat:
          @"%@\n\nUse 1–10 characters. The selected license keeps its friend code, online account, records, and progress.",
          [self licenseTitleForRecord:record]]
                preferredStyle:UIAlertControllerStyleAlert];
  [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.text = record[@"name"] ?: @"";
    field.placeholder = @"License name";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.returnKeyType = UIReturnKeyDone;
  }];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [editor addAction:[UIAlertAction actionWithTitle:@"Save"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSError *renameError = nil;
    if (!KartPadStageLicenseRename(record[@"profileIdentifier"],
            [record[@"slot"] unsignedIntegerValue], record[@"createId"],
            editor.textFields.firstObject.text ?: @"", &renameError)) {
      [weakSelf showIntegrationAlert:@"License Could Not Be Renamed"
                             message:renameError.localizedDescription];
      return;
    }
    [weakSelf showIntegrationAlert:@"License Rename Scheduled"
                           message:@"Fully close KartPad from the app switcher and reopen it to apply the rename. Returning to the KartPad menu and resuming does not apply pending edits. The live save and matching Mii are backed up automatically."];
  }]];
  [editor addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [controller presentViewController:editor animated:YES completion:nil];
}

- (void)confirmLicenseDeletionForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  NSString *name = record[@"name"] ?: @"Unnamed";
  UIAlertController *confirm = [UIAlertController
      alertControllerWithTitle:[NSString stringWithFormat:
          @"Delete “%@” from %@ Slot %lu?", name,
          record[@"profileTitle"] ?: @"Mario Kart Wii",
          (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1)]
                       message:@"This permanently removes that license’s friend code, online account data, records, and progress. Its Mii appearance remains available. KartPad creates a save backup first."
                preferredStyle:UIAlertControllerStyleAlert];
  [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [confirm addAction:[UIAlertAction actionWithTitle:@"Delete License"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
    (void)action;
    NSError *deleteError = nil;
    if (!KartPadStageLicenseDeletion(record[@"profileIdentifier"],
            [record[@"slot"] unsignedIntegerValue], record[@"createId"],
            &deleteError)) {
      [weakSelf showIntegrationAlert:@"License Could Not Be Deleted"
                             message:deleteError.localizedDescription];
      return;
    }
    [weakSelf showIntegrationAlert:@"License Deletion Scheduled"
                           message:@"Fully close KartPad from the app switcher and reopen it to apply the deletion. Returning to the KartPad menu and resuming does not apply pending edits. Other licenses stay in their current slots. The live save is backed up automatically."];
  }]];
  [controller presentViewController:confirm animated:YES completion:nil];
}

- (void)showLicenseActionsForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *actions = [UIAlertController
      alertControllerWithTitle:[self licenseTitleForRecord:record]
                       message:@"Fully close KartPad from the app switcher and reopen it to apply changes. Returning to the KartPad menu and resuming does not apply pending edits. Rename keeps this license’s account and progress. Delete removes only this slot; other licenses stay in place."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [actions addAction:[UIAlertAction actionWithTitle:@"Rename License…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [weakSelf showLicenseNameEditorForRecord:record];
    });
  }]];
  [actions addAction:[UIAlertAction actionWithTitle:@"Delete License…"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [weakSelf confirmLicenseDeletionForRecord:record];
    });
  }]];
  [actions addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  actions.popoverPresentationController.sourceView = _overlay;
  actions.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:actions animated:YES completion:nil];
}

- (void)showLicenseChoices {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadLicenseRecords(&error);
  if (error != nil) {
    [self showIntegrationAlert:@"Licenses Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  if (records.count == 0) {
    [self showIntegrationAlert:@"No Existing Licenses"
                       message:@"Choose New on the license screen inside Mario Kart Wii or Retro Rewind, then select your Mii. Return here to rename or delete that license. Edit Mii Name changes your identity; it does not create a game license."];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *choices = [UIAlertController
      alertControllerWithTitle:@"Rename or Delete Licenses"
                       message:@"Choose the exact game profile and slot. A license with an established friend code should be renamed, not deleted."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *record in records) {
    [choices addAction:[UIAlertAction
        actionWithTitle:[self licenseTitleForRecord:record]
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [weakSelf showLicenseActionsForRecord:record];
      });
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  choices.popoverPresentationController.sourceView = _overlay;
  choices.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:choices animated:YES completion:nil];
}

- (void)showMiiRemovalChoices {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  NSArray<NSDictionary<NSString *, id> *> *licenses =
      error == nil ? KartPadLicenseRecords(&error) : @[];
  if (error != nil) {
    [self showIntegrationAlert:@"Miis Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *choices = [UIAlertController
      alertControllerWithTitle:@"Remove Mii Appearance"
                       message:@"This removes only an unused Mii appearance; it does not delete a Mario Kart license. Miis linked to a license must be changed or removed from Rename or Delete Licenses first."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *record in records) {
    NSUInteger linkedLicenses = 0;
    for (NSDictionary<NSString *, id> *license in licenses) {
      if ([license[@"createId"] isEqualToData:record[@"createIdBytes"]]) {
        ++linkedLicenses;
      }
    }
    NSString *title = linkedLicenses == 0 ? record[@"name"] :
        [NSString stringWithFormat:@"%@ — used by %lu license%@",
            record[@"name"], (unsigned long)linkedLicenses,
            linkedLicenses == 1 ? @"" : @"s"];
    NSUInteger slot = [record[@"slot"] unsignedIntegerValue];
    UIAlertActionStyle style = linkedLicenses == 0
        ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
    [choices addAction:[UIAlertAction actionWithTitle:title
                                                style:style
                                              handler:^(UIAlertAction *action) {
      (void)action;
      if (linkedLicenses > 0) {
        [weakSelf showIntegrationAlert:@"Mii Is In Use"
                               message:@"Open Rename or Delete Licenses to rename or delete the linked license first. Removing its Mii appearance here could leave the license unusable."];
        return;
      }
      NSError *removeError = nil;
      if (!KartPadStageMiiRemoval(slot, &removeError)) {
        [weakSelf showIntegrationAlert:@"Mii Could Not Be Removed"
                               message:removeError.localizedDescription];
        return;
      }
      [weakSelf showIntegrationAlert:@"Mii Removal Scheduled"
                             message:@"Fully close KartPad from the app switcher and reopen it to apply the appearance removal. Returning to the KartPad menu and resuming does not apply pending edits. A backup of the current Mii database will be kept automatically."];
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  choices.popoverPresentationController.sourceView = _overlay;
  choices.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:choices animated:YES completion:nil];
}

- (void)showMiiManager {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  NSArray<NSDictionary<NSString *, id> *> *licenses =
      error == nil ? KartPadLicenseRecords(&error) : @[];
  if (error != nil) {
    [self showIntegrationAlert:@"Miis Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  NSMutableArray<NSString *> *names = [NSMutableArray array];
  for (NSDictionary<NSString *, id> *record in records) {
    [names addObject:record[@"name"]];
  }
  NSString *summary = names.count == 0 ? @"No Miis found."
      : [names componentsJoinedByString:@", "];
  NSString *pending = KartPadHasPendingMiiChanges()
      ? @"\n\nChanges are pending. Fully close KartPad from the app switcher and reopen it to apply them before making another change. Returning to the KartPad menu and resuming does not apply pending edits." : @"";
  NSString *message = [NSString stringWithFormat:
      @"%lu Mii appearance%@ available: %@\n%lu existing license%@ found.\n\nA Mii supplies your name and appearance. A game license stores your progress and friend code. Create a license with New inside the game, then select your Mii.%@",
      (unsigned long)records.count, records.count == 1 ? @"" : @"s",
      summary, (unsigned long)licenses.count,
      licenses.count == 1 ? @"" : @"s", pending];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *manager = [UIAlertController
      alertControllerWithTitle:@"Player Identity"
                       message:message
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [manager addAction:[UIAlertAction actionWithTitle:@"Rename or Delete Licenses…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showLicenseChoices]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Edit Mii Name…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showPlayerNameChoices]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Import Mii Appearance…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf presentMiiImportPicker]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Remove Mii Appearance…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showMiiRemovalChoices]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"About Mii Appearance…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showMiiCreationHelp]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Done"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  manager.popoverPresentationController.sourceView = _overlay;
  manager.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:manager animated:YES completion:nil];
}

- (void)presentGameDataFolderPicker {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    return;
  }
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:KartPadGameDataContentTypes() asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [controller presentViewController:picker animated:YES completion:nil];
}

- (void)importExtractedGameDataFromURL:(NSURL *)url
                     deleteAfterwards:(BOOL)deleteAfterwards {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    return;
  }
  UIAlertController *progress =
      [UIAlertController alertControllerWithTitle:@"Importing Game Data"
                                          message:@"Validating the extracted disc…"
                                   preferredStyle:UIAlertControllerStyleAlert];
  _gameDataProgressAlert = progress;
  [controller presentViewController:progress animated:YES completion:nil];

  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *workError = KartPadPerformGameDataImport(
        url, ^(NSString *status, double fraction) {
          KartPadRuntimeOverlayHost *strongSelf = weakSelf;
          if (strongSelf != nil && strongSelf->_gameDataProgressAlert != nil) {
            strongSelf->_gameDataProgressAlert.message =
                [NSString stringWithFormat:@"%@\n%.0f%%", status, fraction * 100.0];
          }
        });
    if (deleteAfterwards) {
      [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadRuntimeOverlayHost *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      [strongSelf->_gameDataProgressAlert dismissViewControllerAnimated:YES completion:^{
        strongSelf->_gameDataProgressAlert = nil;
        if (workError != nil) {
          [strongSelf showIntegrationAlert:@"Game Data Import Failed"
                                   message:workError.localizedDescription];
          return;
        }
        [strongSelf showIntegrationAlert:@"Game Data Imported"
                                 message:@"The validated RMCP01 data is stored privately. Close and reopen KartPad to use the new copy."];
      }];
    });
  });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  (void)controller;
  NSURL *url = urls.firstObject;
  if (_choosingMiiImport) {
    _choosingMiiImport = NO;
    if (url == nil) return;
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&readError];
    NSString *name = nil;
    NSError *importError = nil;
    BOOL imported = data != nil &&
        KartPadStageMiiImport(data, &name, &importError);
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    if (!imported) {
      NSError *shownError = readError ?: importError;
      [self showIntegrationAlert:@"Mii Import Failed"
                         message:shownError.localizedDescription ?: @"The selected file could not be imported."];
      return;
    }
    [self showIntegrationAlert:@"Mii Import Scheduled"
                       message:[NSString stringWithFormat:
        @"%@ will be added the next time KartPad launches. A backup of the current Mii database will be kept automatically.",
        name.length > 0 ? name : @"The selected Mii"]];
    return;
  }
  if (url != nil) {
    [self importExtractedGameDataFromURL:url deleteAfterwards:YES];
  }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  (void)controller;
  _choosingMiiImport = NO;
}

- (void)gameOverlayRequestsGameDataChange:(SunPadGameOverlay *)overlay {
  (void)overlay;
  [self presentGameDataFolderPicker];
}

- (void)gameOverlayRequestsGameDataFolderImport:(SunPadGameOverlay *)overlay {
  (void)overlay;
  NSError *error = nil;
  NSArray<NSURL *> *roots = KartPadGameDataRootsInDocuments(&error);
  if (roots.count == 0) {
    NSLog(@"[KartPad] %@", KartPadDocumentsFolderScanDetail(error));
    [self presentGameDataFolderPicker];
    return;
  }
  if (roots.count == 1) {
    [self importExtractedGameDataFromURL:roots.firstObject deleteAfterwards:NO];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    return;
  }
  NSString *message = @"Choose a Mario Kart Wii WBFS, ISO, or extracted DATA folder from this signed app's KartPad folder.";
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"KartPad Folder"
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSURL *root in roots) {
    [alert addAction:[UIAlertAction actionWithTitle:root.lastPathComponent
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
      (void)action;
      [weakSelf importExtractedGameDataFromURL:root deleteAfterwards:NO];
    }]];
  }
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                            style:UIAlertActionStyleCancel handler:nil]];
  [controller presentViewController:alert animated:YES completion:nil];
}

- (void)gameOverlayRequestsGameDataRemoval:(SunPadGameOverlay *)overlay {
  (void)overlay;
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  NSString *supportRoot = KartPadSupportRoot();
  NSError *error = nil;
  [NSFileManager.defaultManager createDirectoryAtPath:supportRoot
                          withIntermediateDirectories:YES
                                           attributes:@{NSFileProtectionKey:
      NSFileProtectionCompleteUntilFirstUserAuthentication}
                                                error:&error];
  if (error == nil) {
    [@"remove-on-next-launch\n" writeToFile:KartPadRemovalMarkerPath()
                                   atomically:YES encoding:NSUTF8StringEncoding
                                      error:&error];
  }
  if (error != nil) {
    [self showIntegrationAlert:@"Game Data Removal Failed"
                       message:error.localizedDescription];
    return;
  }

  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    [NSFileManager.defaultManager removeItemAtPath:KartPadRemovalMarkerPath()
                                             error:nil];
    return;
  }
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Game Data Removal Scheduled"
                       message:@"KartPad will remove the private game-data copy before emulation starts on the next launch. Saves and control settings are not affected."
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Undo"
                                             style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSError *undoError = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:KartPadRemovalMarkerPath()
                                                  error:&undoError]) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [weakSelf showIntegrationAlert:@"Undo Failed"
                               message:undoError.localizedDescription];
      });
    }
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
  [controller presentViewController:alert animated:YES completion:nil];
}

- (void)showControllerButtonAssignment:(uint16_t)gameButton title:(NSString *)title {
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
      message:@"Choose a physical button. If it is already assigned, the two assignments swap. Applies to all connected controllers; touch controls keep their layout."
      preferredStyle:UIAlertControllerStyleActionSheet];
  NSArray<NSString *> *names = @[@"A / Cross / bottom", @"B / Circle / right",
      @"X / Square / left", @"Y / Triangle / top", @"Left Shoulder / L1"];
  const SunPadPhysicalControllerButton buttons[] = {SunPadPhysicalControllerButtonA,
      SunPadPhysicalControllerButtonB, SunPadPhysicalControllerButtonX,
      SunPadPhysicalControllerButtonY, SunPadPhysicalControllerButtonLeftShoulder};
  for (NSUInteger index = 0; index < names.count; ++index) {
    const SunPadPhysicalControllerButton physical = buttons[index];
    [sheet addAction:[UIAlertAction actionWithTitle:names[index]
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [SunPadControllerMappingStore setMapping:SunPadControllerButtonMappingByAssigning(
          [SunPadControllerMappingStore mapping], physical, gameButton)];
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)showControllerButtonMapping {
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Controller Button Mapping"
      message:@"Choose the game button to reassign. Sticks, D-pad, Menu, and triggers remain direct."
      preferredStyle:UIAlertControllerStyleActionSheet];
  const SunPadControllerButtonMapping mapping = [SunPadControllerMappingStore mapping];
  NSArray<NSString *> *names = @[@"A — Accelerate / Confirm", @"B — Drift / Back",
      @"X — Rear View", @"Y", @"ZR — Rear View"];
  const uint16_t buttons[] = {SunPadButtonA, SunPadButtonB, SunPadButtonX, SunPadButtonY, SunPadButtonZ};
  const SunPadPhysicalControllerButton physical[] = {mapping.gameA, mapping.gameB,
      mapping.gameX, mapping.gameY, mapping.gameZ};
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSUInteger index = 0; index < names.count; ++index) {
    NSString *name = names[index];
    const uint16_t gameButton = buttons[index];
    NSString *label = [NSString stringWithFormat:@"%@: %@", name,
        SunPadPhysicalControllerButtonName(physical[index])];
    [sheet addAction:[UIAlertAction actionWithTitle:label
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [weakSelf showControllerButtonAssignment:gameButton title:name];
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Reset Face Button Mapping"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [SunPadControllerMappingStore reset];
    [weakSelf showMultiplayerMessage:@"Default Mapping Restored"
        message:@"The default A/B/X/Y and left-shoulder mapping will apply to new controller input."];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)gameOverlayRequestsControllerMapping:(SunPadGameOverlay *)overlay {
  (void)overlay;
  KartPadPhysicalControllers *controllers = [KartPadPhysicalControllers sharedControllers];
  [controllers reconcileControllers];
  NSString *players = [[controllers playerDescriptions] componentsJoinedByString:@"\n"];
  NSString *message = players;
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Controller Setup"
      message:message preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [sheet addAction:[UIAlertAction actionWithTitle:@"Customize Face Buttons…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf showControllerButtonMapping];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Pairing & Compatibility…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf showMultiplayerMessage:@"Connect & Register Controllers"
        message:@"Pair pads in system Bluetooth settings. In the game, choose Multiplayer and press mapped A on each pad at Register Controllers. Touch shares Player 1.\n\nDualShock 4 / DualSense defaults: Cross = A, Circle = B, Square = X, Triangle = Y. GameCube-style pads need OS Extended Gamepad support. Original GameCube USB adapters are not supported on iPad."];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (NSString *)gameOverlayDiagnosticContext:(SunPadGameOverlay *)overlay {
  (void)overlay;
  return @"product=KartPad\nsurface=SDL UIKit+Metal\ncore=full-retail\nprivateDataIncluded=false";
}

- (NSString *)gameOverlayPerformanceProfile:(SunPadGameOverlay *)overlay {
  (void)overlay;
  return @"full-retail-simulator";
}

@end

extern "C" bool KartPadMobileEnsureGameDataAvailable() {
  KartPadApplyPrivateServerAtLaunch();
  NSError *miiError = nil;
  if (!KartPadApplyPendingMiiDatabase(&miiError)) {
    NSLog(@"[KartPad] pending Mii changes were not applied: %@",
          miiError.localizedDescription);
  }
  if (!NSThread.isMainThread) {
    __block BOOL available = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
      available = [[[KartPadFirstLaunchHost alloc] init] run];
    });
    return available;
  }
  return [[[KartPadFirstLaunchHost alloc] init] run];
}

extern "C" const char *KartPadMobileSelectedRuntimeProfile() {
  return gKartPadRetroRewindSelected ? "retro_rewind" : "base";
}

extern "C" void KartPadMobileServiceMainMenu() {
  if (gKartPadMainMenuRequested && gRuntimeOverlayHost != nil && NSThread.isMainThread) {
    [gRuntimeOverlayHost runMainMenu];
  }
}

extern "C" void KartPadMobileRuntimeHostInstall(void *sdlWindow) {
  if (sdlWindow == nullptr || !NSThread.isMainThread) {
    NSLog(@"[KartPad] refusing overlay installation away from UIKit's main thread");
    return;
  }
  [gRuntimeOverlayHost uninstall];
  gRuntimeOverlayHost =
      [[KartPadRuntimeOverlayHost alloc] initWithSDLWindow:(SDL_Window *)sdlWindow];
}

extern "C" void KartPadMobileRuntimeHostUninstall() {
  [gRuntimeOverlayHost uninstall];
  gRuntimeOverlayHost = nil;
}

extern "C" bool KartPadMobileReadRuntimeSettings(
    KartPadMobileRuntimeSettings *settings) {
  if (settings == nullptr) {
    return false;
  }
  SunPadSettings *source = [SunPadSettings sharedSettings];
  settings->aspectRatioMode = static_cast<int>(source.aspectRatioMode);
  settings->resolutionScale = source.renderScaleFloat;
  settings->showFps = source.showFPSCounter ? 1 : 0;
  return true;
}

extern "C" bool KartPadMobileReadClassicInput(
    KartPadMobileClassicInputSnapshot *snapshot) {
  return KartPadMobileReadClassicInputForPlayer(0, snapshot);
}

extern "C" bool KartPadMobileIsControllerConnected(unsigned int player) {
  return [[KartPadPhysicalControllers sharedControllers] isPlayerConnected:player];
}

extern "C" bool KartPadMobileReadClassicInputForPlayer(
    unsigned int player, KartPadMobileClassicInputSnapshot *snapshot) {
  if (snapshot == nullptr || gRuntimeOverlayHost == nil) {
    return false;
  }
  SunPadInputState source{};
  if (player == 0) {
    source = [[SunPadInputMixer sharedMixer] consumeMergedState];
  } else if (player < 4) {
    [[KartPadPhysicalControllers sharedControllers] consumePlayer:player
                                                            state:&source];
  } else {
    return false;
  }
  KartPadClassicInputState adapted =
      kartpad::mobile::AdaptSunPadInput(source);
  KartPadMotionSteering *motion = [KartPadMotionSteering sharedSteering];
  const BOOL shakeTrick = player == 0 ? [motion consumeShakeTrick] : NO;
  if (player == 0 &&
      [KartPadPhysicalControllers sharedControllers].connectedControllerCount == 0) {
    kartpad::mobile::ApplyMotionInput(adapted, motion.currentSteering,
                                      shakeTrick);
  }
  snapshot->buttons = adapted.buttons;
  snapshot->leftStickX = std::clamp(static_cast<float>(adapted.leftStickX) / 127.0f,
                                   -1.0f, 1.0f);
  snapshot->leftStickY = std::clamp(static_cast<float>(adapted.leftStickY) / 127.0f,
                                   -1.0f, 1.0f);
  snapshot->connected = adapted.connected ? 1 : 0;
  return true;
}

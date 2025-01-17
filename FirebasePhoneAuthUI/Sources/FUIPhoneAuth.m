//
//  Copyright (c) 2016 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "FirebasePhoneAuthUI/Sources/FUIPhoneAuth_Internal.h"

@import FirebaseAuthUI;

#import "FirebasePhoneAuthUI/Sources/FUICountryCodes.h"
#import "FirebasePhoneAuthUI/Sources/FUIPhoneAuthStrings.h"
#import "FirebasePhoneAuthUI/Sources/FUIPhoneEntryViewController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FUIPhoneAuth {
  /** The @c FUIAuth instance of the application. */
  FUIAuth *_authUI;

  /** The callback which should be invoked when the sign in flow completes (or is cancelled.) */
  FUIAuthProviderSignInCompletionBlock _pendingSignInCallback;
  
  /** Available country codes For the authUI to use. */
  FUICountryCodes *_countryCodes;
}

+ (NSBundle *)bundle {
  return [FUIAuthUtils bundleNamed:FUIPhoneAuthBundleName
                 inFrameworkBundle:[NSBundle bundleForClass:[self class]]];
}

- (instancetype)initWithAuthUI:(FUIAuth *)authUI {
  if (self = [super init]) {
    _authUI = authUI;
    _countryCodes = [[FUICountryCodes alloc] init];
  }

  return self;
}

- (instancetype)initWithAuthUI:(FUIAuth *)authUI
          whitelistedCountries:(NSSet<NSString *> *)countries {
  NSParameterAssert(countries);
  NSParameterAssert(countries.count > 0);
  if (self = [self initWithAuthUI:authUI]) {
    [_countryCodes whitelistCountries:countries];
    NSAssert(_countryCodes.count, @"No available country code found.");
    if (!_countryCodes.count) {
      return nil;
    }
  }
  return self;
}

- (instancetype)initWithAuthUI:(FUIAuth *)authUI
          blacklistedCountries:(NSSet<NSString *> *)countries {
  if (!countries.count) {
    return nil;
  }
  if (self = [self initWithAuthUI:authUI]) {
    [_countryCodes blacklistCountries:countries];
    NSAssert(_countryCodes.count, @"No available country code found.");
    if (!_countryCodes.count) {
      return nil;
    }
  }
  return self;
}

#pragma mark - FUIAuthProvider

- (nullable NSString *)providerID {
  return FIRPhoneAuthProviderID;
}

/** @fn accessToken:
    @brief Phone Auth token is matched by FirebaseUI User Access Token
 */
- (nullable NSString *)accessToken {
  return nil;
}

/** @fn idToken:
    @brief Phone Auth Token Secret is matched by FirebaseUI User Id Token
 */
- (nullable NSString *)idToken {
  return nil;
}

- (NSString *)shortName {
  return @"Phone";
}

- (NSString *)signInLabel {
  return FUIPhoneAuthLocalizedString(kPAStr_SignInWithPhone);
}

- (UIImage *)icon {
  return [FUIAuthUtils imageNamed:@"ic_phone" fromBundle:[FUIPhoneAuth bundle]];
}

- (UIColor *)buttonBackgroundColor {
  return [UIColor colorWithRed:68.0f/255.0f green:197.0f/255.0f blue:166.0f/255.0f alpha:1.0f];
}

- (UIColor *)buttonTextColor {
  return [UIColor whiteColor];
}

- (void)signInWithPresentingViewController:(UIViewController *)presentingViewController {
  [self signInWithPresentingViewController:presentingViewController phoneNumber:nil];
}


- (void)signInWithPresentingViewController:(UIViewController *)presentingViewController
                               phoneNumber:(nullable NSString *)phoneNumber {
  [_authUI signInWithProviderUI:self presentingViewController:presentingViewController
                   defaultValue:phoneNumber];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
- (void)signInWithEmail:(nullable NSString *)email
    presentingViewController:(nullable UIViewController *)presentingViewController
                  completion:(nullable FUIAuthProviderSignInCompletionBlock)completion {
  [self signInWithDefaultValue:email
      presentingViewController:presentingViewController
                    completion:completion];
}
#pragma clang diagnostic pop

- (void)signInWithDefaultValue:(nullable NSString *)defaultValue
      presentingViewController:(nullable UIViewController *)presentingViewController
                    completion:(nullable FUIAuthProviderSignInCompletionBlock)completion {
  _pendingSignInCallback = completion;
  
  FUIPhoneAuth *delegate = [_authUI providerWithID:FIRPhoneAuthProviderID];
  if (!delegate) {
    NSError *error = [FUIAuthErrorUtils errorWithCode:FUIAuthErrorCodeCantFindProvider
                                             userInfo:@{
                       FUIAuthErrorUserInfoProviderIDKey : FIRPhoneAuthProviderID
                     }];
    [self callbackWithCredential:nil error:error result:^(FIRUser *_Nullable user,
                                                          NSError *_Nullable error) {
      if (error) {
        [FUIAuthBaseViewController showAlertWithMessage:error.localizedDescription
                               presentingViewController:presentingViewController];
      }
    }];
    return;
  }

  UIViewController *controller = [[FUIPhoneEntryViewController alloc] initWithAuthUI:_authUI
                                                                         phoneNumber:defaultValue
                                                                        countryCodes:_countryCodes];
  UINavigationController *navigationController =
      [[UINavigationController alloc] initWithRootViewController:controller];
  [presentingViewController presentViewController:navigationController animated:YES completion:nil];
}

- (void)signOut {
  return;
}

- (BOOL)handleOpenURL:(NSURL *)URL sourceApplication:(nullable NSString *)sourceApplication {
  return NO;
}

- (void)callbackWithCredential:(nullable FIRAuthCredential *)credential
                         error:(nullable NSError *)error
                        result:(nullable FIRAuthResultCallback)result {
  FUIAuthProviderSignInCompletionBlock callback = _pendingSignInCallback;

  FIRAuthResultCallback resultAuthCallback = ^(FIRUser *_Nullable user, NSError *_Nullable error) {
    if (!error) {
      self->_pendingSignInCallback = nil;
    }
    if (result) {
      result(user, error);
    }
  };
  if (callback) {
    callback(credential, error, resultAuthCallback, nil);
  }
}

+ (UIAlertController *)alertControllerForError:(NSError *)error
                                 actionHandler:(nullable FUIAuthAlertActionHandler)actionHandler {
  NSString *message;
  if (error.code == FIRAuthErrorCodeInvalidPhoneNumber) {
    message = FUIPhoneAuthLocalizedString(kPAStr_IncorrectPhoneMessage);
  } else if (error.code == FIRAuthErrorCodeInvalidVerificationCode) {
    message = FUIPhoneAuthLocalizedString(kPAStr_IncorrectCodeMessage);
  } else if (error.code == FIRAuthErrorCodeTooManyRequests) {
    message = FUIPhoneAuthLocalizedString(kPAStr_TooManyCodesSent);
  } else if (error.code == FIRAuthErrorCodeQuotaExceeded) {
    message = FUIPhoneAuthLocalizedString(kPAStr_MessageQuotaExceeded);
  } else if (error.code == FIRAuthErrorCodeSessionExpired) {
    message = FUIPhoneAuthLocalizedString(kPAStr_MessageExpired);
  } else if ((error.code >= FIRAuthErrorCodeMissingPhoneNumber
             && error.code <= FIRAuthErrorCodeAppNotVerified)
             || error.code >= FIRAuthErrorCodeInternalError) {
    message = FUIPhoneAuthLocalizedString(kPAStr_InternalErrorMessage);
  } else {
    message = error.localizedDescription;
  }
  UIAlertController *alertController =
      [UIAlertController alertControllerWithTitle:nil
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *okAction =
      [UIAlertAction actionWithTitle:FUIPhoneAuthLocalizedString(kPAStr_Done)
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *_Nonnull action) {
        if (actionHandler) {
          actionHandler();
        }
      }];
  [alertController addAction:okAction];
  return alertController;
}

@end

NS_ASSUME_NONNULL_END

//
//  SocialManager.swift
//  HolyBible
//
//  Created by Margarita Zherikhova on 13/12/16.
//  Copyright © 2016 Globus ltd. All rights reserved.
//

import FBSDKLoginKit
import Foundation
import ok_ios_sdk
import TwitterKit
import VK_ios_sdk

enum SocialManagerProvider: String {
    case vk
    case fb
    case ok
    case tw
}

typealias SocialManagerCompletion = (_ provider: SocialManagerProvider, _ success: Bool, _ accessToken: String?) -> Void

fileprivate class VKDelegate: NSObject, VKSdkDelegate, VKSdkUIDelegate {
    fileprivate var completionClosure: SocialManagerCompletion?
    
    // MARK: VKSdkDelegate
    func completion(closure: @escaping SocialManagerCompletion) {
        completionClosure = closure
    }
    
    func vkSdkUserAuthorizationFailed() {
        completionClosure?(.vk, false, nil)
    }
    
    func vkSdkAccessAuthorizationFinished(with result: VKAuthorizationResult!) {
        if let accessToken = result.token?.accessToken {
            completionClosure?(.vk, true, accessToken)
        } else {
            completionClosure?(.vk, false, nil)
        }
    }
    // MARK: VKSdkUIDelegate
    func vkSdkShouldPresent(_ controller: UIViewController!) {
        let rootVC = UIApplication.shared.delegate?.window??.rootViewController
        rootVC?.present(controller, animated: true, completion: nil)
    }
    
    func vkSdkNeedCaptchaEnter(_ captchaError: VKError!) {
        
    }
}

class SocialManager {
    static let shared = SocialManager()
    // MARK: Fileprivate properties
    fileprivate var authCompletionClosure: SocialManagerCompletion?
    fileprivate lazy var vkDelegate = VKDelegate()
    fileprivate lazy var okSettings = { () -> OKSDKInitSettings in
        let settings = OKSDKInitSettings()
        settings.appId = kOKAppID
        settings.appKey = kOKAppKey
        settings.controllerHandler = { () -> UIViewController? in
            let rootVC = UIApplication.shared.delegate?.window??.rootViewController
            return rootVC
        }
        return settings
    }()
    
    init() {
    }
    
    func auth(_ provider: SocialManagerProvider, _ closure: SocialManagerCompletion?) {
        authCompletionClosure = closure
        switch provider {
        case .vk:
            vkAuth()
        case .fb:
            fbAuth()
        case .ok:
            okAuth()
        case .tw:
            twAuth()
        }
    }
}

// MARK: AppDelegate handling methods
extension SocialManager {
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        //VK
        VKSdk.processOpen(url, fromApplication: sourceApplication)
        //FB
        let fbDelegate = FBSDKApplicationDelegate.sharedInstance()
        fbDelegate?.application(application, open: url, sourceApplication: sourceApplication, annotation: annotation)
        //OK
        OKSDK.open(url)
        //TW
        Twitter.sharedInstance().application(application, open:url, options: annotation as! [AnyHashable : Any])
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        //VK
        VKSdk.processOpen(url, fromApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String)
        //FB
        let fbDelegate = FBSDKApplicationDelegate.sharedInstance()
        fbDelegate?.application(app,
                               open: url,
                               sourceApplication: options[UIApplicationOpenURLOptionsKey.sourceApplication] as? String,
                               annotation: options[UIApplicationOpenURLOptionsKey.annotation])
        //OK
        OKSDK.open(url)
        //TW
        _ = Twitter.sharedInstance().application(app, open:url, options: options)
        return true
    }
}

// MARK: Fileprivate properties
fileprivate extension SocialManager {
    func vkAuth() {
        VKSdk.initialize(withAppId: kVKAppID)
        VKSdk.instance().register(vkDelegate)
        VKSdk.instance().uiDelegate = vkDelegate
        vkDelegate.completion { [unowned self] (provider, success, accessToken) in
            self.authCompletionClosure?(provider, success, accessToken)
        }
        if let accessToken = VKSdk.accessToken()?.accessToken {
            authCompletionClosure?(.vk, true, accessToken)
        } else {
            VKSdk.authorize(["friends", "email"], with: .unlimitedToken)
        }
    }
    
    func fbAuth() {
        let fb = FBSDKLoginManager()
        let rootVC = UIApplication.shared.delegate?.window??.rootViewController!
        fb.logIn(withReadPermissions: ["public_profile"], from: rootVC) { [unowned self] (result, _) in
            if let accessToken = result?.token?.tokenString {
                self.authCompletionClosure?(.fb, true, accessToken)
            } else {
                self.authCompletionClosure?(.fb, false, nil)
            }
        }
    }
    
    func okAuth() {
        OKSDK.clearAuth()
        OKSDK.initWith(okSettings)
        OKSDK.authorize(withPermissions: ["VALUABLE_ACCESS", "LONG_ACCESS_TOKEN"],
                        success: { [unowned self] (response) in
                            if let token = (response as? NSArray)?.firstObject as? String {
                                self.authCompletionClosure?(.ok, true, token)
                            } else {
                                self.authCompletionClosure?(.ok, false, nil)
                            }
            }) { [unowned self] (_) in
               self.authCompletionClosure?(.ok, false, nil)
        }
    }
    
    func twAuth() {
        Twitter.sharedInstance().start(withConsumerKey: kTwitterKey, consumerSecret: kTwitterSecret)
        Twitter.sharedInstance().logIn(withMethods: .all) { (session, _) in
            if let token = session?.authToken, let secret = session?.authTokenSecret {
                self.authCompletionClosure?(.tw, true, token + ";" + secret)
            } else {
                self.authCompletionClosure?(.tw, false, nil)
            }
        }
    }
}

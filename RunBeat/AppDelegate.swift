//
//  AppDelegate.swift
//  RunBeat
//
//  Created by Mark Shore on 8/29/25.
//

import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Auth is handled by FirebaseService
        
        return true
    }
}
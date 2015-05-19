//
//  APCDStack.swift
//  APCDStack
//
//  Created by Deszip on 14/09/14.
//  Copyright (c) 2014 - 2015 Alterplay. All rights reserved.
//

import Foundation
import CoreData

public class APCDStack {
    
    //MARK: Constants
    
    private let kAppBundleNameKey   = "CFBundleName"
    private let kModelMOMExtension  = "mom"
    private let kModelMOMDExtension = "momd"
    
    //MARK: Settings
    
    public var storeName: String    = ""
    public var storeType: String    = NSSQLiteStoreType
    public var appGroupID: String   = ""
    
    //MARK: Model and coordinator
    
    private lazy var _mom: NSManagedObjectModel? = {
        if let modelUrl = self.modelURL() {
            if let mom = NSManagedObjectModel(contentsOfURL: modelUrl) {
                return mom
            }
        }
        
        let currentBundle = NSBundle(forClass: object_getClass(self))
        if let mom = NSManagedObjectModel.mergedModelFromBundles([currentBundle]) {
            return mom
        }
        
        return nil
    }()
    
    private lazy var _psc: NSPersistentStoreCoordinator? = {
        let storeOptions = [NSMigratePersistentStoresAutomaticallyOption : true,
                            NSInferMappingModelAutomaticallyOption : true]
        
        if let _ = self._mom {
            let psc = NSPersistentStoreCoordinator(managedObjectModel: self._mom!)
            let psUrl = self.storeURL().URLByAppendingPathComponent("\(self.storeName).sqlite")
            var error: NSError?
            if let _ = psc.addPersistentStoreWithType(self.storeType, configuration: nil, URL: psUrl, options: storeOptions, error: &error) {
                return psc
            } else {
                NSException.raise("Failed to add store to coordinator:", format: "%@", arguments: getVaList([error!]))
            }
        } else {
            NSException.raise("Can't find model!", format: "", arguments: getVaList([""]))
        }
        
        return nil
        
        }()
    
    //MARK: Contexts
    
    lazy var mainMOC: NSManagedObjectContext = {
        let mainMOC = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        mainMOC.parentContext = self.writerMOC
        
        return mainMOC
        }()
    
    lazy var workerMOC: NSManagedObjectContext = {
        let workerMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        workerMOC.parentContext = self.mainMOC
        
        return workerMOC
        }()
    
    lazy var writerMOC: NSManagedObjectContext = {
        let writerMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        writerMOC.persistentStoreCoordinator = self._psc
        
        return writerMOC
        }()
    
    private var spawnedContexts: Dictionary<String, NSManagedObjectContext> = Dictionary()
    
    //MARK: Initializers
    
    public class var defaultInstance: APCDStack {
        struct Singleton {
            static let instance = APCDStack(storeType: "", storeName: "", appGroupID: "")
        }
        
        return Singleton.instance
    }
    
    init(storeType: String, storeName: String, appGroupID: String) {
        self.storeType = storeType;
        self.storeName = storeName;
        self.appGroupID = appGroupID;
    }
    
    convenience init(storeType: String) {
        self.init(storeType: storeType, storeName: "", appGroupID: "")
        self.storeName = self.applicationName()
    }
    
    convenience init(storeType: String, storeName: String) {
        self.init(storeType: storeType, storeName: storeName, appGroupID: "")
    }
    
    //MARK: Context management
    
    public func spawnBackgroundContextForThread(thread: NSThread) -> NSManagedObjectContext {
        return self.spawnBackgroundContextWithName(thread.description)
    }
    
    public func spawnBackgroundContextWithName(name: String) -> NSManagedObjectContext {
        if let context = spawnedContexts[name] {
            return context
        }
        
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = mainMOC
        spawnedContexts[name] = context
        
        return context
    }
    
    public func performSave() {
        mainMOC.performBlock { () -> Void in
            var saveError: NSError?
            if !self.mainMOC.save(&saveError) {
                println("APCDStore: error saving main context: \(saveError)")
            }
            
            self.writerMOC.performBlock({ () -> Void in
                var saveError: NSError?
                if !self.writerMOC.save(&saveError) {
                    println("APCDStore: error saving writer context: \(saveError)")
                }
            })
        }
    }
    
    //MARK: Tools
    
    private func modelURL() -> NSURL? {
        let currentBundle = NSBundle(forClass: object_getClass(self))
        if let modelPath = currentBundle.pathForResource(self.storeName, ofType:kModelMOMDExtension) {
            return NSURL(fileURLWithPath: modelPath)
        } else if let modelPath = currentBundle.pathForResource(self.storeName, ofType:kModelMOMExtension) {
            return NSURL(fileURLWithPath: modelPath)
        }
        
        return nil
    }
    
    private func storeURL() -> NSURL {
        
        #if os(iOS)
            
            if self.appGroupID.lengthOfBytesUsingEncoding(NSUTF8StringEncoding) > 0 {
                return NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier(self.appGroupID)!
            }
            
            let urls = NSFileManager.defaultManager().URLsForDirectory(.LibraryDirectory, inDomains:.UserDomainMask)
            return urls[0] as! NSURL
            
            #else
            
            let urls = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)
            let supportUrl = urls[0] as! NSURL
            let currentBundle = NSBundle(forClass: object_getClass(self))
            let appUrl = supportUrl.URLByAppendingPathComponent(self.applicationName(), isDirectory: true)
            if !NSFileManager.defaultManager().fileExistsAtPath(appUrl.path!) {
            NSFileManager.defaultManager().createDirectoryAtURL(appUrl, withIntermediateDirectories: true, attributes: nil, error: nil)
            }
            
            return appUrl
            
        #endif
    }
    
    private func applicationName() -> String {
        return NSBundle(forClass: object_getClass(self)).objectForInfoDictionaryKey(kAppBundleNameKey) as! String
    }
}
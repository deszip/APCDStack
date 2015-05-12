//
//  APCDStore.swift
//  APCDStoreExample
//
//  Created by Deszip on 14/09/14.
//  Copyright (c) 2014 Alterplay. All rights reserved.
//

import Foundation
import CoreData

public class APCDStore {
    
    //MARK: Settings
    
    public var storeName: String = ""
    public var storeType: String = NSSQLiteStoreType
    
    //MARK: Model and coordinator
    
    private lazy var _mom: NSManagedObjectModel = {
        let momdPath = NSBundle.mainBundle().pathForResource(self.storeName, ofType: "momd")
        let momdURL = NSURL.fileURLWithPath(momdPath!)
        let mom = NSManagedObjectModel(contentsOfURL: momdURL!)
 
        return mom!
    }()
    
    private lazy var _psc: NSPersistentStoreCoordinator = {
        let storeOptions = [NSMigratePersistentStoresAutomaticallyOption : true,
                            NSInferMappingModelAutomaticallyOption : true]
        
        let psc = NSPersistentStoreCoordinator(managedObjectModel: self._mom)
        let psName = "\(self.storeName).sqlite"
        let psURL = self.applicationDocumentsDirectory().URLByAppendingPathComponent(psName)
        var error: NSError?
        if (psc.addPersistentStoreWithType(self.storeType, configuration: nil, URL: psURL, options: storeOptions, error: &error) == nil) {
            println("Error initializing NSPersistentStoreCoordinator: \(error)")
        }
        
        return psc
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
    
    public class var defaultInstance: APCDStore {
        struct Singleton {
            static let instance = APCDStore()
        }
            
        return Singleton.instance
    }
    
    init() {
        self.storeName = self.applicationDisplayName()
    }
    
    convenience init(storeType: String) {
        self.init()
        self.storeType = storeType
    }
    
    convenience init(storeType: String, storeName: String) {
        self.init()
        self.storeType = storeType
        self.storeName = storeName
    }
    
    deinit {
        //...
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
    
    private func applicationDocumentsDirectory() -> NSURL {
        let fileManager = NSFileManager.defaultManager()
        let urls: Array<NSURL> = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask) as! Array<NSURL>
        
        return urls.last!
    }
    
    private func applicationDisplayName() -> String {
        let name = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleName") as! String

        return name
    }
}
// Copyright (c) 2014–2015 Alterplay (http://www.alterplay.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import CoreData

public class APCDStack {

    public struct Configuration {
        public let storeName: String
        public let storeType: String
        public let appGroupID: String
        public let bundleID: String
        
        public init(storeName: String, storeType: String, appGroupID: String, bundleID: String) {
            self.storeName = storeName
            self.storeType = storeType
            self.appGroupID = appGroupID
            self.bundleID = bundleID
        }
        
        /**
        Factory method for configuration
        
        :returns: Configuration struct initialized with SQLite store type. Suitable in most simple cases.
        */
        public static func defaultConfiguration() -> Configuration {
            return Configuration(storeName: "", storeType: NSSQLiteStoreType, appGroupID: "", bundleID: "")
        }
    }
    
    //MARK: Constants
    
    private let kAppBundleNameKey   = "CFBundleName"
    private let kModelMOMExtension  = "mom"
    private let kModelMOMDExtension = "momd"
    
    //MARK: Settings
    
    private let configuration: Configuration
    
    //MARK: Model and coordinator
    
    private lazy var _mom: NSManagedObjectModel? = {
        if let modelUrl = self.modelURL() {
            if let mom = NSManagedObjectModel(contentsOf: modelUrl) {
                return mom
            }
        }
        
        if let mom = NSManagedObjectModel.mergedModel(from: [self.workingBundle()]) {
            return mom
        }
        
        return nil
    }()
    
    private lazy var _psc: NSPersistentStoreCoordinator? = {
        let storeOptions = [NSMigratePersistentStoresAutomaticallyOption : true,
                            NSInferMappingModelAutomaticallyOption : true]
        
        if let _ = self._mom {
            let psc: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self._mom!)
            
            var storeName: String = self.configuration.storeName
            if storeName.unicodeScalars.count == 0 {
                storeName = self.applicationName()
            }
            
            let psUrl = try! self.storeURL().appendingPathComponent("\(storeName).sqlite")
            
            do {
                try psc.addPersistentStore(ofType: self.configuration.storeType, configurationName: nil, at: psUrl, options: storeOptions)
                return psc
            } catch let error {
                NSException.raise("Failed to add store to coordinator:" as NSExceptionName, format: "%@", arguments: getVaList(["\(error)"]))
            }
        } else {
            NSException.raise("Can't find model!" as NSExceptionName, format: "", arguments: getVaList([""]))
        }
        
        return nil
        
    }()
    
    //MARK: Contexts
    
    /// Context attached to store, used for writing to store only
    public private(set) lazy var writerMOC: NSManagedObjectContext = {
        let writerMOC = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        writerMOC.persistentStoreCoordinator = self._psc
        
        return writerMOC
        }()
    
    /// Main thread context for UI interactions
    public private(set) lazy var mainMOC: NSManagedObjectContext = {
        let mainMOC = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        mainMOC.parent = self.writerMOC
        
        return mainMOC
        }()
    
    //MARK: Initializer
    
    public init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    //MARK: Context management
    
    /**
    Creates new background context and assigns it as a child to main context
    
    :returns: spawned context
    */
    public func spawnBackgroundContext() -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.parent = mainMOC
        
        return context
    }
    
    /**
    Saves main and writer contexts
    */
    public func performSave() {
        mainMOC.performAndWait { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            do {
                try strongSelf.mainMOC.save()
                strongSelf.writerMOC.perform {
                    do {
                        try strongSelf.writerMOC.save()
                    } catch let saveError {
                        print("APCDStack: error saving writer context: \(saveError)")
                    }
                }
            } catch let saveError {
                print("APCDStack: error saving main context: \(saveError)")
            }
        }
    }
    
    //MARK: Tools
    
    private func modelURL() -> URL? {
        let currentBundle = self.workingBundle()
        if let modelPath = currentBundle.pathForResource(self.configuration.storeName, ofType:kModelMOMDExtension) {
            return URL(fileURLWithPath: modelPath)
        } else if let modelPath = currentBundle.pathForResource(self.configuration.storeName, ofType:kModelMOMExtension) {
            return URL(fileURLWithPath: modelPath)
        }
        
        return nil
    }
    
    private func storeURL() -> URL {
        
        #if os(iOS)
            
            if self.configuration.appGroupID.lengthOfBytes(using: String.Encoding.utf8) > 0 {
                return FileManager.default().containerURLForSecurityApplicationGroupIdentifier(self.configuration.appGroupID)!
            }
            
            let urls = FileManager.default().urlsForDirectory(.libraryDirectory, inDomains:.userDomainMask)
            return urls[0]
            
        #else
            
            let urls = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)
            let supportUrl = urls[0] as! NSURL
            let appUrl = supportUrl.URLByAppendingPathComponent(self.applicationName(), isDirectory: true)
            if !NSFileManager.defaultManager().fileExistsAtPath(appUrl.path!) {
                NSFileManager.defaultManager().createDirectoryAtURL(appUrl, withIntermediateDirectories: true, attributes: nil, error: nil)
            }
            
            return appUrl
            
        #endif
    }
    
    private func workingBundle() -> Bundle {
        if let bundle = Bundle(identifier: self.configuration.bundleID) {
            return bundle
        }
        
        return Bundle.main()
    }
    
    private func applicationName() -> String {
        if let appName = self.workingBundle().objectForInfoDictionaryKey(kAppBundleNameKey) as? String {
            return appName
        }
        
        return Bundle(for: object_getClass(self)).objectForInfoDictionaryKey(kAppBundleNameKey) as! String
    }
}

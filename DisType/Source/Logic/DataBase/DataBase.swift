/*-
 * Copyright © 2016  Alex Makushkin
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
//
//  DataBase.swift
//  DisType
//
//  Created by Mike Kholomeev on 11/20/17.
//

import Foundation
import RealmSwift

let DB = DataBase()

class DataBase {
    fileprivate static let noCategoryCategoryName = "Без категории"
    
    fileprivate let minChatCount = 3
    fileprivate let chatName = "ЧАТ"

    fileprivate let noCategoryCategory:Category

    fileprivate var realm :Realm { return try! Realm() }

    var settings: Settings {
        guard let settings = realm.objects(Settings.self).first
            else {
                initSettings()
                return self.settings
        }
        return settings
    }
    
    var chats: Results<Chat> {
        return realm.objects(Chat.self).sorted(byKeyPath: #keyPath(Chat.name))
    }
    
    var categories = List<Category>()
    
    // MARK: - INIT
    init() {
        if let version = try? schemaVersionAtURL(Realm.Configuration.defaultConfiguration.fileURL!) {
            let config = Realm.Configuration(schemaVersion: version + 1)
            Realm.Configuration.defaultConfiguration = config
        }
        
        let realm = try! Realm()
        let categories = realm.objects(Category.self)
        
        if !categories.isEmpty,
            let category = categories.first(where:{ $0.id == DataBase.noCategoryCategoryName}) {
            noCategoryCategory = category
        } else {
            noCategoryCategory = Category()
            noCategoryCategory.name = DataBase.noCategoryCategoryName
            noCategoryCategory.id = DataBase.noCategoryCategoryName
            self.add(noCategoryCategory)
        }

        updateCategoriesList()
        initChats()
        initSettings()
    }
    
    fileprivate func updateCategoriesList() {
        let firstIndex = 0
        let categories = List<Category>()
        let objs = realm.objects(Category.self)
        objs.forEach {categories.append($0)}
        
        if !categories.isEmpty,
            let index = categories.index(of: noCategoryCategory),
            index != firstIndex {
            categories.move(from: index, to:firstIndex)
        }
        
        self.categories = categories
    }
    
    fileprivate func initChats() {
        let chatsCount = self.chats.count
        if chatsCount < minChatCount {
            var count = chatsCount + 1
            while count <= minChatCount {
                let chat = Chat()
                chat.name = "\(chatName)\(count)"
                self.add(chat)
                count += 1
            }
        }
    }
    
    fileprivate func initSettings() {
        guard realm.objects(Settings.self).first == nil else { return }
        let settings = Settings()
        realm.beginWrite()
        realm.add(settings)
        try! realm.commitWrite()
    }

    // MARK: - Public
    // MARK: - Add
    func addNewChat() {
        let chat = Chat()
        chat.name = "\(chatName)\(DB.chats.count+1)"
        DB.add(chat)
    }
    
    func add(_ chat:Chat) {
        realm.beginWrite()
        realm.add(chat)
        try! realm.commitWrite()
    }

    func add(_ category:Category) {
        realm.beginWrite()
        realm.add(category)
        try! realm.commitWrite()
        updateCategoriesList()
    }
    
    func add(_ message:Message, to category:Category) {
        realm.beginWrite()
        category.messages.append(message)
        try! realm.commitWrite()
    }
    
    // MARK: - Update
    func update(_ chat:Chat, text:String) {
        realm.beginWrite()
        chat.text = text
        try! realm.commitWrite()
    }
    func update(_ category:Category, name:String) {
        realm.beginWrite()
        category.name = name
        try! realm.commitWrite()
        updateCategoriesList()
    }
    func update(_ message:Message, text:String) {
        realm.beginWrite()
        message.text = text
        try! realm.commitWrite()
    }

    func update(useInternet:Bool) {
        realm.beginWrite()
        settings.isUseInternet = useInternet
        try! realm.commitWrite()
    }
    
    func update(speakEveryWord:Bool) {
        realm.beginWrite()
        settings.isSpeakEveryWord = speakEveryWord
        try! realm.commitWrite()
    }
    func update(voiceId:String) {
        realm.beginWrite()
        settings.voiceId = voiceId
        try! realm.commitWrite()
    }
    // MARK: - Delete
    func delete(_ chat:Chat) {
        guard let index = DB.chats.index(of: chat), index > 2 else { return }
        realm.beginWrite()
        realm.delete(chat)
        try! realm.commitWrite()
    }

    func delete(_ category:Category) {
        realm.beginWrite()
        realm.delete(category)
        try! realm.commitWrite()
        updateCategoriesList()
    }

    func delete(_ message:Message) {
        realm.beginWrite()
        realm.delete(message)
        try! realm.commitWrite()
    }
}

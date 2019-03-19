//
//  ReadingPlanDBService.swift
//  HolyBible
//
//  Created by Margarita Zherikhova on 09.02.17.
//  Copyright © 2017 Globus ltd. All rights reserved.
//

import Foundation

class ReadingPlanDBService: BaseDBService {
    func createUpdate(plan: ReadingPlanParameters) {
        createUpdate(plans: [plan])
    }
    
    func createUpdate(plans: [ReadingPlanParameters]) {
        safeWriteWithErrorHandling(db) {
            guard let db = db else { return }
            for plan in plans {
                let p = ReadingPlan()
                p.id = plan.id
                p.categoryId = plan.categoryId
                p.name = plan.name
                p.summary = plan.summary
                p.days = plan.days
                p.createdDate = plan.createdDate
                p.image = plan.image
                
//                if p.image != plan.image {
//                    p.image = plan.image
//                    p.imageData = nil
//                } else if let sPlan = plan as? ReadingPlanDBParameters {
//                    p.imageData = sPlan.imageData
//                }

                //p.localId = p.incrementID(db)
                for literature in plan.listOfDayLiterature() {
                    let literatureObject = DayLiterature()
                    p.daysLiterature.append(literatureObject)
                    for literatureItem in literature.listOfLiteratureItems() {
                        let literatureItemObject = LiteratureItem()
                        literatureItemObject.id = literatureItem.id
                        literatureItemObject.dayId = literatureItem.dayId
                        literatureItemObject.bookId = literatureItem.bookId
                        literatureItemObject.translationId = literatureItem.translationId
                        literatureItemObject.fromChapter = literatureItem.fromChapter
                        literatureItemObject.toChapter = literatureItem.toChapter
                        literatureItemObject.fromVerse = literatureItem.fromVerse
                        literatureItemObject.toVerse = literatureItem.toVerse
                        literatureObject.literatureItems.append(literatureItemObject)
                    }
                }
                db.create(ReadingPlan.self, value: p, update: true)
                
                ServicesDBManager.shared.readingPlans.imageDataForReadingPlan(id: p.id, completion: nil)
            }
        }
    }
    
    //MARK: -
    
    func imageDataForReadingPlan(id: Int, completion: ((_ model: ReadingPlanDBParameters) -> Void)?) {
        guard var readingPlan = self.plan(id: id) else { return }
        guard let sImage = readingPlan.image else { return }
        DispatchQueue.global(qos: .default).async {
            do {
                guard let string = sImage
                    .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)?
                    .replacingOccurrences(of: "%3A", with: ":")
                    .replacingOccurrences(of: "%2F", with: "/") else {
                        return
                }
                let data = try Data.init(contentsOf: URL.init(string: string)!)
                DispatchQueue.main.async {
                    
                    if var readingPlan = self.plan(id: id) {
                        self.safeWriteWithErrorHandling(self.db) {
                            readingPlan.imageData = data
                        }
                        completion?(readingPlan)
                    }
                }
            } catch {}
        }
    }
    
    //
    
    func delete(plan: ReadingPlanParameters) {
        safeWriteWithErrorHandling(db) {
            if let deletePlan = self.plan(id: plan.id) as? ReadingPlan {
                db?.delete(deletePlan)
            }
        }
    }
    
    func plans(_ closure: ((_ plans: [ReadingPlanParameters]) -> Void)?) {
        guard let realm = db else {
            closure?([ReadingPlanParameters]())
            return
        }
        //TODO
        //let results = realm.objects(ReadingPlanUser.self).filter("userId = \(userId)")
        //let array = (results.flatMap { $0 as ReadingPlanUser }) as [ReadingPlanUser]
        closure?(realm.objects(ReadingPlan.self).flatMap { $0 as ReadingPlan } as [ReadingPlan])
    }

    func plan(id: Int) -> ReadingPlanDBParameters? {
        return db?.object(ofType: ReadingPlan.self, forPrimaryKey: id)
    }
    
//    func plans(_ userId: Int,
//               _ bookId: Int,
//               _ chapter: Int,
//               _ verse: Int) -> [ReadingPlanParameters] {
//        //TODO: hz
//        return [ReadingPlanParameters]()
//    }
    
    func plans(categoryId: Int, _ closure: ((_ plans: [ReadingPlanDBParameters]) -> Void)?) {
        guard let realm = db else {
            closure?([ReadingPlanDBParameters]())
            return
        }
        let results = realm.objects(ReadingPlan.self).filter("categoryId = \(categoryId)")
        let array = (results.flatMap { $0 as ReadingPlan }) as [ReadingPlan]
        closure?(array)
    }

    func resetReadingPlans() {
        safeWriteWithErrorHandling(db) {
            if let results = db?.objects(ReadingPlan.self) {
                db?.delete(results)
            }
        }
    }
    
    //MARK: - Progress
    
    func planProgress(planId: Int) -> ReaderPlanProgress? {
        guard let realm = db else { return nil }
        let userId = UserManager.shared.currentUser?.id 
        let predicate = "readerPlanId = \(planId) AND userId = \(userId!)"
        let results = realm.objects(ReaderPlanProgress.self).filter(predicate)
        let planProgress = results.first
        return planProgress
    }
    
    func finishReadingStep(_ planId: Int) {
        safeWriteWithErrorHandling(db) {
            guard db != nil, let plan = plan(id: planId) else { return }
            guard let planProgress = self.planProgress(planId: planId) else { return }
            planProgress.progressDay = min(planProgress.progressDay + 1, plan.days)
        }
    }
    
    func finishReadingStep(_ planId: Int, _ progressDay: Int) {
        safeWriteWithErrorHandling(db) {
            guard db != nil, let plan = plan(id: planId) else { return }
            guard let planProgress = self.planProgress(planId: planId) else { return }
            if planProgress.progressDay <= progressDay {
                planProgress.progressDay = min(progressDay + 1, plan.days)
            }
        }
    }
    
    func currentStep(_ planId: Int) -> Int? {
        guard db != nil else { return nil }
        guard let planProgress = self.planProgress(planId: planId) else { return nil }
        return planProgress.progressDay
    }
    
    func addMyReaderPlan(_ planId: Int) {
        safeWriteWithErrorHandling(db) {
            guard db != nil else { return }
            guard self.planProgress(planId: planId) == nil, self.plan(id: planId) != nil else { return }
            let userId = UserManager.shared.currentUser?.id
            let planProgress = ReaderPlanProgress.init(userId: userId!, readerPlanId: planId)
            db?.create(ReaderPlanProgress.self, value: planProgress)
        }
        if let plan = ServicesDBManager.shared.readingPlans.plan(id: planId) {
            ServicesDBManager.shared.userReadingPlans.createUpdate(plan: plan)
        }
    }
    
    func removeMyReaderPlan(_ planId: Int) {
        safeWriteWithErrorHandling(db) {
            guard db != nil else { return }
            guard let planProgress = self.planProgress(planId: planId) else { return }
            db?.delete(planProgress)
        }
        if let plan = ServicesDBManager.shared.readingPlans.plan(id: planId) {
            ServicesDBManager.shared.userReadingPlans.delete(plan: plan)
        }
    }
    
    func myReaderPlans() -> [ReadingPlanDBParameters] {
        guard let realm = db else {
            return []
        }
        let userId = UserManager.shared.currentUser?.id
        let results = realm.objects(ReaderPlanProgress.self).filter("userId = \(userId!)")
        let readerPlansProgress = (results.flatMap { $0 as ReaderPlanProgress }) as [ReaderPlanProgress]
        var plans: [ReadingPlanDBParameters] = []
        for readerPlanProgress in readerPlansProgress {
            //if let readerPlan = self.plan(id: readerPlanProgress.readerPlanId) {
            if let readerPlan = ServicesDBManager.shared.userReadingPlans.plan(id: readerPlanProgress.readerPlanId) {
                plans.append(readerPlan)
            }
        }
        return plans
    }
    
    // MARK:
    
    func createUpdate(category: ReadingPlanCategoryParameters) {
        createUpdate(categories: [category])
    }
    
    func createUpdate(categories: [ReadingPlanCategoryParameters]) {
        safeWriteWithErrorHandling(db) {
            guard let db = db else { return }
            for category in categories {
                let c = ReadingPlanCategory()
                c.id = category.id
                c.name = category.name
                db.create(ReadingPlanCategory.self, value: c, update: true)
            }
        }
    }
    
    func delete(category: ReadingPlanCategoryParameters) {
        safeWriteWithErrorHandling(db) {
            if let deleteCategory = self.category(id: category.id) as? ReadingPlanCategory {
                db?.delete(deleteCategory)
            }
        }
    }
    
    func category(id: Int) -> ReadingPlanCategoryParameters? {
        return db?.object(ofType: ReadingPlanCategory.self, forPrimaryKey: id)
    }
    
    func categories(_ closure: ((_ categories: [ReadingPlanCategoryParameters]) -> Void)?) {
        guard let realm = db else {
            closure?([ReadingPlanCategoryParameters]())
            return
        }
        closure?(realm.objects(ReadingPlanCategory.self).flatMap { $0 as ReadingPlanCategory } as [ReadingPlanCategory])
    }
    
    func resetReadingPlansCategories() {
        safeWriteWithErrorHandling(db) {
            if let results = db?.objects(ReadingPlanCategory.self) {
                db?.delete(results)
            }
        }
    }
}

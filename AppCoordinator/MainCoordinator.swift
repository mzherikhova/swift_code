//
//  MainCoordinator.swift
//  HolyBible
//
//  Created by Margarita Zherikhova on 16.02.17.
//  Copyright © 2017 Globus ltd. All rights reserved.
//

import UIKit

class MainCoordinator: AppCoordinator {
    // MARK: Internal properties
    var sideMenu: SideMenuController {
        return rootViewController as! SideMenuController
    }
    var reader: BookReaderController!
    
    override func start() {
        super.start()
        sideMenu.sideMenuDelegate = self
        ThemeManager.shared.configureThemeOnLaunch()
        if UserManager.shared.isAuthenticated {
            showBookReader()
        } else {
            showAuthWelcome()
        }
    }
    
    // MARK: Fileprivate functions
    /*
    fileprivate func showBibleReader() {
        if reader == nil {
            reader = BibleReaderController()
            reader.delegate = self
        }
        sideMenu.changeContent(UINavigationController(rootViewController: reader))
    } */
    func showBookReader() {
        
        UserManager.shared.reloadReadingPlansWithClean(nil)
        UserManager.shared.reloadReadingPlansCategoriesWithClean(nil)
        
        if let navController = sideMenu.contentViewController as? ExtendedNavigationController,
            navController.viewControllers[0] is BookReaderController {
            sideMenu.changeContent(ExtendedNavigationController(rootViewController: reader))
            return
        }
        
        if reader == nil {
            reader = BookReaderController.instantiate(from: .from(.bookReader))
            reader.delegate = self
        }
        sideMenu.setupTheme()
        sideMenu.changeContent(ExtendedNavigationController(rootViewController: reader))
    }
    
    func showBookReader(translationId: Int, bookId: Int, chapter: Int, verse: Int) {
        
        ReadingManager.shared.currentBookId = bookId
        ReadingManager.shared.currentChapter = chapter
        ReadingManager.shared.currentVerse = verse
        
        UserManager.shared.reloadReadingPlansWithClean(nil)
        UserManager.shared.reloadReadingPlansCategoriesWithClean(nil)
        
        if let navController = sideMenu.contentViewController as? ExtendedNavigationController,
            navController.viewControllers[0] is BookReaderController {
            reader.present(bookId, chapter, verse)
            sideMenu.changeContent(ExtendedNavigationController(rootViewController: reader))
            return
        }

        if reader == nil {
            reader = BookReaderController.instantiate(from: .from(.bookReader))
            reader.delegate = self
            reader.present(bookId, chapter, verse)
            
        }
        
        sideMenu.setupTheme()
        sideMenu.changeContent(ExtendedNavigationController(rootViewController: reader))
    }
    
    // MARK: Side menu
    func showLenta() {
        let storyboard = UIStoryboard.from(.lenta)
        let controller = LentaViewController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    func showChurches() {
        let storyboard = UIStoryboard.from(.churches)
        let controller = ChurchesContainterController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    fileprivate func showBookReaderWithBackButton() {
        
        UserManager.shared.reloadReadingPlansWithClean(nil)
        UserManager.shared.reloadReadingPlansCategoriesWithClean(nil)
        
        if let navController = sideMenu.contentViewController as? ExtendedNavigationController,
            navController.viewControllers[0] is BookReaderController {
            sideMenu.changeContent(ExtendedNavigationController(rootViewController: reader))
            return
        }
        
        if reader == nil {
            reader = BookReaderController.instantiate(from: .from(.bookReader))
            reader.delegate = self
        }
        sideMenu.setupTheme()
        
        if let navController = sideMenu.contentViewController as? UINavigationController {
            navController.pushViewController(reader, animated: true)
            reader.createBackNavButton()
        }
    }
    
    func showMyReaderPlans() {
        let storyboard = UIStoryboard.from(.readerPlans)
        let controller = ReaderPlansMainViewController.instantiate(from: storyboard)
        controller.delegate = self
        controller.needShowMyReaderPlan = true
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }

    fileprivate func showReaderPlans() {
        let storyboard = UIStoryboard.from(.readerPlans)
        let controller = ReaderPlansMainViewController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }

    // MARK: Auth
    func showAuthWelcome() {
        let welcome = AuthWelcomeController.createFromNib()
        welcome.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: welcome))
        sideMenu.statusBarStyle = .black
    }
    
    fileprivate func showAuthSignIn() {
        let signIn = SignInController.createFromNib()
        signIn.delegate = self
        let navController = sideMenu.contentViewController as? UINavigationController
        navController?.pushViewController(signIn, animated: true)
    }
    
    fileprivate func showRegistration() {
        let reg = RegistrationController.createFromNib()
        reg.delegate = self
        let navController = sideMenu.contentViewController as? UINavigationController
        navController?.pushViewController(reg, animated: true)
    }
    
    fileprivate func showRestore() {
        let restore = RestoreController.createFromNib()
        restore.delegate = self
        let navController = sideMenu.contentViewController as? UINavigationController
        navController?.pushViewController(restore, animated: true)
    }
    
    // MARK: Side menu
    fileprivate func showBookmarksList() {
        let storyboard = UIStoryboard.from(.bookmarks)
        let controller = BookmarksListController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    fileprivate func showPartnershipList() {
        let storyboard = UIStoryboard.from(.partnership)
        let controller = PartnershipListViewController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    fileprivate func showBibleGift() {
        let storyboard = UIStoryboard.from(.bibleGift)
        let controller = BibleGiftViewController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }

    fileprivate func showHistoriesList() {
        let storyboard = UIStoryboard.from(.histories)
        let controller = HistoriesListController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    func showHistoriesListWithBackButton() {
        let storyboard = UIStoryboard.from(.histories)
        let controller = HistoriesListController.instantiate(from: storyboard)
        controller.delegate = self
        
        let navController = sideMenu.contentViewController as? UINavigationController
        navController?.pushViewController(controller, animated: true)
    }
    
    fileprivate func showNotesList() {
        let storyboard = UIStoryboard.from(.notes)
        let controller = NotesListController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    fileprivate func showPromises() {
        let storyboard = UIStoryboard.from(.promises)
        let controller = PromisesViewController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(ExtendedNavigationController(rootViewController: controller))
    }
    
    fileprivate func showConfessions() {
        let storyboard = UIStoryboard.from(.confessions)
        let controller = ConfessionCategoriesController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(ExtendedNavigationController(rootViewController: controller))
    }

    fileprivate func showPhotoVersesList() {
        guard UserManager.shared.currentUser?.id != nil else {
            ErrorHandler.handle(HolyBible.APIError.unauthorized)
            return
        }
        let storyboard = UIStoryboard.from(.photoVerses)
        let controller = PhotoVersesListViewController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }

    fileprivate func showMarkersList() {
        let storyboard = UIStoryboard.from(.markers)
        let controller = MarkersListController.instantiate(from: storyboard)
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
    
    fileprivate func showUserProfile() {
        let controller = UserProfileController.instantiate(from: UIStoryboard.from(.user))
        controller.delegate = self
        sideMenu.present(UINavigationController(rootViewController: controller), animated: true, completion: nil)
    }
    
    fileprivate func showAboutApp() {
        let controller = AboutAppViewController.instantiate(from: UIStoryboard.from(.aboutApp))
        controller.delegate = self
        sideMenu.changeContent(UINavigationController(rootViewController: controller))
    }
}

extension MainCoordinator: SideMenuDelegate {
    func sideMenu(item: LeftSideMenuItem) {
        guard !needAuthorization(forMenuItem: item) else {
            AlertHelper.showAlert(title: "", message: "alertUnauthorized".localized())
            return
        }
        
        switch item {
        case .readerPlans:
            showReaderPlans()
            sideMenu.hideMenu()
        case .read:
            showBookReader()
            sideMenu.hideMenu()
        case .lenta:
            showLenta()
            sideMenu.hideMenu()
        case .churches:
            showChurches()
            sideMenu.hideMenu()
        case .bookmarks:
            showBookmarksList()
            sideMenu.hideMenu()
        case .readingHistory:
            showHistoriesList()
            sideMenu.hideMenu()
        case .notes:
            showNotesList()
            sideMenu.hideMenu()
        case .promises:
            showPromises()
            sideMenu.hideMenu()
        case .confessions:
            showConfessions()
            sideMenu.hideMenu()
        case .photoVerses:
            showPhotoVersesList()
            sideMenu.hideMenu()
        case .markers:
            showMarkersList()
            sideMenu.hideMenu()
        case .auth:
            showAuthWelcome()
            sideMenu.hideMenu()
        case .profile:
            showUserProfile()
            sideMenu.hideMenu(false)
        case .partnership:
            showPartnershipList()
            sideMenu.hideMenu()
        case .bibleGift:
            showBibleGift()
            sideMenu.hideMenu()
        case .aboutApp:
            showAboutApp()
            sideMenu.hideMenu()
        default:
            break
        }
        print("\(item)")
    }
    
    fileprivate func needAuthorization(forMenuItem item: LeftSideMenuItem) -> Bool {
        switch item {
        case .auth, .read, .aboutApp, .churches:
            return false
        default:
            return !UserManager.shared.isAuthenticated
        }
    }
}

extension MainCoordinator: ScreenOfMenuDelegate {
    func screenOfMenuNeedToShowLeftMenu() {
        sideMenu._presentLeftMenuViewController()
    }
}

extension MainCoordinator: AuthDelegate {
    func authDidFinish() {
        showBookReader()
    }
    
    func authNeedShowSignIn() {
        showAuthSignIn()
    }
    
    func authNeedShowRegistration() {
        showRegistration()
    }
    
    func authNeedShowRestore() {
        showRestore()
    }
    
    func authRestoreDidFinish() {
        let navController = sideMenu.contentViewController as? UINavigationController
        _ = navController?.popViewController(animated: true)
    }
    
    func authNeedShowWithoutRegistration() {
        showBookReader()
    }
    
}

// MARK: Screens of menu
/*
extension MainCoordinator: BibleReaderDelegate {
    func bibleReaderNeedCreateNote(_ bookId: Int,
                                   _ chapterNumber: Int,
                                   _ translationId: Int,
                                   _ verseStart: Int,
                                   _ verseEnd: Int,
                                   _ locationStart: Int,
                                   _ locationEnd: Int) {
        let editNote = NoteEditorController.instantiate(from: UIStoryboard.from(.notes))
        editNote.delegate = self
        editNote.setContent(bookId,
                            chapterNumber,
                            translationId,
                            verseStart,
                            verseEnd,
                            locationStart,
                            locationEnd)
        sideMenu.present(UINavigationController(rootViewController: editNote), animated: true, completion: nil)
    }
    
    func bibleReader(_ reader: BibleReaderController, editNote: NoteParameters) {
        let controller = NoteEditorController.instantiate(from: UIStoryboard.from(.notes))
        controller.delegate = self
        controller.edit(editNote)
        sideMenu.present(UINavigationController(rootViewController: controller), animated: true, completion: nil)
    }

    func bibleReaderShowSearchVerse() {
        let controller = SearchVerseController.instantiate(from: UIStoryboard.from(.search))
        controller.delegate = self
        sideMenu.present(controller, animated: true, completion: nil)
    }
    
    func bibleReaderShowTableOfContents() {
        let controller = ChooseBookController.instantiate(from: UIStoryboard.from(.tableOfContents))
        let testaments = BibleContentHelper.bibles(translationId: TranslationSourcesManager.shared.translation(at: 0)!.id)
        controller.testaments = testaments
        controller.delegate = self
        sideMenu.present(UINavigationController(rootViewController: controller), animated: true, completion: nil)
    }
}
 */

extension MainCoordinator: BookReaderDelegate {
    func bookReaderNeedCreateNote(_ bookId: Int,
                                  _ chapterNumber: Int,
                                  _ translationId: Int,
                                  _ verseStart: Int,
                                  _ verseEnd: Int,
                                  _ locationStart: Int,
                                  _ locationEnd: Int) {
        let editNote = NoteEditorController.instantiate(from: UIStoryboard.from(.notes))
        editNote.delegate = self
        editNote.setContent(bookId,
                            chapterNumber,
                            translationId,
                            verseStart,
                            verseEnd,
                            locationStart,
                            locationEnd)
        sideMenu.present(UINavigationController(rootViewController: editNote), animated: true, completion: nil)
    }
    
    func bookReader(_ reader: BookReaderController, edit note: NoteParameters) {
        let controller = NoteEditorController.instantiate(from: UIStoryboard.from(.notes))
        controller.delegate = self
        controller.edit(note)
        sideMenu.present(ExtendedNavigationController(rootViewController: controller), animated: true, completion: nil)
    }
    
    func bookReaderShowSearchVerse(translation: TranslationParameters?) {
        let controller = SearchVerseController.instantiate(from: UIStoryboard.from(.search))
        controller.delegate = self
        controller.initialTranslation = translation
        sideMenu.present(controller, animated: true, completion: nil)
    }
}

extension MainCoordinator: BookmarksListDelegate {
    func bookmarksList(show book: BookProtocol, translationId: Int, chapterNumber: Int, verseNumber: Int) {
        showBookReader()
        reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, verseNumber)
    }
}

extension MainCoordinator: LentaDelegate {
    func presentVerseOfTheDayController(rootVC: UIViewController) {
        let controller = VerseOfTheDayViewController.instantiate(from: UIStoryboard.from(.lenta))
        controller.delegate = self
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
    func presentLentaController() {
        showLenta()
    }
}

extension MainCoordinator: ChurchesContainterDelegate {
    func presentChurchController(_ rootVC: UIViewController, _ church: ChurchShortParameters) {
        let controller = ChurchViewController.instantiate(from: UIStoryboard.from(.churches))
        controller.configure(church: church)
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
    func presentChurchFilterController(_ rootVC: UIViewController) {
        let controller = ChurchFilterViewController.instantiate(from: UIStoryboard.from(.churches))
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
    func presentChurchSearchController(_ rootVC: UIViewController) {
        if let _ = rootVC as? ChurchContainterSearchDelegate {
            let controller = ChurchContainterSearchController.instantiate(from: UIStoryboard.from(.churches))
            controller.delegate = rootVC as? ChurchContainterSearchDelegate
            rootVC.navigationController?.pushViewController(controller, animated: false)
        }
    }
}

extension MainCoordinator: HistoriesListDelegate {
    func historiesList(show book: BookProtocol, translationId: Int, chapterNumber: Int, verseNumber: Int) {
        showBookReader()
        reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, verseNumber)
    }
}

extension MainCoordinator: NotesListDelegate {
    func notesListNeedCreateNewNote(_ notesList: NotesListController) {
        let controller = NoteEditorController.instantiate(from: UIStoryboard.from(.notes))
        controller.delegate = self
        notesList.navigationController?.pushViewController(controller, animated: true)
    }
    
    func notesList(_ notesList: NotesListController, editNote: NoteParameters) {
        let controller = NoteEditorController.instantiate(from: UIStoryboard.from(.notes))
        controller.delegate = self
        controller.edit(editNote)
        notesList.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: MarkersListDelegate {
    func markersListNeedShow(_ markersList: MarkersListController,
                             _ translationId: Int,
                             _ book: BookProtocol,
                             _ chapterNumber: Int,
                             _ startVerseNumber: Int) {
        showBookReader()
        reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, startVerseNumber)
    }
    
    func markersListShowGroupOfColor(_ markersList: MarkersListController,
                                     _ colorTitle: String?,
                                     _ markers: [MarkerParameters]) {
        let controller = MarkersOfColorGroupController.instantiate(from: UIStoryboard.from(.markers))
        controller.delegate = self
        controller.load(colorTitle, markers)
        markersList.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: MarkersOfColorGroupDelegate {
    func markersOfColorGroupNeedShow(_ markersList: MarkersOfColorGroupController,
                                     _ translationId: Int,
                                     _ book: BookProtocol,
                                     _ chapterNumber: Int,
                                     _ startVerseNumber: Int) {
        showBookReader()
        reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, startVerseNumber)
    }
}

extension MainCoordinator: PromisesListControllerDelegate {
    func presentThemesController(rootVC: UIViewController, promiseCategory: PromiseCategoryParameters) {
        let controller = PromiseCategoryController.instantiate(from: UIStoryboard.from(.promises))
        controller.delegate = self
        controller.promiseCategory = promiseCategory
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: ConfessionCategoriesControllerDelegate {
    func presentConfessionController(rootVC: UIViewController, _ confession: ConfessionDBParameters) {
        let controller = ConfessionViewController.instantiate(from: UIStoryboard.from(.confessions))
        controller.confession = confession
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: PromiseCategoryControllerDelegate {
    func presentThemeController(rootVC: UIViewController, promiseTheme: PromiseThemeParameters) {
        let controller = PromiseThemeController.instantiate(from: UIStoryboard.from(.promises))
        controller.delegate = self
        controller.promiseTheme = promiseTheme
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}
extension MainCoordinator:  PromisesControllerDelegate {

    func presentListController(rootVC: UIViewController, _ promiseCategories: [PromiseCategoryDBParameters]) {
        let controller = PromisesListController.instantiate(from: UIStoryboard.from(.promises))
        controller.delegate = self
        controller.promiseCategories = promiseCategories
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: PromiseThemeControllerDelegate {
    func promiseThemeNeedShow(_ rootVC: UIViewController, _ translationId: Int, _ book: BookProtocol, _ chapterNumber: Int, _ startVerseNumber: Int) {
        showBookReaderWithBackButton()
        reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, startVerseNumber)
//        if let navController = rootVC.navigationController, navController.viewControllers.count > 1 {
//            _ = rootVC.navigationController?.popViewController(animated: true)
//        } else {
//            rootVC.dismiss(animated: true, completion: nil)
//        }
//        self.showBookReader()
//        self.reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, startVerseNumber)
    }
}


extension MainCoordinator: NoteEditorDelegate {
    func noteEditorNoteWasCanceled(_ editor: NoteEditorController) {
        if let navController = editor.navigationController, navController.viewControllers.count > 1 {
            _ = editor.navigationController?.popViewController(animated: true)
        } else {
            editor.dismiss(animated: true, completion: nil)
        }
    }

    func noteEditorNoteDidChange(_ editor: NoteEditorController) {
        if let navController = editor.navigationController, navController.viewControllers.count > 1 {
            _ = editor.navigationController?.popViewController(animated: true)
        } else {
            editor.dismiss(animated: true, completion: nil)
        }
    }

    func noteEditorNeedShow(_ editor: NoteEditorController,
                            _ translationId: Int,
                            _ book: BookProtocol,
                            _ chapterNumber: Int,
                            _ startVerseNumber: Int) {
        if let navController = editor.navigationController, navController.viewControllers.count > 1 {
            _ = editor.navigationController?.popViewController(animated: true)
        } else {
            editor.dismiss(animated: true, completion: nil)
        }
        showBookReader()
        reader.present(changeGeneralTranslation: translationId, book.getNumber(), chapterNumber, startVerseNumber)
    }
}

extension MainCoordinator: UserProfileDelegate {
    func userProfileLogoutDidFinish() {
        SettingsManager.clearAllSettings()
        showAuthWelcome()
        sideMenu.dismiss(animated: true, completion: nil)
    }
}

extension MainCoordinator: SearchVerseDelegate {
    func searchVersePicked(searchVerse: SearchVerseController, translationId: Int, bookId: Int, verse: VerseProtocol) {
        reader.showLoader(true)
        searchVerse.dismiss(animated: true) { [weak self] in
            self?.reader.present(changeGeneralTranslation: translationId, bookId, verse.getChapterNumber(), verse.getNumber())
        }
    }

    func searchVerseCancel(searchVerse: SearchVerseController) {
        searchVerse.dismiss(animated: true, completion: nil)
    }

    func searchVersePicked(searchVerse: SearchVerseController, translationId: Int, book: BookProtocol, verse: VerseProtocol) {
        reader.showLoader(true)
        searchVerse.dismiss(animated: true) { [weak self] in
            self?.reader.present(changeGeneralTranslation: translationId, book.getNumber(), verse.getChapterNumber(), verse.getNumber())
        }
    }
}

extension MainCoordinator: PhotoVersesListDelegate {

}

extension MainCoordinator: ReaderPlansReaderControllerDelegate {
    func popToReadMorePlanController(rootVC: UIViewController, _ readerPlan: ReadingPlanDBParameters) {
        
        let controller = ReaderPlansMorePlanController.instantiate(from: UIStoryboard.from(.readerPlans))
        controller.delegate = self
        controller.readerPlan = readerPlan
        
        rootVC.navigationController!.viewControllers = [rootVC.navigationController!.viewControllers.first!, controller, rootVC.navigationController!.viewControllers.last!]
        rootVC.navigationController?.popViewController(animated: true)
    }
}


extension MainCoordinator: ReaderPlansMainDelegate {
    func presentAboutPlanController(rootVC: UIViewController, _ readerPlan: ReadingPlanDBParameters, _ needJumpBack: Bool) {
        let controller = ReaderPlansAboutController.instantiate(from: UIStoryboard.from(.readerPlans))
        controller.delegate = self
        controller.readerPlan = readerPlan
        controller.isJumpBackNeeded = needJumpBack
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
    
    func presentReadMorePlanController(rootVC: UIViewController, _ readerPlan: ReadingPlanDBParameters) {
        let controller = ReaderPlansMorePlanController.instantiate(from: UIStoryboard.from(.readerPlans))
        controller.delegate = self
        controller.readerPlan = readerPlan
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
    
    func presentCategoryReaderPlansController(rootVC: UIViewController, _ readerPlanCategory: ReadingPlanCategoryParameters) {
        let controller = CategoryReaderPlansViewController.instantiate(from: UIStoryboard.from(.readerPlans))
        controller.completion = nil
        controller.delegate = self
        controller.category = readerPlanCategory
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
    
    func presentReaderController(rootVC: UIViewController, _ readerPlan: ReadingPlanDBParameters, _ day: Int) {
        let controller = ReaderPlansReaderController.instantiate(from: UIStoryboard.from(.readerPlans))
        controller.completion = nil
        controller.delegate = self
        controller.readerPlan = readerPlan
        controller.currentDay = day
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: AboutAppDelegate {
    
}

extension MainCoordinator: VerseOfTheDayDelegate {

    func verseOfTheDayNeedShow(_ verseOfTheDayController: VerseOfTheDayViewController,
                               _ translationId: Int,
                               _ bookNumber: Int,
                               _ chapterNumber: Int,
                               _ startVerseNumber: Int) {

        self.showBookReader()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.reader.present(changeGeneralTranslation: translationId, bookNumber, chapterNumber, startVerseNumber)
        }
    }
    
    func createPhotoVerse(_ verseOfTheDayController: VerseOfTheDayViewController,
                          _ selectedData: BookReaderSelectedData,
                          _ verseOfTheDay: VerseOfTheDay) {
        
        guard
            let translation = ServicesDBManager.shared.translations.translation(id: selectedData.translationId)
            else { return }
        let vers = (verseStart: verseOfTheDay.verseStart,
                    verseEnd: verseOfTheDay.verseEnd,
                    locationStart: 0,
                    locationEnd: 0)
        
        let controller = PhotoVersesEditViewController.instantiate(from: UIStoryboard.from(.photoVerses))
        //controller.delegate = self
        
        controller.isTextWithoutRange = true
        controller.currentTranslation = translation
        controller.selecteValues = vers
        controller.selectedData = selectedData
        
        verseOfTheDayController.navigationController?.pushViewController(controller, animated: true)
    }
    
    func presentVerseOfTheDayController(_ rootVC: UIViewController,
                                        _ verseOfTheDay: VerseOfTheDay) {
        let controller = VerseOfTheDayViewController.instantiate(from: UIStoryboard.from(.lenta))
        controller.delegate = self
        controller.currentVerseOfTheDay = verseOfTheDay
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: PartnershipListDelegate {
    func presentPartnershipController(rootVC: UIViewController, partnershipType: PartnershipType) {
        let controller = PartnershipViewController.instantiate(from: UIStoryboard.from(.partnership))
        //controller.delegate = self
        controller.configure(partnershipType: partnershipType)
        rootVC.navigationController?.pushViewController(controller, animated: true)
    }
}

extension MainCoordinator: BibleGiftDelegate {
    func showPartnershipFromBibleGift() {
        showPartnershipList()
    }
}

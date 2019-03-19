//
//  TranslationsListController.swift
//  HolyBible
//
//  Created by Margarita Zherikhova on 07.04.17.
//  Copyright © 2017 Globus ltd. All rights reserved.
//

import UIKit

fileprivate enum TranslationsListSourceType: Int {
    case local
    case avaible
}

class TranslationsListController: UIViewController {
    // MARK: Internal prop
    var currentTranslation: TranslationParameters?
    var completion: ((_ controller: TranslationsListController, _ translation: TranslationParameters?) -> Void)?
    // MARK: Fileprivate prop
    @IBOutlet fileprivate weak var segmentControl: UISegmentedControl!
    @IBOutlet fileprivate weak var segmentControlView: UIView!
    @IBOutlet fileprivate weak var leftNavbarButton: UIButton!
    @IBOutlet fileprivate weak var tableView: UITableView!
    @IBOutlet fileprivate weak var segmentSeparatorView: UIView!
    fileprivate var localTranslations = [TranslationParameters]()
    fileprivate var avaibleTranslations = [TranslationParameters]()
    fileprivate let cap = TablePlaceholderView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        title = "translationsListTitle".localized()
        cap.title = "translationsInternetNotAvaibleCapTitle".localized()
        cap.message = "translationsInternetNotAvaibleCapMessage".localized()
        cap.imageName = ""
        loadData()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        let theme = ThemeManager.shared.currentConfig
        return theme.common.statusBarStyle
    }

    // MARK: Private func
    @IBAction private func segmentControlChanged(_ sender: UISegmentedControl) {
        tableView.reloadData()

        let source = TranslationsListSourceType(rawValue: sender.selectedSegmentIndex)!
        switch source {
        case .local:
            showCapIfNeeded()
        case .avaible:
            loadData()
        }
    }
    
    @IBAction private func leftNavbarButtonClicked(_ sender: UIButton) {
        completion?(self, currentTranslation)
    }
    
    // MARK: Filprivate func
    fileprivate func loadData() {
        ServicesDBManager.shared.translations.translations { [weak self] (translations) in
            if let tr = self?.rearrange(listOf: translations) {
                self?.localTranslations = tr
            } else {
                self?.localTranslations = translations
            }
        }

        TranslationAPIManager.shared.translations { [weak self] (result) in
            if case let .success(data) = result {
                if let tr = self?.rearrange(listOf: data) {
                    self?.avaibleTranslations = tr
                } else {
                    self?.avaibleTranslations = data
                }
            }
            else {
                self?.avaibleTranslations.removeAll()
            }
            self?.tableView?.reloadData()
            self?.showCapIfNeeded()
        }
    }
    
    fileprivate func isLoaded(_ translation: TranslationParameters) -> Bool {
        return localTranslations.filter({ $0.id == translation.id }).first != nil
    }
    
    fileprivate func currentSource() -> TranslationsListSourceType {
        return TranslationsListSourceType(rawValue: segmentControl.selectedSegmentIndex)!
    }
    
    func showCapIfNeeded() {
        switch currentSource() {
        case .avaible:
            tableView.backgroundView = avaibleTranslations.count == 0 ? cap : nil
        default:
            tableView.backgroundView = nil

        }
    }
}

extension TranslationsListController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        var translation: TranslationParameters!
        switch currentSource() {
        case .avaible:
            translation = avaibleTranslations[indexPath.row]
        case .local:
            translation = localTranslations[indexPath.row]
        }
        if isLoaded(translation) {
            currentTranslation = translation
        } else {
            if !TranslationSourcesManager.shared.isDownloading(translation: translation) {
                TranslationSourcesManager.shared.download(translation: translation, { [weak self] (_, success) in
                    if !success { return }
                    ServicesDBManager.shared.translations.translations { (translations) in
                        self?.localTranslations = translations
                        self?.tableView.reloadData()
                    }
                })
            }
        }
        tableView.reloadData()
    }
}

extension TranslationsListController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var translation: TranslationParameters!
        switch currentSource() {
        case .local:
            translation = localTranslations[indexPath.row]
        case .avaible:
            translation = avaibleTranslations[indexPath.row]
        }
        if isLoaded(translation) {
            let cell = tableView.dequeueReusableCell() as TranslationLocalCell
            cell.setupTheme()
            cell.isCheckmarked = currentTranslation?.id == translation.id
            cell.titleLabel.text = translation.title
            cell.descriptionLabel.text = translation.text
            return cell
        } else {
            let cell = tableView.dequeueReusableCell() as TranslationRemoteCell
            cell.setupTheme()
            cell.titleLabel.text = translation.title
            cell.descriptionLabel.text = translation.text
            cell.isDowloading = TranslationSourcesManager.shared.isDownloading(translation: translation)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentSource() {
        case .local:
            return localTranslations.count
        case .avaible:
            return avaibleTranslations.count
        }
    }
}

extension TranslationsListController: SetupThemeProtocol {
    func setupTheme() {
        let config = ThemeManager.shared.currentConfig
        let navbar = navigationController?.navigationBar
        navbar?.barTintColor = config.navbar.backgroundColor
        navbar?.titleTextAttributes = [NSFontAttributeName: UIFont.appFont(16),
                                       NSForegroundColorAttributeName: config.navbar.titleColor]
        navigationItem.leftBarButtonItem?.tintColor = config.navbar.iconsTintColor
        
        if let navController = navigationController,
            navController.viewControllers.count > 1 {
            leftNavbarButton.setImage(#imageLiteral(resourceName: "back_icon"), for: .normal)
            leftNavbarButton.setTitle("back".localized(), for: .normal)
        }
        leftNavbarButton.setTitleColor(config.navbar.buttonsTextColor, for: .normal)
        tableView.backgroundColor = config.common.bgColor
        view.backgroundColor = config.common.bgColor
        segmentControl.tintColor = config.common.segmentControlTintColor
        segmentControlView.backgroundColor = config.common.bgColor
        segmentSeparatorView.backgroundColor = config.common.separatorColor
        let attributes = [ NSForegroundColorAttributeName: UIColor.lightThemeAdditionalTextColor ]
        let highlightedAttributes = [ NSForegroundColorAttributeName: UIColor.white ]
        segmentControl.setTitleTextAttributes(attributes, for: .normal)
        segmentControl.setTitleTextAttributes(highlightedAttributes, for: .selected)
    }
}

// MARK: - rearrange translateions list
extension TranslationsListController {
    func rearrange(listOf translations: [TranslationParameters]) -> [TranslationParameters] {
        var tr = translations
        tr.sort(by: { (obj1, obj2) -> Bool in
            return obj1.title < obj2.title
        })

        let index = tr.index { (t) -> Bool in
            currentTranslation?.id == t.id
        }

        func rearrange<T>(objectWithIndex: Int, toIndex: Int, in array: [T]) -> [T] {
            var arr = array
            let element = arr.remove(at: objectWithIndex)
            arr.insert(element, at: toIndex)

            return arr
        }

        if let indx = index {
            tr = rearrange(objectWithIndex: indx, toIndex: 0, in: tr)
        }

        return tr
    }
}

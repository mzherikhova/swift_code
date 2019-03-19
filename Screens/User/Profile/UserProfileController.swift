//
//  UserProfileController.swift
//  HolyBible
//
//  Created by Margarita Zherikhova on 24.03.17.
//  Copyright © 2017 Globus ltd. All rights reserved.
//

import ALCameraViewController
import SDWebImage
import TPKeyboardAvoiding
import UIKit

fileprivate enum UserProfileItem: Int {
    case firstName
    case lastName
    case email
    case password
    case notifications
    case message
    case creed
    case dateOfBirth
    case gender
    case messageChurch
    case myChurch
    case mySubscribedChurch

    var title: String {
        switch self {
        case .firstName:
            return "userProfileFirstName".localized()
        case .lastName:
            return "userProfileLastName".localized()
        case .creed:
            return "userProfileCreed".localized()
        case .dateOfBirth:
            return "userProfileDateOfBirth".localized()
        case .gender:
            return "userProfileGender".localized()
        case .email:
            return "userProfileEmail".localized()
        case .password:
            return "userProfilePassword".localized()
        case .notifications:
            return "userProfileNotifications".localized()
        case .message:
            return "userProfileMessage".localized()
        case .messageChurch:
            return "userProfileMessageChurch".localized()
        case .myChurch:
            return "userProfileMyChurch".localized()
        case .mySubscribedChurch:
            return "userProfileMySubscribedChurch".localized()
        }
    }
}

protocol UserProfileDelegate: ScreenOfMenuDelegate {
    func userProfileLogoutDidFinish()
}

class UserProfileController: UIViewController {
    // MARK: Internal properties
    weak var delegate: UserProfileDelegate?
    var user: UserParameters? {
        didSet {
            profileModel = UserProfileModel(from: user)
            reloadAvatar()
        }
    }
    // MARK: Fileprivate properties
    @IBOutlet fileprivate weak var avatarContainerView: UIView!
    @IBOutlet fileprivate weak var avatarImageView: UIImageView!
    @IBOutlet fileprivate weak var tableView: TPKeyboardAvoidingTableView!
    @IBOutlet fileprivate weak var rightNavbarButton: UIButton!
    fileprivate var profileModel: UserProfileModel?
    @IBOutlet weak var bgImageView: UIImageView!
    @IBOutlet weak var headerSeparatorView: UIView!
    fileprivate var avatarChanged: Bool = false
    
    fileprivate weak var activityIndicatorView: ModalActivityIndicatorView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTheme()
        if SizeUtils.currentScreenType() == .iPhoneSE {
            setMyTitle(title: "userProfileEditTitle".localized())
        } else {
            title = "userProfileEditTitle".localized()
        }
        user = UserManager.shared.currentUser
        tableView.makeAutomaticDimension()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        user = UserManager.shared.currentUser
        tableView.reloadData()
    }
    
    func setMyTitle(title: String) {
        let titleLabel = UILabel.init(frame: CGRect.init(x: 0, y: 0, width: (self.navigationController?.view.bounds.size.width)!, height: 44))
        let theme = ThemeManager.shared.currentConfig        
        titleLabel.text = "   " + title
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = theme.navbar.titleColor
        self.navigationItem.titleView = titleLabel
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        let theme = ThemeManager.shared.currentConfig
        return theme.common.statusBarStyle
    }
    
    // MARK: Fileprivate func
    @IBAction fileprivate func avatarButtonClicked(_ sender: UIButton) {
        
        let croppingParameters = CroppingParameters.init(isEnabled: true,
                                                         allowResizing: true,
                                                         allowMoving: true,
                                                         minimumSize: CGSize(width: 60, height: 60))
        
        let cameraViewController = CameraViewController.init(croppingParameters: croppingParameters,
                                                             allowsLibraryAccess: true,
                                                             allowsSwapCameraOrientation: true,
                                                             allowVolumeButtonCapture: true) {  [weak self] (image, _) in
            self?.profileModel?.avatarImage = image
            self?.avatarChanged = true
            self?.reloadAvatar()
            self?.dismiss(animated: true, completion: nil)
        }
        present(cameraViewController, animated: true, completion: nil)
    }
    
    @IBAction fileprivate func leftNavbarButtonClicked(_ sender: UIButton) {
        guard let model = profileModel else { return }
        if !model.isValid() {
            tableView.reloadData()
            showMessageAboutDontSave()
            return
        }
        
        if model.hasChanges {
            showMessageAboutSave()
        } else {
            dismissWithSaveChanges(false)
        }
    }
    
    @IBAction fileprivate func rightButtonCliked(_ sender: UIButton) {
        let alertMessage = "alertLogoutConfirmation".localized()
        
        AlertHelper.showYesNoAlert(title: alertMessage, yesAction: { [weak self] in
            UserManager.shared.resetWithoutOffline()
            self?.delegate?.userProfileLogoutDidFinish()
            }, noAction: nil)
    }
    
    fileprivate func reloadAvatar() {
        
        if avatarChanged {
            avatarChanged = false
            if let image = profileModel?.avatarImage {
                avatarImageView.image = image
                return
            }
        } else {
            if let updatedUser = ServicesDBManager.shared.user.userToSync(id: (UserManager.shared.currentUser?.id)!) {
                if let imageData = updatedUser.avatarData {
                    avatarImageView.image = UIImage.init(data: imageData)
                    return
                }
            }
        }

        DispatchQueue.global(qos: .background).async {
            var placeholderImage = UIImage(named: "avatar_cap")
            if let image = UserManager.shared.loadAvatar() {
                    placeholderImage = image
            }
            DispatchQueue.main.async {
                self.avatarImageView.image = placeholderImage
            }
            guard let urlString = self.profileModel?.avatar, let url = URL(string: urlString) else { return }
            
            DispatchQueue.main.async {
                self.avatarImageView.sd_setImage(with: url, placeholderImage: placeholderImage, options:[]) { (image, error, cacheType, fileURL) in
                    if let image = image {
                        UserManager.shared.saveAvatar(image: image)
                    }
                }
            }
        }
    }
    
    fileprivate func dismissWithSaveChanges(_ save: Bool) {
        if save {
            guard let model = profileModel else { return }
            ScreenManager.shared.showHUD()
            if let image = avatarImageView.image {
                UserManager.shared.saveAvatar(image: image)
            }
            SyncAPIManager.shared.updateUserProfileOffline(model.firstName,
                                                           model.lastName,
                                                           model.email,
                                                           model.gender,
                                                           model.creed,
                                                           model.dateOfBirth?.string(),
                                                           model.avatarData) { (updatedUser) in
                UserManager.shared.currentUser = updatedUser
                self.dismiss(animated: true, completion: nil)
                ScreenManager.shared.hideHUD()
            }
        } else {
            dismiss(animated: true, completion: nil)
        }
    }
    // MARK: Messages
    fileprivate func showMessageAboutSave() {
        AlertHelper.showYesNoAlert(message: "alertSaveProfile".localized(), yesAction: { [weak self] in
            self?.dismissWithSaveChanges(true)
        }) { [weak self] in
            self?.dismissWithSaveChanges(false)
        }
    }

    fileprivate func showMessageAboutDontSave() {
        AlertHelper.showOkCancelAlert(title: "alertDontSaveProfile".localized(), message: "", okAction: { [weak self] in
            self?.dismissWithSaveChanges(false)
            }, cancelAction: nil)
    }
}

extension UserProfileController: UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UserProfileItem.mySubscribedChurch.rawValue + 1
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch UserProfileItem(rawValue: indexPath.row)! {
        case .password:
            return (profileModel?.hasPassword ?? false) ? 44 : 0
        case .email:
            return (APICredentials.shared.isSocialAccount ?? false) ? 0 : UITableViewAutomaticDimension
        case .message:
            return 60
        case .messageChurch:
            return 60
        default:
            return UITableViewAutomaticDimension
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = UserProfileItem(rawValue: indexPath.row)!
        switch item {
        case .creed, .dateOfBirth, .gender, .firstName, .lastName, .email:
            let cell = tableView.cellForRow(at: indexPath) as? UserProfileBaseCell
            cell?.inputTextField.becomeFirstResponder()
        case .password:
            let controller = UserProfilePasswordController.instantiate(from: UIStoryboard.from(.user))
            controller.user = UserManager.shared.currentUser
            navigationController?.pushViewController(controller, animated: true)
        case .myChurch:
            if
                let user = UserManager.shared.currentUser,
                let church = ServicesDBManager.shared.churches.church(id: user.myChurchId) {
                
                let storyboard = UIStoryboard.from(.churches)
                let controller = ChurchViewController.instantiate(from: storyboard)
                controller.showedFromMap = false
                controller.configure(church: church)
                self.navigationController?.pushViewController(controller, animated: true)
            } else if
                let user = UserManager.shared.currentUser,
                let church = user.myChurch() {
                
                let storyboard = UIStoryboard.from(.churches)
                let controller = ChurchViewController.instantiate(from: storyboard)
                controller.showedFromMap = false
                controller.configure(church: church)
                self.navigationController?.pushViewController(controller, animated: true)
            }
        case .mySubscribedChurch:
            let storyboard = UIStoryboard.from(.churches)
            let controller = ProfileChurchListViewController.instantiate(from: storyboard)
            controller.configure()
            self.navigationController?.pushViewController(controller, animated: true)
        default:
            break
        }
    }
}

extension UserProfileController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var outputCell: UserProfileBaseCell!
        let item = UserProfileItem(rawValue: indexPath.row)!
        switch item {
            
        case .firstName:
            let cell = tableView.dequeueReusableCell() as UserProfileInputTextCell
            cell.setupTheme()
            cell.inputTextField.text = profileModel?.firstName
            cell.inputTextField.returnKeyType = .next
            cell.errorLabel.text = profileModel?.errorMessages[indexPath.row] ?? ""
            cell.textDidChangeCompletion = { [weak self] (text) in
                self?.profileModel?.firstName = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            outputCell = cell
            
        case .lastName:
            let cell = tableView.dequeueReusableCell() as UserProfileInputTextCell
            cell.setupTheme()
            cell.inputTextField.text = profileModel?.lastName
            cell.inputTextField.returnKeyType = .next
            cell.errorLabel.text = profileModel?.errorMessages[indexPath.row] ?? ""
            cell.textDidChangeCompletion = { [weak self] (text) in
                self?.profileModel?.lastName = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
            outputCell = cell
            
        case .creed:
            let cell = tableView.dequeueReusableCell() as UserProfileInputPickerCell
            cell.setupTheme()
            if let model = profileModel {
                let titles = model.titlesOfCreeds()
                cell.pickerTextField.stringPickerData = titles
                
                if let currentTitle = model.currentCreedTitle() {
                    cell.inputTextField.text = currentTitle
                    cell.pickerTextField.selectedStringIndex = titles.index(of: currentTitle) ?? -1
                }
            }
            cell.errorLabel.text = profileModel?.errorMessages[indexPath.row] ?? ""
            cell.pickerTextField.pickerType = .stringPicker
            cell.pickerTextField.stringDidChange = { [weak self] (index) in
                guard let model = self?.profileModel else { return }
                model.creed = model.creeds[index].id
                cell.inputTextField.text = model.currentCreedTitle()
            }
            outputCell = cell
            
        case .dateOfBirth:
            let cell = tableView.dequeueReusableCell() as UserProfileInputPickerCell
            cell.setupTheme()
            if let model = profileModel {
                cell.inputTextField.text = model.dateOfBirth?.string(with: "d MMMM YYYY") ?? ""
                cell.pickerTextField.datePicker?.date = model.dateOfBirth ?? Date()
            }
            cell.pickerTextField.pickerType = .datePicker
            cell.errorLabel.text = profileModel?.errorMessages[indexPath.row] ?? ""
            cell.pickerTextField.datePicker?.datePickerMode = .date
            cell.pickerTextField.datePicker?.maximumDate = Date()
            cell.pickerTextField.dateDidChange = { [weak self] (date, dateString) in
                guard let model = self?.profileModel else { return }
                model.dateOfBirth = date
                cell.inputTextField.text = date.string(with: "d MMMM YYYY")
            }
            outputCell = cell
            
        case .gender:
            let cell = tableView.dequeueReusableCell() as UserProfileInputPickerCell
            cell.setupTheme()
            if let model = profileModel {
                let titles = model.titlesOfGenders()
                cell.pickerTextField.stringPickerData = titles
                
                if let currentTitle = Gender(rawValue: model.gender)?.title() {
                    cell.inputTextField.text = currentTitle
                    cell.pickerTextField.selectedStringIndex = titles.index(of: currentTitle) ?? 0
                }
            }
            cell.errorLabel.text = profileModel?.errorMessages[indexPath.row] ?? ""
            cell.pickerTextField.pickerType = .stringPicker
            cell.pickerTextField.stringDidChange = { [weak self] (index) in
                guard let model = self?.profileModel else { return }
                model.gender = model.genders[index].rawValue
                cell.inputTextField.text = model.genders[index].title()
            }
            outputCell = cell
            
        case .email:
            let cell = tableView.dequeueReusableCell() as UserProfileInputTextCell
            cell.setupTheme()
            cell.inputTextField.text = profileModel?.email
            cell.inputTextField.returnKeyType = .done
            cell.inputTextField.tag = indexPath.row
            cell.errorLabel.text = profileModel?.errorMessages[indexPath.row] ?? ""
            cell.textDidChangeCompletion = { [weak self] (text) in
                self?.profileModel?.email = text
            }
            outputCell = cell
            
        case .password:
            let cell = tableView.dequeueReusableCell() as UserProfilePasswordCell
            cell.setupTheme()
            outputCell = cell
            
        case .notifications:
            let cell = tableView.dequeueReusableCell() as UserProfileSwitcherCell
            cell.setupTheme()
            outputCell = cell
            
        case .message:
            let cell = tableView.dequeueReusableCell() as UserProfileMessageCell
            cell.setupTheme()
            outputCell = cell
            
        case .messageChurch:
            let cell = tableView.dequeueReusableCell() as UserProfileMessageCell
            cell.setupTheme()
            outputCell = cell
            
        case .myChurch:
            let cell = tableView.dequeueReusableCell() as UserProfileChurchesCell
            cell.configure(cellType: .MyChurch)
            cell.setupTheme()
            outputCell = cell
            
        case .mySubscribedChurch:
            let cell = tableView.dequeueReusableCell() as UserProfileChurchesCell
            cell.configure(cellType: .MySubscribedChurches)
            cell.setupTheme()
            outputCell = cell
        }
        
        outputCell.leftTitleLabel.text = item.title
        (outputCell as? UserProfileInputTextCell)?.inputTextField.tag = indexPath.row
        (outputCell as? UserProfileInputTextCell)?.inputTextField.delegate = self
        return outputCell
    }
}

extension UserProfileController: SetupThemeProtocol {
    func setupTheme() {
        let config = ThemeManager.shared.currentConfig
        let navbar = navigationController?.navigationBar
        navbar?.barTintColor = config.navbar.backgroundColor
        navbar?.titleTextAttributes = [NSFontAttributeName: UIFont.appFont(16),
                                       NSForegroundColorAttributeName: config.navbar.titleColor]
        navigationItem.leftBarButtonItem?.tintColor = config.navbar.iconsTintColor
        
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
        avatarContainerView.layer.cornerRadius = avatarContainerView.bounds.width / 2
        bgImageView?.image = UIImage(named: config.userProfile.bgImageName)
        rightNavbarButton.setTitleColor(config.navbar.buttonsTextColor, for: .normal)
        headerSeparatorView.backgroundColor = config.common.separatorColor
    }
}

extension UserProfileController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if string.isEmpty {
            return true
        }
        let item = UserProfileItem(rawValue: textField.tag)!
        let currentString = textField.text! as NSString
        let newString = currentString.replacingCharacters(in: range, with: string) as NSString
        switch item {
        case .email:
            let email = NSPredicate(format: "SELF MATCHES %@", InputFieldsConstants.regexEmailValidSymbols as NSString)
            return email.evaluate(with: newString)
        default:
            let name = NSPredicate(format: "SELF MATCHES %@", InputFieldsConstants.regexAlphabeticCharacters as NSString)
            if string.characters.count > 1 {
                let trimedString = newString.substring(to: min(newString.length, InputFieldsConstants.maxAlphabeticCharactersLength))
                if name.evaluate(with: trimedString) {
                    textField.text = trimedString
                }
                return false
            }
            return name.evaluate(with: newString)
        }
    }
    
    @discardableResult
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return tableView.textFieldShouldReturn(textField)
    }
}

extension UserProfileController {
    
    func needToPresentActivityIndicator() -> Bool {
        return true
    }
    
    func presentActivityIndicator(
        info: String? = nil,
        viewController: UIViewController? = nil,
        completion: (() -> Void)? = nil)
    {
        let viewController = viewController ?? self.navigationController ?? self
        
        guard
            self.activityIndicatorView == .none,
            let activityIndicatorView = ModalActivityIndicatorView.loadFromNib(),
            let superView = viewController.view
            else { return }
        
        activityIndicatorView.infoString = info
        activityIndicatorView.viewContainer = viewController
        
        if let navigationController = viewController as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
        } else {
            viewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        
        superView.addSubview(activityIndicatorView)
        self.activityIndicatorView = activityIndicatorView
        
        activityIndicatorView.frame = CGRect(
            x: 0.0, y: 0.0,
            width: superView.bounds.width,
            height: superView.bounds.height)
        activityIndicatorView.indicatorShow = { completion?() }
        activityIndicatorView.animating = true
    }
    
    func dismissActivityIndicator(completion: (() -> Void)? = nil)
    {
        guard let activityIndicatorView = self.activityIndicatorView else {
            if let completion = completion {
                completion()
            }
            return
        }
        
        let viewController = activityIndicatorView.viewContainer
        
        if let navigationController = viewController as? UINavigationController {
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
        } else {
            viewController?.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
        
        activityIndicatorView.indicatorHide = { [weak activityIndicatorView] in
            if let completion = completion {
                completion()
            }
            activityIndicatorView?.removeFromSuperview()
            self.activityIndicatorView = nil
        }
        activityIndicatorView.animating = false
    }
}
